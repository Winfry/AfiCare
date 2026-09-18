-- Notifications (facility-admin) -- makes the currently-decorative bell
-- icon real. Two data sources feed it: live alert conditions (already
-- computed elsewhere, zero new queries) and a real Recent Activity feed
-- built from the EXISTING audit_log table, which every facility-admin
-- RPC already writes to. No new table, no new RPC -- pure read feature.
--
-- Gap found and fixed here: audit_log has RLS ENABLED but ZERO SELECT
-- policies exist anywhere in tracked SQL -- meaning no authenticated
-- client can currently read a single row of it (this predates this
-- migration and also affects the platform-admin's own audit_log_screen,
-- which is out of scope to fix here). This adds exactly the one policy
-- facility admins need.
--
-- audit_log has no facility_id COLUMN -- confirmed via grep across every
-- INSERT INTO public.audit_log call site that every facility-admin-
-- relevant action (facility_patient_registered, visit_registered,
-- visit_status_updated, visit_clearance_updated, lab_order_placed,
-- lab_order_status_updated, drug_stock_received, prescription_placed,
-- prescription_dispensed, ward_added, ward_updated, patient_admitted,
-- patient_discharged, department_added, department_updated,
-- facility_profile_updated, facility_link, facility_unlink,
-- facility_admin_granted, facility_admin_revoked) consistently stores a
-- real facility UUID under the 'facility_id' key in the JSONB `details`
-- column instead. Platform-wide actions (role_change, status_change,
-- facility_admin_request_rejected, etc.) simply don't have that key --
-- details->>'facility_id' returns NULL for those, and the IS NOT NULL
-- guard below short-circuits before the UUID cast, so no row throws.

BEGIN;

CREATE POLICY "audit_log_select_facility_admin" ON public.audit_log
FOR SELECT
USING (
  (
    (details->>'facility_id') IS NOT NULL
    AND is_facility_admin_of((details->>'facility_id')::uuid)
  )
  OR get_my_role() = 'admin'
);

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- As a facility admin of your own facility, your facility's events are
-- readable:
--   SELECT * FROM audit_log WHERE details->>'facility_id' = '<own-facility-id>';
--   -- returns rows (assuming any facility-admin RPC has run for this facility)
--
-- Another facility's events are NOT readable:
--   SELECT * FROM audit_log WHERE details->>'facility_id' = '<other-facility-id>';
--   -- returns zero rows
--
-- Platform-wide rows with no facility_id key (e.g. role_change) are NOT
-- readable by a facility admin, and don't error the query:
--   SELECT * FROM audit_log WHERE action = 'role_change'; -- zero rows, no error
--
-- As the platform admin: everything is readable regardless of facility_id:
--   SELECT count(*) FROM audit_log; -- full count, not just own-facility rows
-- ================================================================
