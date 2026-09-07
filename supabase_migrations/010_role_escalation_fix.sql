-- ================================================================
-- 010_role_escalation_fix.sql
--
-- Closes a critical privilege-escalation hole found in a follow-up
-- security review (2026-09-03): the only RLS rule on `users` for
-- UPDATE is "you can edit your own row" (users_update_own, from
-- 002_rls_policies.sql) — it never restricts WHICH columns can
-- change. Any authenticated user, patient or otherwise, can currently
-- send `UPDATE users SET role = 'admin' WHERE id = auth.uid()`
-- directly against the REST API and the database will allow it. The
-- same gap exists on INSERT: self-registration lets the client choose
-- its own `role` value with no server-side check at all.
--
-- Fix: role and status become columns nobody can write directly,
-- except through the two admin-only RPCs defined below. Everything
-- else (the app reading `role` off the row, the router trusting it,
-- get_my_role() used throughout every other table's RLS) becomes
-- trustworthy again, because the row itself can no longer be forged.
--
-- Also makes get_my_role() suspension-aware: a user with
-- status = 'suspended' now resolves to a NULL role, which fails every
-- `get_my_role() = '<role>'` check across the entire schema in one
-- place — instant, system-wide enforcement without touching every
-- individual table's policies.
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- get_my_role(): suspended users get no role at all.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT role
    FROM   users
    WHERE  id::text = (auth.uid())::text
      AND  status IS DISTINCT FROM 'suspended'
  );
END;
$$;

-- ------------------------------------------------------------------
-- Lock role/status: a BEFORE trigger, not just an RLS policy, because
-- RLS's WITH CHECK can't compare "old value" vs "new value" the way a
-- trigger can. Any INSERT/UPDATE that isn't flagged by one of the
-- RPCs below gets its role/status silently forced back to a safe
-- default (INSERT) or rejected outright (UPDATE).
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_role_status_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Self-registration (patient sign-up, provider self-service today)
    -- can only ever create a plain, active patient row. Privileged
    -- accounts are created exclusively through admin_set_user_role /
    -- future invite RPCs, which set the bypass flag below.
    IF current_setting('app.bypass_role_lock', true) IS DISTINCT FROM 'on' THEN
      NEW.role := 'patient';
      NEW.status := 'active';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF (NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status)
       AND current_setting('app.bypass_role_lock', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'role and status can only be changed through an admin action';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_role_status_lock ON public.users;
CREATE TRIGGER trg_enforce_role_status_lock
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.enforce_role_status_lock();

-- ------------------------------------------------------------------
-- The only legitimate way role/status can change: these two RPCs.
-- Each checks the CALLER is an admin before touching anything, then
-- sets a transaction-local flag so the trigger above lets the write
-- through, then logs the change to audit_log.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_user_role(target_user_id uuid, new_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can change a user''s role';
  END IF;
  IF new_role NOT IN ('patient', 'doctor', 'nurse', 'radiologist', 'chw', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', new_role;
  END IF;

  PERFORM set_config('app.bypass_role_lock', 'on', true);
  UPDATE public.users SET role = new_role WHERE id = target_user_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'role_change',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'new_role', new_role),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_status(target_user_id uuid, new_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can change a user''s status';
  END IF;
  IF new_status NOT IN ('active', 'suspended', 'invited') THEN
    RAISE EXCEPTION 'Invalid status: %', new_status;
  END IF;

  PERFORM set_config('app.bypass_role_lock', 'on', true);
  UPDATE public.users SET status = new_status WHERE id = target_user_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'status_change',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'new_status', new_status),
    now()
  );
END;
$$;

-- Any authenticated client may call these — the functions themselves
-- reject anyone whose own role isn't admin.
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid, text) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a non-admin, this must fail with "role and status can only be
-- changed through an admin action":
--   UPDATE users SET role = 'admin' WHERE id = auth.uid();
--
-- As an admin, this must succeed and add a row to audit_log:
--   SELECT admin_set_user_role('<some-user-uuid>', 'doctor');
-- ================================================================
