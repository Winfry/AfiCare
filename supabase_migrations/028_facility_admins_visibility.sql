-- Settings (facility-admin) -- "Team" section. Widens facility_admins'
-- SELECT policy so a facility admin can see every admin of a facility
-- they themselves administer, not just their own row.
--
-- 013_facility_admins.sql's original policy (user_id = auth.uid() OR
-- get_my_role() = 'admin') means AdminFacilityProvider.loadFacilityAdmins
-- -- which already exists and already does the right facility_admins-
-- joined-to-users query -- has only ever been able to return the
-- caller's OWN row to a facility admin, never their colleagues'. This is
-- visibility only: granting/revoking facility-admin access remains
-- exclusively platform-admin-only (admin_grant_facility_admin /
-- admin_revoke_facility_admin, untouched here) -- a deliberate boundary
-- from 013, not something this migration reverses.

BEGIN;

DROP POLICY IF EXISTS "facility_admins_select_own_or_admin" ON public.facility_admins;
CREATE POLICY "facility_admins_select_scoped"
ON public.facility_admins FOR SELECT
USING (
  user_id = auth.uid()
  OR get_my_role() = 'admin'
  OR is_facility_admin_of(facility_id)
);

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- As a facility admin of your own facility, the full roster is
-- readable, not just your own row:
--   SELECT * FROM facility_admins WHERE facility_id = '<own-facility-id>';
--   -- returns every admin of that facility, including colleagues
--
-- Another facility's roster is NOT readable:
--   SELECT * FROM facility_admins WHERE facility_id = '<other-facility-id>';
--   -- returns zero rows
--
-- As the platform admin: everything is readable regardless of facility.
--
-- Granting/revoking is still platform-admin-only (unchanged):
--   SELECT admin_grant_facility_admin('<user-id>', '<own-facility-id>');
--   -- fails for a facility admin caller, succeeds only for the platform admin
-- ================================================================
