-- ================================================================
-- 042: The rest of step 3, saves that always failed
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run 040 first. Safe to run more than once.
-- ================================================================
--
-- WHY (from the 042 pre-check against the live database)
-- • Medicine costs, insurance claims, medicine reminders and Settings
--   sent columns their tables don't have, so every save failed, for
--   everyone. (The app side is fixed alongside this file.)
-- • Receipt photos went to a 'media' bucket that doesn't exist, as
--   public links. Receipts now go to a private 'receipts' bucket, each
--   person's in their own folder, shown only through short-lived links.
-- • Emergency info, vaccinations, care team and reminders only accepted
--   the signed-in person, and emergency info and vaccinations also
--   needed a patients row. So nothing could be saved for a dependant,
--   nor for an adult who hadn't filled in their medical profile.
-- • NHIF became SHA in October 2024; payment methods now accept 'sha'.
--
-- WHAT THIS DOES
-- 1. is_self_or_my_dependant(): "yourself, or a dependant you're the
--    guardian of". The same rule 040 gave appointments.
-- 2. emergency_profiles, vaccination_records, care_team and
--    medication_reminders: patient_id may be an account or a dependant
--    profile and nothing else (a trigger checks it), and the owner
--    policy becomes is_self_or_my_dependant(). Deleting an account or a
--    dependant still deletes their rows. Doctors' and admins' existing
--    read policies are untouched.
-- 3. medication_reminders: columns renamed/added to match the app.
-- 4. user_preferences: text size, reduce motion, read aloud, and the
--    monthly medicine budget.
-- 5. medication_costs: dosage and quantity; 'sha' accepted.
-- 6. receipts: 'sha' accepted; the private 'receipts' bucket.
-- ================================================================

BEGIN;

-- ── 1. Yourself, or your dependant ──────────────────────────────
CREATE OR REPLACE FUNCTION public.is_self_or_my_dependant(p_patient_id UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_patient_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.dependent_profiles d
                 WHERE d.id = p_patient_id AND d.guardian_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION public.is_self_or_my_dependant(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_self_or_my_dependant(UUID) TO authenticated;

-- A record's patient must be an account or a dependant profile.
CREATE OR REPLACE FUNCTION public.check_record_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.patient_id)
     AND NOT EXISTS (SELECT 1 FROM public.dependent_profiles WHERE id = NEW.patient_id) THEN
    RAISE EXCEPTION 'This must be for an AfiCare account or a dependant profile';
  END IF;
  RETURN NEW;
END;
$$;

-- Deleting a person deletes their rows in these tables, as the old
-- foreign keys' ON DELETE CASCADE did.
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
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_delete_records_of_removed_user ON public.users;
CREATE TRIGGER trg_delete_records_of_removed_user
AFTER DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.delete_records_of_removed_patient();

DROP TRIGGER IF EXISTS trg_delete_records_of_removed_dependant ON public.dependent_profiles;
CREATE TRIGGER trg_delete_records_of_removed_dependant
AFTER DELETE ON public.dependent_profiles
FOR EACH ROW EXECUTE FUNCTION public.delete_records_of_removed_patient();

-- ── 2. Four tables a guardian saves to for a dependant ──────────
-- emergency_profiles
ALTER TABLE public.emergency_profiles DROP CONSTRAINT IF EXISTS emergency_profiles_patient_id_fkey;
DROP TRIGGER IF EXISTS trg_check_emergency_profiles_patient ON public.emergency_profiles;
CREATE TRIGGER trg_check_emergency_profiles_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.emergency_profiles
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();
DROP POLICY IF EXISTS "Patients own emergency profile" ON public.emergency_profiles;
DROP POLICY IF EXISTS "emergency_profiles_self_or_dependant" ON public.emergency_profiles;
CREATE POLICY "emergency_profiles_self_or_dependant" ON public.emergency_profiles
FOR ALL TO authenticated
USING (is_self_or_my_dependant(patient_id))
WITH CHECK (is_self_or_my_dependant(patient_id));

-- One emergency profile per person: the screen loads it with
-- .maybeSingle(), which fails if there are two. Only added when there
-- are no duplicates already (the pre-check found no rows at all).
DO $$
BEGIN
  IF NOT EXISTS (SELECT patient_id FROM public.emergency_profiles GROUP BY patient_id HAVING count(*) > 1) THEN
    CREATE UNIQUE INDEX IF NOT EXISTS emergency_profiles_one_per_patient
      ON public.emergency_profiles (patient_id);
  END IF;
END;
$$;

-- vaccination_records
ALTER TABLE public.vaccination_records DROP CONSTRAINT IF EXISTS vaccination_records_patient_id_fkey;
DROP TRIGGER IF EXISTS trg_check_vaccination_records_patient ON public.vaccination_records;
CREATE TRIGGER trg_check_vaccination_records_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.vaccination_records
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();
DROP POLICY IF EXISTS "Patients own vaccination records" ON public.vaccination_records;
DROP POLICY IF EXISTS "vaccination_records_self_or_dependant" ON public.vaccination_records;
CREATE POLICY "vaccination_records_self_or_dependant" ON public.vaccination_records
FOR ALL TO authenticated
USING (is_self_or_my_dependant(patient_id))
WITH CHECK (is_self_or_my_dependant(patient_id));

-- care_team
ALTER TABLE public.care_team DROP CONSTRAINT IF EXISTS care_team_patient_id_fkey;
DROP TRIGGER IF EXISTS trg_check_care_team_patient ON public.care_team;
CREATE TRIGGER trg_check_care_team_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.care_team
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();
DROP POLICY IF EXISTS "Patients can manage care team" ON public.care_team;
DROP POLICY IF EXISTS "care_team_self_or_dependant" ON public.care_team;
CREATE POLICY "care_team_self_or_dependant" ON public.care_team
FOR ALL TO authenticated
USING (is_self_or_my_dependant(patient_id))
WITH CHECK (is_self_or_my_dependant(patient_id));

-- medication_reminders
ALTER TABLE public.medication_reminders DROP CONSTRAINT IF EXISTS medication_reminders_patient_id_fkey;
DROP TRIGGER IF EXISTS trg_check_medication_reminders_patient ON public.medication_reminders;
CREATE TRIGGER trg_check_medication_reminders_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.medication_reminders
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();
DROP POLICY IF EXISTS "Patients own medication reminders" ON public.medication_reminders;
DROP POLICY IF EXISTS "medication_reminders_self_or_dependant" ON public.medication_reminders;
CREATE POLICY "medication_reminders_self_or_dependant" ON public.medication_reminders
FOR ALL TO authenticated
USING (is_self_or_my_dependant(patient_id))
WITH CHECK (is_self_or_my_dependant(patient_id));

-- ── 3. medication_reminders columns match the app ───────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = 'medication_reminders'
               AND column_name = 'reminder_times')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_schema = 'public' AND table_name = 'medication_reminders'
                       AND column_name = 'times') THEN
    ALTER TABLE public.medication_reminders RENAME COLUMN reminder_times TO times;
  END IF;
END;
$$;
ALTER TABLE public.medication_reminders ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.medication_reminders ADD COLUMN IF NOT EXISTS prescription_id TEXT;
ALTER TABLE public.medication_reminders ALTER COLUMN start_date DROP NOT NULL;
ALTER TABLE public.medication_reminders ALTER COLUMN start_date SET DEFAULT CURRENT_DATE;

-- ── 4. Settings ─────────────────────────────────────────────────
ALTER TABLE public.user_preferences ADD COLUMN IF NOT EXISTS text_scale NUMERIC NOT NULL DEFAULT 1.0;
ALTER TABLE public.user_preferences ADD COLUMN IF NOT EXISTS reduce_motion BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_preferences ADD COLUMN IF NOT EXISTS text_to_speech BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_preferences ADD COLUMN IF NOT EXISTS monthly_med_budget NUMERIC;
ALTER TABLE public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_text_scale_check;
ALTER TABLE public.user_preferences ADD CONSTRAINT user_preferences_text_scale_check
  CHECK (text_scale BETWEEN 0.5 AND 3.0);
ALTER TABLE public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_monthly_med_budget_check;
ALTER TABLE public.user_preferences ADD CONSTRAINT user_preferences_monthly_med_budget_check
  CHECK (monthly_med_budget IS NULL OR monthly_med_budget >= 0);

-- ── 5. Medicine costs ───────────────────────────────────────────
ALTER TABLE public.medication_costs ADD COLUMN IF NOT EXISTS dosage TEXT;
ALTER TABLE public.medication_costs ADD COLUMN IF NOT EXISTS quantity INTEGER;
ALTER TABLE public.medication_costs DROP CONSTRAINT IF EXISTS medication_costs_quantity_check;
ALTER TABLE public.medication_costs ADD CONSTRAINT medication_costs_quantity_check
  CHECK (quantity IS NULL OR quantity > 0);
ALTER TABLE public.medication_costs DROP CONSTRAINT IF EXISTS medication_costs_payment_method_check;
ALTER TABLE public.medication_costs ADD CONSTRAINT medication_costs_payment_method_check
  CHECK (payment_method IN ('cash', 'sha', 'nhif', 'insurance', 'mpesa', 'subsidized'));

-- ── 6. Receipts ─────────────────────────────────────────────────
ALTER TABLE public.receipts DROP CONSTRAINT IF EXISTS receipts_payment_method_check;
ALTER TABLE public.receipts ADD CONSTRAINT receipts_payment_method_check
  CHECK (payment_method IN ('cash', 'sha', 'nhif', 'insurance', 'mpesa', 'card', 'subsidized'));

-- Private: nobody can open a receipt by its address. Each person's
-- receipts sit in a folder named after their account id.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('receipts', 'receipts', false, 10485760,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'])
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "receipts_owner_read"   ON storage.objects;
DROP POLICY IF EXISTS "receipts_owner_write"  ON storage.objects;
DROP POLICY IF EXISTS "receipts_owner_update" ON storage.objects;
DROP POLICY IF EXISTS "receipts_owner_delete" ON storage.objects;

CREATE POLICY "receipts_owner_read" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "receipts_owner_write" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "receipts_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "receipts_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text);

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'function is_self_or_my_dependant' AS check_name,
         EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_self_or_my_dependant') AS passed
  UNION ALL
  SELECT 2, 'patient keys replaced on 4 tables',
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname IN (
           'emergency_profiles_patient_id_fkey', 'vaccination_records_patient_id_fkey',
           'care_team_patient_id_fkey', 'medication_reminders_patient_id_fkey'))
         AND (SELECT count(*) FROM pg_trigger WHERE tgname IN (
           'trg_check_emergency_profiles_patient', 'trg_check_vaccination_records_patient',
           'trg_check_care_team_patient', 'trg_check_medication_reminders_patient')) = 4
  UNION ALL
  SELECT 3, 'guardian policies on 4 tables',
         (SELECT count(*) FROM pg_policies WHERE policyname IN (
           'emergency_profiles_self_or_dependant', 'vaccination_records_self_or_dependant',
           'care_team_self_or_dependant', 'medication_reminders_self_or_dependant')) = 4
         AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname IN (
           'Patients own emergency profile', 'Patients own vaccination records',
           'Patients can manage care team', 'Patients own medication reminders'))
  UNION ALL
  SELECT 4, 'clean-up when a person is deleted',
         (SELECT count(*) FROM pg_trigger WHERE tgname IN (
           'trg_delete_records_of_removed_user', 'trg_delete_records_of_removed_dependant')) = 2
  UNION ALL
  SELECT 5, 'one emergency profile per person',
         EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'emergency_profiles_one_per_patient')
  UNION ALL
  SELECT 6, 'medication_reminders columns match the app',
         (SELECT count(*) FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'medication_reminders'
            AND column_name IN ('times', 'notes', 'prescription_id')) = 3
         AND EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_schema = 'public' AND table_name = 'medication_reminders'
                       AND column_name = 'start_date' AND is_nullable = 'YES')
  UNION ALL
  SELECT 7, 'user_preferences has the 4 new columns',
         (SELECT count(*) FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'user_preferences'
            AND column_name IN ('text_scale', 'reduce_motion', 'text_to_speech', 'monthly_med_budget')) = 4
  UNION ALL
  SELECT 8, 'medication_costs has dosage and quantity',
         (SELECT count(*) FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'medication_costs'
            AND column_name IN ('dosage', 'quantity')) = 2
  UNION ALL
  SELECT 9, 'SHA accepted for costs and receipts',
         (SELECT count(*) FROM pg_constraint WHERE conname IN (
           'medication_costs_payment_method_check', 'receipts_payment_method_check')
          AND pg_get_constraintdef(oid) LIKE '%sha%') = 2
  UNION ALL
  SELECT 10, 'private receipts bucket',
         EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'receipts' AND public = false)
  UNION ALL
  SELECT 11, 'receipts bucket rules (4)',
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND policyname IN (
           'receipts_owner_read', 'receipts_owner_write', 'receipts_owner_update', 'receipts_owner_delete')) = 4
) checks
ORDER BY n;
