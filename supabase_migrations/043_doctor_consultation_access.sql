-- ================================================================
-- 043: Doctors can read the patients they care for, and leave the two
--      audit entries the app writes
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run 041 first (it creates provider_can_see_patient). Safe to run
-- more than once.
-- ================================================================
--
-- WHY
-- 1. patients_select_consulted let a doctor read a patient's profile
--    (allergies, date of birth) by comparing consultations.patient_id
--    with users.medilink_id. On the live database consultations.patient_id
--    is the account id (a UUID), so the comparison never matched and no
--    doctor could ever read a consulted patient's profile.
-- 2. audit_log has read policies only, so the app's own entries,
--    "consultation_created" and "patient_record_accessed" (who opened
--    whose record, which matters for privacy), could never be written,
--    and a failed entry made a saved consultation look unsaved.
--
-- WHAT THIS DOES
-- 1. The doctor/nurse read of patients uses provider_can_see_patient()
--    (041): care team, an appointment, or a consultation with them. The
--    same rule pregnancies and ANC visits use.
-- 2. A doctor or nurse may add exactly those two audit entries, only
--    under their own name. Nothing else, and never edit or delete.
-- ================================================================

BEGIN;

DROP POLICY IF EXISTS "patients_select_consulted" ON public.patients;
DROP POLICY IF EXISTS "patients_select_her_providers" ON public.patients;
CREATE POLICY "patients_select_her_providers" ON public.patients
FOR SELECT TO authenticated
USING (provider_can_see_patient(id));

DROP POLICY IF EXISTS "audit_log_insert_clinician_events" ON public.audit_log;
CREATE POLICY "audit_log_insert_clinician_events" ON public.audit_log
FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND action IN ('consultation_created', 'patient_record_accessed')
  AND (SELECT get_my_role()) IN ('doctor', 'nurse')
);

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'old consulted-patients rule removed' AS check_name,
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'patients'
                     AND policyname = 'patients_select_consulted') AS passed
  UNION ALL
  SELECT 2, 'doctors read the patients they care for',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'patients'
                 AND policyname = 'patients_select_her_providers')
  UNION ALL
  SELECT 3, 'patients still read their own row',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'patients'
                 AND policyname = 'patients_select_own')
  UNION ALL
  SELECT 4, 'clinicians may write the two audit entries',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'audit_log'
                 AND policyname = 'audit_log_insert_clinician_events')
) checks
ORDER BY n;
