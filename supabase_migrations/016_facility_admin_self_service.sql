-- ================================================================
-- 016_facility_admin_self_service.sql
--
-- Replaces the "platform admin blindly promotes a random patient
-- account" facility-admin flow with a self-service one: a facility
-- registers itself and its applicant requests to administer it, then
-- the platform admin reviews and approves in one step. This is the
-- same self-submit-then-approve shape provider verification already
-- uses (011_provider_verification.sql) -- deliberate, since 010's
-- enforce_role_status_lock trigger forces every fresh signup to
-- role='patient' regardless of what the form says, so "start neutral,
-- get promoted via a checked approval" is this platform's security
-- model for every professional role, not something specific to
-- facility admin.
--
-- Also fixes a real, separate bug found along the way: the RLS
-- policies guarding facilities UPDATE/DELETE check
-- auth.role() IN ('admin'), which can never be true anywhere in this
-- app (every other policy uses get_my_role() = 'admin' against
-- public.users.role instead) -- so no platform admin could ever
-- actually verify or delete a facility through PostgREST. Only the
-- facilities policies are fixed here; the same broken pattern on
-- departments/system_settings/audit_log is flagged, not touched, to
-- keep this migration scoped to what's actually in the way.
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- Fix facilities UPDATE/DELETE RLS.
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can update facilities" ON facilities;
CREATE POLICY "facilities_update_platform_admin"
ON facilities FOR UPDATE
USING (get_my_role() = 'admin')
WITH CHECK (get_my_role() = 'admin');

DROP POLICY IF EXISTS "Admins can delete facilities" ON facilities;
CREATE POLICY "facilities_delete_platform_admin"
ON facilities FOR DELETE
USING (get_my_role() = 'admin');

-- ------------------------------------------------------------------
-- facility_admin_requests -- self-submitted "I want to administer
-- this facility" requests, mirroring provider_credentials' shape.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facility_admin_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  title TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES public.users(id),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  UNIQUE (user_id, facility_id)
);

ALTER TABLE public.facility_admin_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_admin_requests_select_own_or_admin" ON public.facility_admin_requests;
CREATE POLICY "facility_admin_requests_select_own_or_admin"
ON public.facility_admin_requests FOR SELECT
USING (user_id = auth.uid() OR get_my_role() = 'admin');

DROP POLICY IF EXISTS "facility_admin_requests_insert_own_pending" ON public.facility_admin_requests;
CREATE POLICY "facility_admin_requests_insert_own_pending"
ON public.facility_admin_requests FOR INSERT
WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- No UPDATE/DELETE policy for anyone -- review only via the RPC below.

GRANT SELECT, INSERT ON public.facility_admin_requests TO authenticated;

-- ------------------------------------------------------------------
-- admin_review_facility_admin_request -- the one action a platform
-- admin takes. Approving both verifies the facility and grants the
-- role in one motion, reusing admin_grant_facility_admin
-- (013_facility_admins.sql) rather than duplicating its logic.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_review_facility_admin_request(
  request_id UUID,
  decision TEXT,
  reason TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_facility_id UUID;
  v_status TEXT;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only the platform admin can review facility admin requests';
  END IF;

  SELECT user_id, facility_id, status INTO v_user_id, v_facility_id, v_status
  FROM public.facility_admin_requests WHERE id = request_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'Request already reviewed';
  END IF;
  IF decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'decision must be approved or rejected';
  END IF;

  IF decision = 'approved' THEN
    UPDATE public.facilities SET status = 'verified'
    WHERE id = v_facility_id AND status <> 'verified';

    PERFORM public.admin_grant_facility_admin(v_user_id, v_facility_id);

    UPDATE public.facility_admin_requests
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
    WHERE id = request_id;
  ELSE
    UPDATE public.facility_admin_requests
    SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = reason
    WHERE id = request_id;
  END IF;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_admin_request_reviewed',
    auth.uid(),
    jsonb_build_object(
      'request_id', request_id,
      'target_user_id', v_user_id,
      'facility_id', v_facility_id,
      'decision', decision,
      'reason', reason
    ),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_review_facility_admin_request(UUID, TEXT, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a freshly authenticated user, submitting a request must succeed:
--   INSERT INTO facility_admin_requests (user_id, facility_id)
--   VALUES (auth.uid(), '<facility-uuid>');
--
-- A second submission for the same (user_id, facility_id) must fail
-- (UNIQUE constraint):
--   INSERT INTO facility_admin_requests (user_id, facility_id)
--   VALUES (auth.uid(), '<same-facility-uuid>');
--
-- As a non-admin, this must fail:
--   SELECT admin_review_facility_admin_request('<request-uuid>', 'approved');
--
-- As the platform admin, approving must succeed and:
--   SELECT admin_review_facility_admin_request('<request-uuid>', 'approved');
--   SELECT role, status FROM users WHERE id = '<applicant-uuid>';        -- role = 'facility_admin'
--   SELECT status FROM facilities WHERE id = '<facility-uuid>';          -- status = 'verified'
--   SELECT is_facility_admin_of('<facility-uuid>');                      -- (as that user) true
--
-- Re-reviewing the same request must fail ("already reviewed").
--
-- Rejecting a different pending request must succeed and store the
-- reason without touching the applicant's role:
--   SELECT admin_review_facility_admin_request('<other-request-uuid>', 'rejected', 'Could not verify registration number');
--   SELECT role FROM users WHERE id = '<other-applicant-uuid>';          -- unchanged, still 'patient'
--
-- As the platform admin, this must now succeed (previously silently
-- failed due to the auth.role() IN ('admin') bug):
--   UPDATE facilities SET status = 'verified' WHERE id = '<facility-uuid>';
-- ================================================================
