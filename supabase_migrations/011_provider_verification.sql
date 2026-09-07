-- ================================================================
-- 011_provider_verification.sql
--
-- Adds provider license verification and multi-facility affiliation.
--
-- Two problems this closes:
-- 1. Self-registration lets a client pick 'doctor'/'nurse'/'chw' as
--    their role with zero proof they're a real medical professional
--    (010_role_escalation_fix.sql already neutralizes the role value
--    itself on INSERT, but there was previously no path at all for a
--    legitimate provider to actually become verified staff).
-- 2. `users.facility_id` is a single column, which doesn't fit a
--    specialist who works across several hospitals, or a licensed
--    provider who isn't employed anywhere yet.
--
-- Design: reuses the bypass-flag trigger already built in 010 for the
-- `users.role` promotion step (no new bypass machinery needed there).
-- The two new tables are brand new, so a simpler rule works for them:
-- a provider may only ever INSERT their own `provider_credentials` row
-- as 'pending'; only the two admin-only, SECURITY DEFINER RPCs below
-- may ever change verification_status or write to provider_facilities
-- at all — there is no client UPDATE/INSERT policy on those at any
-- point, so there's no escalation path to defend against.
--
-- Facility linking is a directory/staffing fact only — it does NOT
-- gate clinical data access. Confirmed: consultations/care_team/etc.
-- key exclusively off auth.uid() = patient_id/provider_id, never off
-- facility_id or department. This migration doesn't change that.
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- provider_credentials — one row per provider, one active license claim.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_credentials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  license_number TEXT NOT NULL,
  specialty TEXT,
  requested_role TEXT NOT NULL CHECK (requested_role IN ('doctor', 'nurse', 'chw', 'radiologist')),
  verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
  verified_by UUID REFERENCES public.users(id),
  verified_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_provider_credentials_status ON public.provider_credentials(verification_status);

ALTER TABLE public.provider_credentials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "provider_credentials_select_own_or_admin" ON public.provider_credentials;
CREATE POLICY "provider_credentials_select_own_or_admin"
ON public.provider_credentials FOR SELECT
USING (provider_id = auth.uid() OR get_my_role() = 'admin');

DROP POLICY IF EXISTS "provider_credentials_insert_own_pending" ON public.provider_credentials;
CREATE POLICY "provider_credentials_insert_own_pending"
ON public.provider_credentials FOR INSERT
WITH CHECK (provider_id = auth.uid() AND verification_status = 'pending');

-- No UPDATE/DELETE policy for anyone, including admin — verification_status
-- can only change through admin_verify_provider_license below.

GRANT SELECT, INSERT ON public.provider_credentials TO authenticated;

-- ------------------------------------------------------------------
-- provider_facilities — directory only: which hospitals a verified
-- provider is staff at. Never a clinical-data access gate.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_facilities (
  provider_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  specialty TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  linked_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (provider_id, facility_id)
);

CREATE INDEX IF NOT EXISTS idx_provider_facilities_facility ON public.provider_facilities(facility_id);

ALTER TABLE public.provider_facilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "provider_facilities_select_all" ON public.provider_facilities;
CREATE POLICY "provider_facilities_select_all"
ON public.provider_facilities FOR SELECT
USING (true);

-- No INSERT/UPDATE/DELETE policy for anyone — RPC-only
-- (admin_link_provider_to_facility below).

GRANT SELECT ON public.provider_facilities TO authenticated;

-- ------------------------------------------------------------------
-- admin_verify_provider_license: approve or reject a pending request.
-- On approval, also promotes users.role using 010's existing
-- bypass-flag pattern — reusing that mechanism rather than building a
-- second one.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_verify_provider_license(
  target_user_id UUID,
  decision TEXT,
  reason TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requested_role TEXT;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can verify provider licenses';
  END IF;
  IF decision NOT IN ('verified', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision: %', decision;
  END IF;

  SELECT requested_role INTO v_requested_role
  FROM public.provider_credentials
  WHERE provider_id = target_user_id;

  IF v_requested_role IS NULL THEN
    RAISE EXCEPTION 'No verification request found for this user';
  END IF;

  IF decision = 'verified' THEN
    UPDATE public.provider_credentials
    SET verification_status = 'verified',
        verified_by = auth.uid(),
        verified_at = now(),
        rejection_reason = NULL
    WHERE provider_id = target_user_id;

    PERFORM set_config('app.bypass_role_lock', 'on', true);
    UPDATE public.users SET role = v_requested_role WHERE id = target_user_id;
  ELSE
    UPDATE public.provider_credentials
    SET verification_status = 'rejected',
        verified_by = auth.uid(),
        verified_at = now(),
        rejection_reason = reason
    WHERE provider_id = target_user_id;
  END IF;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'provider_verification',
    auth.uid(),
    jsonb_build_object(
      'target_user_id', target_user_id,
      'decision', decision,
      'requested_role', v_requested_role,
      'reason', reason
    ),
    now()
  );
END;
$$;

-- ------------------------------------------------------------------
-- admin_link_provider_to_facility: staff a verified provider at a
-- facility. Refuses to link anyone not yet verified.
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
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can link a provider to a facility';
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

GRANT EXECUTE ON FUNCTION public.admin_verify_provider_license(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_link_provider_to_facility(UUID, UUID, TEXT, BOOLEAN) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a non-admin, this must be rejected (no RLS policy permits it):
--   UPDATE provider_credentials SET verification_status = 'verified' WHERE provider_id = auth.uid();
--   INSERT INTO provider_facilities (provider_id, facility_id) VALUES (auth.uid(), '<any-facility-uuid>');
--
-- A provider requesting verification (self, as 'pending') must succeed:
--   INSERT INTO provider_credentials (provider_id, license_number, requested_role)
--   VALUES (auth.uid(), 'KMPDC/12345', 'doctor');
--
-- As an admin, this must succeed and promote users.role to 'doctor':
--   SELECT admin_verify_provider_license('<provider-uuid>', 'verified');
--   SELECT admin_link_provider_to_facility('<provider-uuid>', '<facility-uuid>', 'Cardiology', true);
--   SELECT * FROM audit_log WHERE action IN ('provider_verification', 'facility_link') ORDER BY timestamp DESC LIMIT 2;
-- ================================================================
