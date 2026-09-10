-- ================================================================
-- 018_facilities_anon_insert.sql
--
-- Bug fix found while live-testing 017: facility_admin_requests was
-- opened up to anonymous submission, but the facilities table itself
-- was not -- its INSERT policy still required auth.role() =
-- 'authenticated', so the new anonymous "register your facility" form
-- failed at the very first insert. A bare facility row is harmless
-- (status defaults to 'pending', unusable until a platform admin
-- approves the paired facility_admin_requests row), so this widens
-- the same way 017 already widened facility_admin_requests.
-- ================================================================

BEGIN;

DROP POLICY IF EXISTS "Authenticated users can register facilities" ON public.facilities;
CREATE POLICY "facilities_insert_anyone"
ON public.facilities FOR INSERT
WITH CHECK (true);

GRANT INSERT ON public.facilities TO anon;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As an anonymous (logged-out) client, this must now succeed:
--   INSERT INTO facilities (name, type) VALUES ('Test Clinic', 'clinic');
-- ================================================================
