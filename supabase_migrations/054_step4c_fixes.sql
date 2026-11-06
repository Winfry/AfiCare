-- ================================================================
-- 054: Step 4c — the database half of removing the "fake" buttons
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 041 (provider_can_see_patient) and 042
-- (is_self_or_my_dependant). Safe to run more than once.
--
-- Checked against checks/053_step4c_check.sql (run live 2026-11-06):
--   * user_preferences had no bold_text; patients only insurance_id
--   * no patient-photos bucket; users "update own profile" lets a
--     patient set her own photo_url (the triggers on users guard only
--     role/status and a PIN account's phone)
--   * medication_reminders.frequency has no CHECK rule, so the app's
--     new five_times / six_times need nothing here
-- Run live 2026-11-06: 5 ok.
--
-- WHY
--   A  Accessibility  "Bold text" is now a real, saved setting, so
--                     user_preferences needs somewhere to keep it.
--   B  Insurance      Edit profile asked for the insurer's name and
--                     threw it away: patients only had insurance_id
--                     (the policy number).
--   C  Photo          "Change photo" did nothing. A patient's face is
--                     part of her health record, so it goes in a
--                     PRIVATE bucket: she (and a guardian, for a
--                     dependant) may put and remove it; she, her
--                     guardian and the clinicians caring for her
--                     (provider_can_see_patient, the rule pregnancies
--                     and ANC visits use) may look at it. Nobody gets a
--                     public link. Doctors' photos stay public, as now.
-- ================================================================

BEGIN;

-- ── A. Bold text ────────────────────────────────────────────────
ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS bold_text BOOLEAN NOT NULL DEFAULT false;

-- ── B. Insurance provider ───────────────────────────────────────
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS insurance_provider TEXT;
ALTER TABLE public.patients DROP CONSTRAINT IF EXISTS patients_insurance_provider_length;
ALTER TABLE public.patients
  ADD CONSTRAINT patients_insurance_provider_length
  CHECK (insurance_provider IS NULL OR char_length(insurance_provider) <= 100);

-- ── C. Private patient photos ───────────────────────────────────
-- 5 MB is far more than an 800×800 photo needs; only pictures.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('patient-photos', 'patient-photos', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Whose photo a stored file is: its first folder, when that is a valid
-- id (anything else belongs to nobody, so every rule below says no).
CREATE OR REPLACE FUNCTION public.patient_photo_owner(p_name TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
           WHEN (storage.foldername(p_name))[1]
                ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           THEN ((storage.foldername(p_name))[1])::uuid
         END
$$;

DROP POLICY IF EXISTS "patient_photos_read"   ON storage.objects;
DROP POLICY IF EXISTS "patient_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "patient_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "patient_photos_delete" ON storage.objects;

CREATE POLICY "patient_photos_read" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'patient-photos'
  AND (
    is_self_or_my_dependant(patient_photo_owner(name))
    OR provider_can_see_patient(patient_photo_owner(name))
  )
);

CREATE POLICY "patient_photos_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'patient-photos'
  AND is_self_or_my_dependant(patient_photo_owner(name))
);

CREATE POLICY "patient_photos_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'patient-photos'
  AND is_self_or_my_dependant(patient_photo_owner(name))
)
WITH CHECK (
  bucket_id = 'patient-photos'
  AND is_self_or_my_dependant(patient_photo_owner(name))
);

CREATE POLICY "patient_photos_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'patient-photos'
  AND is_self_or_my_dependant(patient_photo_owner(name))
);

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'user_preferences.bold_text exists' AS check_name,
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'user_preferences'
                   AND column_name = 'bold_text') AS passed
  UNION ALL
  SELECT 2, 'patients.insurance_provider exists',
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'patients'
                   AND column_name = 'insurance_provider')
  UNION ALL
  SELECT 3, 'patient-photos bucket is private',
         EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'patient-photos' AND public = false)
  UNION ALL
  SELECT 4, 'four patient-photo rules',
         (SELECT COUNT(*) FROM pg_policies
          WHERE schemaname = 'storage' AND tablename = 'objects'
            AND policyname LIKE 'patient_photos_%') = 4
  UNION ALL
  SELECT 5, 'a file outside an id folder belongs to nobody',
         patient_photo_owner('not-an-id/photo') IS NULL
         AND patient_photo_owner('00000000-0000-0000-0000-000000000001/photo')
             = '00000000-0000-0000-0000-000000000001'::uuid
) t ORDER BY n;
