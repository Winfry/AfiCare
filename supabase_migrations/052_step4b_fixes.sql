-- ================================================================
-- 052: Fixes from the step 4b check (checks/051_step4b_check.sql)
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 042 and 047. Safe to run more than once.
--
-- WHY (051, run live 2026-11-04)
--   B  mood_entries and mental_health_screenings point their patient_id
--      at patients(id). 6 patient accounts have no patients row, so their
--      mood check-ins and questionnaires could not be saved at all. Every
--      account is in users, and 047 made these rows hers only
--      (patient_id = auth.uid()), so they now point at users.
--   C  disability_profiles.patient_id must be an account (users), and the
--      only write rule is "your own account", so a parent could not save
--      her child's disability profile. Now: an account or a dependant,
--      and the guardian may save her dependant's (as 042 did for four
--      other tables). Removing a dependant removes theirs.
--   D  adherence_log stores times with a time zone, but the app sent
--      Kenyan clock times without one, so the database took 08:00 as
--      08:00 UTC (11:00 in Kenya), and "is this dose due yet?" was three
--      hours out. The updated app sends true times; the times already
--      stored are corrected once, by three hours (all were written from
--      Kenyan phones). A note on the column marks it done, so running
--      this again never moves them twice.
--   Tidy  signed-out visitors lose the rights they held on these tables
--      (row level security already stopped them).
-- ================================================================

BEGIN;

-- ── B. Mental wellbeing: every account can save ─────────────────
ALTER TABLE public.mood_entries DROP CONSTRAINT IF EXISTS mood_entries_patient_id_fkey;
ALTER TABLE public.mood_entries
  ADD CONSTRAINT mood_entries_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.mental_health_screenings DROP CONSTRAINT IF EXISTS mental_health_screenings_patient_id_fkey;
ALTER TABLE public.mental_health_screenings
  ADD CONSTRAINT mental_health_screenings_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ── C. Disability profiles: an account or a dependant ───────────
ALTER TABLE public.disability_profiles DROP CONSTRAINT IF EXISTS disability_profiles_patient_id_fkey;

DROP TRIGGER IF EXISTS trg_check_disability_profiles_patient ON public.disability_profiles;
CREATE TRIGGER trg_check_disability_profiles_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.disability_profiles
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();

DROP POLICY IF EXISTS "Patients can manage own disability profile" ON public.disability_profiles;
DROP POLICY IF EXISTS "disability_profiles_self_or_dependant" ON public.disability_profiles;
CREATE POLICY "disability_profiles_self_or_dependant" ON public.disability_profiles
FOR ALL TO authenticated
USING (is_self_or_my_dependant(patient_id))
WITH CHECK (is_self_or_my_dependant(patient_id));
-- "Providers can view disability profiles" (care team) is kept as it is.

-- Removing an account or a dependant removes their records in these
-- tables (042), now including the disability profile.
CREATE OR REPLACE FUNCTION public.delete_records_of_removed_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.emergency_profiles   WHERE patient_id = OLD.id;
  DELETE FROM public.vaccination_records  WHERE patient_id = OLD.id;
  DELETE FROM public.care_team            WHERE patient_id = OLD.id;
  DELETE FROM public.medication_reminders WHERE patient_id = OLD.id;
  DELETE FROM public.disability_profiles  WHERE patient_id = OLD.id;
  RETURN OLD;
END;
$$;

-- ── D. Dose times: correct the stored ones, once ────────────────
DO $$
BEGIN
  IF coalesce(col_description('public.adherence_log'::regclass,
       (SELECT attnum FROM pg_attribute
        WHERE attrelid = 'public.adherence_log'::regclass AND attname = 'scheduled_time')), '')
     NOT LIKE '%true times (052)%' THEN
    UPDATE public.adherence_log
    SET scheduled_time = scheduled_time - interval '3 hours',
        taken_time     = taken_time - interval '3 hours';
    COMMENT ON COLUMN public.adherence_log.scheduled_time IS
      'When the dose is due, as a true time: true times (052). Rows from before 052 were moved back 3 hours.';
  END IF;
END $$;

-- ── Tidy: signed-out visitors have no rights here ───────────────
REVOKE ALL ON public.disability_profiles FROM anon;
REVOKE ALL ON public.adherence_log      FROM anon;
REVOKE ALL ON public.medical_expenses   FROM anon;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'mood check-ins save for every account' AS check_name,
         EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mood_entries_patient_id_fkey'
                 AND conrelid = 'public.mood_entries'::regclass
                 AND confrelid = 'public.users'::regclass) AS passed
  UNION ALL
  SELECT 2, 'questionnaires save for every account',
         EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mental_health_screenings_patient_id_fkey'
                 AND conrelid = 'public.mental_health_screenings'::regclass
                 AND confrelid = 'public.users'::regclass)
  UNION ALL
  SELECT 3, 'a parent can save her child''s disability profile',
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'disability_profiles_patient_id_fkey')
         AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_check_disability_profiles_patient')
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'disability_profiles'
                     AND policyname = 'disability_profiles_self_or_dependant' AND with_check IS NOT NULL)
         AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'disability_profiles'
                         AND policyname = 'Patients can manage own disability profile')
  UNION ALL
  SELECT 4, 'removing someone removes their disability profile',
         position('disability_profiles' IN (SELECT prosrc FROM pg_proc
                                            WHERE proname = 'delete_records_of_removed_patient')) > 0
  UNION ALL
  SELECT 5, 'stored dose times corrected (once)',
         coalesce(col_description('public.adherence_log'::regclass,
           (SELECT attnum FROM pg_attribute
            WHERE attrelid = 'public.adherence_log'::regclass AND attname = 'scheduled_time')), '')
         LIKE '%true times (052)%'
  UNION ALL
  SELECT 6, 'signed-out visitors have no rights on these tables',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND grantee = 'anon'
                       AND table_name IN ('disability_profiles', 'adherence_log', 'medical_expenses'))
) checks
ORDER BY n;
