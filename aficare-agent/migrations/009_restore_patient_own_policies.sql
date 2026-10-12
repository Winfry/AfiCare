-- ── Migration 009: Restore patients' access to their own record ────────────
-- Run after 008_dependent_allergies.sql
--
-- WHY
-- The live database was found (2026-10-12) to have only two policies on
-- `patients`: patients_select_admin and patients_select_consulted. The
-- three that 002_rls_policies.sql creates for the patient themselves —
-- select_own, insert_own, update_own — were missing.
--
-- With RLS on and no matching policy, Postgres does not raise an error;
-- it simply returns no rows and writes nothing. So:
--   * the signup wizard's profile save stored nothing, while the app
--     carried on as though it had (fixed separately in the app);
--   * a patient could not read their own allergies, blood type or
--     emergency contact, and Home kept showing "Complete your health
--     profile" no matter how many times it was completed.
--
-- This recreates exactly the policies 002 intended, plus a WITH CHECK on
-- UPDATE so a patient cannot re-point their row at someone else's id.
-- Doctor/nurse/admin policies are not touched.
--
-- Safe to re-run: each policy is dropped first if it exists.

DROP POLICY IF EXISTS "patients_select_own" ON patients;
DROP POLICY IF EXISTS "patients_insert_own" ON patients;
DROP POLICY IF EXISTS "patients_update_own" ON patients;

-- Patient sees only their own extended record
CREATE POLICY "patients_select_own"
ON patients FOR SELECT
USING (
  id::text = (SELECT auth.uid())::text
);

-- Patient creates their own record (first save of the signup wizard)
CREATE POLICY "patients_insert_own"
ON patients FOR INSERT
WITH CHECK (
  id::text = (SELECT auth.uid())::text
);

-- Patient updates their own record, and only into their own record
CREATE POLICY "patients_update_own"
ON patients FOR UPDATE
USING (
  id::text = (SELECT auth.uid())::text
)
WITH CHECK (
  id::text = (SELECT auth.uid())::text
);

-- Table privileges: RLS only filters what a role is already allowed to
-- do, so make sure signed-in users hold the base grants (no-op if they
-- already do). No DELETE: patients never delete their own record.
GRANT SELECT, INSERT, UPDATE ON patients TO authenticated;

-- ── VERIFY: should list five policies ───────────────────────────────────
SELECT policyname, cmd
FROM   pg_policies
WHERE  schemaname = 'public' AND tablename = 'patients'
ORDER  BY policyname;
