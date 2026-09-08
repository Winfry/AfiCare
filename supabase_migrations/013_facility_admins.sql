-- ================================================================
-- 013_facility_admins.sql
--
-- Adds a genuine facility-scoped admin: front-desk/office staff who
-- run one hospital's roster, distinct from the platform-wide `admin`
-- role. Closes a real gap found while testing: admin_register_screen
-- promised "set up your organization account... manage facilities,
-- staff, and system-wide settings" but `admin` has always been global
-- — signing up there never actually granted control over just one
-- organization. This migration builds what that screen implied but
-- never delivered, the right way: granted only by the platform admin,
-- never self-service, same pattern as everything else in this schema.
--
-- Governing rule (confirmed with the user): verifying someone is a
-- real licensed medical professional is always a platform-level call
-- (unchanged, stays admin-only). Deciding who's on your own hospital's
-- roster is a facility-level call — that's what this role gets, and
-- nothing more. A facility admin is never a clinician: granting it
-- requires the target's current role to be a plain 'patient', same
-- "one role per person" rule as everywhere else in this app.
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- Widen the role whitelist. Defensively drop the (possibly stale)
-- trigger-based check from 008_canonical_schema.sql too, so a facility
-- admin can never be silently rejected by whichever mechanism happens
-- to still be live.
-- ------------------------------------------------------------------
DROP TRIGGER IF EXISTS users_role_check ON users;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('patient', 'doctor', 'nurse', 'radiologist', 'admin', 'chw', 'facility_admin'));

-- ------------------------------------------------------------------
-- facility_admins — who administers which facility. Separate from
-- provider_facilities on purpose: that table is for clinically
-- verified staff with a license; a front-desk admin has neither.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facility_admins (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, facility_id)
);

ALTER TABLE public.facility_admins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_admins_select_own_or_admin" ON public.facility_admins;
CREATE POLICY "facility_admins_select_own_or_admin"
ON public.facility_admins FOR SELECT
USING (user_id = auth.uid() OR get_my_role() = 'admin');

-- No INSERT/UPDATE/DELETE policy for anyone — RPC-only, below.

GRANT SELECT ON public.facility_admins TO authenticated;

-- ------------------------------------------------------------------
-- is_facility_admin_of(): the check every facility-scoped RPC below
-- (and the two widened ones from 011) uses alongside get_my_role() =
-- 'admin', so the platform admin always retains every facility
-- admin's powers too, everywhere.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_facility_admin_of(target_facility_id UUID)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.facility_admins
    WHERE user_id = auth.uid() AND facility_id = target_facility_id
  );
$$;

-- ------------------------------------------------------------------
-- admin_grant_facility_admin / admin_revoke_facility_admin — the only
-- way this role is ever assigned. Platform-admin-only, audited, and
-- refuses to grant it to an existing clinician.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_grant_facility_admin(
  target_user_id UUID,
  target_facility_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_role TEXT;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can grant facility admin access';
  END IF;

  SELECT role INTO v_current_role FROM public.users WHERE id = target_user_id;

  IF v_current_role IS DISTINCT FROM 'patient' AND v_current_role IS DISTINCT FROM 'facility_admin' THEN
    RAISE EXCEPTION 'Can only grant facility admin to a plain patient account (one role per person)';
  END IF;

  PERFORM set_config('app.bypass_role_lock', 'on', true);
  UPDATE public.users SET role = 'facility_admin' WHERE id = target_user_id;

  INSERT INTO public.facility_admins (user_id, facility_id, granted_by)
  VALUES (target_user_id, target_facility_id, auth.uid())
  ON CONFLICT (user_id, facility_id) DO NOTHING;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_admin_granted',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'facility_id', target_facility_id),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_facility_admin(
  target_user_id UUID,
  target_facility_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can revoke facility admin access';
  END IF;

  DELETE FROM public.facility_admins
  WHERE user_id = target_user_id AND facility_id = target_facility_id;

  -- If they no longer administer any facility, demote back to patient.
  IF NOT EXISTS (SELECT 1 FROM public.facility_admins WHERE user_id = target_user_id) THEN
    PERFORM set_config('app.bypass_role_lock', 'on', true);
    UPDATE public.users SET role = 'patient' WHERE id = target_user_id AND role = 'facility_admin';
  END IF;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_admin_revoked',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'facility_id', target_facility_id),
    now()
  );
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_add_department / facility_admin_update_department —
-- department management for whoever runs a facility (platform admin
-- or that facility's admin). departments' existing RLS predates the
-- checked-RPC pattern and its live policy text is unverified, so this
-- routes through a fresh, consistent, audited path instead.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_add_department(
  target_facility_id UUID,
  department_name TEXT,
  department_description TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(target_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can add a department';
  END IF;

  INSERT INTO public.departments (facility_id, name, description)
  VALUES (target_facility_id, department_name, department_description);

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'department_added',
    auth.uid(),
    jsonb_build_object('facility_id', target_facility_id, 'name', department_name),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.facility_admin_update_department(
  target_department_id UUID,
  department_name TEXT,
  department_description TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
BEGIN
  SELECT facility_id INTO v_facility_id FROM public.departments WHERE id = target_department_id;
  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Department not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can update this department';
  END IF;

  UPDATE public.departments
  SET name = department_name, description = department_description
  WHERE id = target_department_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'department_updated',
    auth.uid(),
    jsonb_build_object('department_id', target_department_id, 'facility_id', v_facility_id, 'name', department_name),
    now()
  );
END;
$$;

-- ------------------------------------------------------------------
-- Widen admin_link_provider_to_facility / admin_unlink_provider_from
-- _facility (from 011/012) so a facility admin can also manage their
-- own facility's roster. Permission check only — everything else
-- (verified-only linking, audit logging) is unchanged.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_link_provider_to_facility(
  target_user_id UUID,
  target_facility_id UUID,
  provider_specialty TEXT DEFAULT NULL,
  make_primary BOOLEAN DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(target_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can link a provider to it';
  END IF;

  SELECT verification_status INTO v_status
  FROM public.provider_credentials
  WHERE provider_id = target_user_id;

  IF v_status IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'Provider must be verified before being linked to a facility';
  END IF;

  INSERT INTO public.provider_facilities (provider_id, facility_id, specialty, is_primary, linked_by)
  VALUES (target_user_id, target_facility_id, provider_specialty, make_primary, auth.uid())
  ON CONFLICT (provider_id, facility_id)
  DO UPDATE SET specialty = EXCLUDED.specialty, is_primary = EXCLUDED.is_primary;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_link',
    auth.uid(),
    jsonb_build_object(
      'target_user_id', target_user_id,
      'facility_id', target_facility_id,
      'specialty', provider_specialty,
      'is_primary', make_primary
    ),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_unlink_provider_from_facility(
  target_user_id UUID,
  target_facility_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(target_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can unlink a provider from it';
  END IF;

  DELETE FROM public.provider_facilities
  WHERE provider_id = target_user_id AND facility_id = target_facility_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_unlink',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'facility_id', target_facility_id),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_facility_admin_of(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_facility_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_facility_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_add_department(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_update_department(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_link_provider_to_facility(UUID, UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unlink_provider_from_facility(UUID, UUID) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a plain patient, this must be rejected:
--   SELECT admin_grant_facility_admin(auth.uid(), '<any-facility-uuid>');
--   INSERT INTO facility_admins (user_id, facility_id) VALUES (auth.uid(), '<any-facility-uuid>');
--
-- As the platform admin, this must succeed and promote the target's role:
--   SELECT admin_grant_facility_admin('<patient-uuid>', '<facility-uuid>');
--   SELECT role FROM users WHERE id = '<patient-uuid>';  -- should be 'facility_admin'
--
-- Granting it to an existing doctor must be rejected:
--   SELECT admin_grant_facility_admin('<doctor-uuid>', '<facility-uuid>');
--
-- As that newly-granted facility admin (their own session), linking a
-- provider at THEIR facility must succeed; at a DIFFERENT facility must fail.
-- ================================================================
