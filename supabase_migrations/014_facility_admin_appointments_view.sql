-- ================================================================
-- 014_facility_admin_appointments_view.sql
--
-- Gives a facility admin (and the platform admin) read access to
-- their own facility's appointments. This is view-only -- confirming,
-- cancelling, or rescheduling stays out of scope for now; the point
-- here is just visibility into "what is happening at my hospital
-- today", which was the one thing conspicuously missing from the
-- facility admin dashboard shipped in 013.
--
-- No new RPC needed: this is a read, not a state-changing write, so
-- a plain RLS SELECT policy is the right tool (same as how
-- provider_facilities' SELECT policy works) -- audited writes still
-- go through checked RPCs, reads don't need that machinery.
-- ================================================================

BEGIN;

DROP POLICY IF EXISTS "facility_admin_can_view_appointments" ON public.appointments;
CREATE POLICY "facility_admin_can_view_appointments"
ON public.appointments FOR SELECT
USING (
  facility_id IS NOT NULL
  AND (get_my_role() = 'admin' OR is_facility_admin_of(facility_id))
);

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a facility admin, this must return only their own facility's rows:
--   SELECT id, facility_id, scheduled_at, status FROM appointments;
--
-- As a facility admin of Facility A, this must return nothing for
-- Facility B's appointments even if you know a specific row's id:
--   SELECT * FROM appointments WHERE facility_id = '<facility-B-uuid>';
-- ================================================================
