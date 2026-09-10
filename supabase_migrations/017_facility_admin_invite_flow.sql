-- ================================================================
-- 017_facility_admin_invite_flow.sql
--
-- Replaces the previous "applicant signs up with a work email, then
-- gets promoted" facility-admin flow with a real invite: the account
-- is never created until a platform admin approves the application,
-- and when it is created it's created directly as role='facility_admin'
-- -- never 'patient', not even briefly. That's only possible because
-- enforce_role_status_lock (010_role_escalation_fix.sql) forces every
-- client-side INSERT into users to role='patient' unless the
-- transaction sets app.bypass_role_lock, which only a SECURITY DEFINER
-- function can do -- so account creation has to move server-side,
-- behind the platform admin's approval, the same way patient-auth's
-- Edge Function already creates patient accounts with the service
-- role. See supabase/functions/invite-facility-admin for the other
-- half of this (it's the only caller of service_create_invited_
-- facility_admin below).
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- facility_admin_requests now describes an application with no
-- account behind it yet -- user_id is populated only once approved.
-- ------------------------------------------------------------------
ALTER TABLE public.facility_admin_requests ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.facility_admin_requests ADD COLUMN IF NOT EXISTS applicant_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.facility_admin_requests ADD COLUMN IF NOT EXISTS applicant_email TEXT NOT NULL DEFAULT '';
ALTER TABLE public.facility_admin_requests ALTER COLUMN applicant_name DROP DEFAULT;
ALTER TABLE public.facility_admin_requests ALTER COLUMN applicant_email DROP DEFAULT;

DROP POLICY IF EXISTS "facility_admin_requests_select_own_or_admin" ON public.facility_admin_requests;
CREATE POLICY "facility_admin_requests_select_own_or_admin"
ON public.facility_admin_requests FOR SELECT
USING (get_my_role() = 'admin' OR (user_id IS NOT NULL AND user_id = auth.uid()));

DROP POLICY IF EXISTS "facility_admin_requests_insert_own_pending" ON public.facility_admin_requests;
CREATE POLICY "facility_admin_requests_insert_own_pending"
ON public.facility_admin_requests FOR INSERT
WITH CHECK (user_id IS NULL AND status = 'pending');

-- Anonymous applications are deliberate: a facility applying to join
-- shouldn't require an AfiCare account first. Nothing privileged
-- happens until a platform admin reviews it -- a bogus application
-- just sits pending and gets rejected.
GRANT SELECT, INSERT ON public.facility_admin_requests TO authenticated, anon;

-- ------------------------------------------------------------------
-- service_create_invited_facility_admin -- the only place a
-- facility_admin row is ever created directly, never as 'patient'.
-- No get_my_role() check inside: callability IS the authorization
-- boundary, granted only to service_role, same trust model
-- patient-auth already uses to bypass normal client checks entirely.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.service_create_invited_facility_admin(
  new_user_id UUID,
  new_email TEXT,
  new_full_name TEXT,
  target_facility_id UUID,
  target_title TEXT,
  request_id UUID,
  invited_by UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.bypass_role_lock', 'on', true);

  INSERT INTO public.users (id, email, full_name, role, status, created_at)
  VALUES (new_user_id, new_email, new_full_name, 'facility_admin', 'invited', now());

  UPDATE public.facilities SET status = 'verified'
  WHERE id = target_facility_id AND status <> 'verified';

  INSERT INTO public.facility_admins (user_id, facility_id, granted_by)
  VALUES (new_user_id, target_facility_id, invited_by)
  ON CONFLICT (user_id, facility_id) DO NOTHING;

  UPDATE public.facility_admin_requests
  SET status = 'approved', user_id = new_user_id, reviewed_by = invited_by, reviewed_at = now()
  WHERE id = request_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_admin_invited',
    invited_by,
    jsonb_build_object(
      'new_user_id', new_user_id,
      'facility_id', target_facility_id,
      'request_id', request_id,
      'title', target_title
    ),
    now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.service_create_invited_facility_admin(UUID, TEXT, TEXT, UUID, TEXT, UUID, UUID) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.service_create_invited_facility_admin(UUID, TEXT, TEXT, UUID, TEXT, UUID, UUID) TO service_role;

-- ------------------------------------------------------------------
-- Rejection stays a normal admin RPC -- no account is ever involved.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_review_facility_admin_request(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.admin_reject_facility_admin_request(
  request_id UUID,
  reason TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only the platform admin can review facility admin requests';
  END IF;

  SELECT status INTO v_status FROM public.facility_admin_requests WHERE id = request_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'Request already reviewed';
  END IF;

  UPDATE public.facility_admin_requests
  SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = reason
  WHERE id = request_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_admin_request_rejected',
    auth.uid(),
    jsonb_build_object('request_id', request_id, 'reason', reason),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reject_facility_admin_request(UUID, TEXT) TO authenticated;

-- ------------------------------------------------------------------
-- activate_invited_account -- the invited person flips their own
-- account from 'invited' to 'active' once they've set a real password.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activate_invited_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND status = 'invited') THEN
    RAISE EXCEPTION 'No pending invitation for this account';
  END IF;

  PERFORM set_config('app.bypass_role_lock', 'on', true);
  UPDATE public.users SET status = 'active' WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.activate_invited_account() TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As an anonymous (logged-out) client, this must succeed:
--   INSERT INTO facility_admin_requests (facility_id, applicant_name, applicant_email)
--   VALUES ('<facility-uuid>', 'Jane Wanjiku', 'jane@katuluhealth.co.ke');
--
-- The same with a non-null user_id must fail:
--   INSERT INTO facility_admin_requests (user_id, facility_id, applicant_name, applicant_email)
--   VALUES (auth.uid(), '<facility-uuid>', 'Jane Wanjiku', 'jane@katuluhealth.co.ke');
--
-- As an authenticated (non-service-role) user, this must fail on
-- permission alone, not application logic:
--   SELECT service_create_invited_facility_admin('<uuid>', 'x@x.com', 'X', '<facility-uuid>', NULL, '<request-uuid>', auth.uid());
--
-- As the platform admin, rejecting a pending request must succeed and
-- must NOT create any users row:
--   SELECT admin_reject_facility_admin_request('<request-uuid>', 'Could not verify registration number');
--   SELECT id FROM users WHERE email = '<that applicant email>';  -- no rows
--
-- As a non-admin, admin_reject_facility_admin_request must fail.
--
-- activate_invited_account(): as a user whose status is already
-- 'active', must fail ("No pending invitation"); as a user whose
-- status is 'invited', must succeed and flip status to 'active'.
-- ================================================================
