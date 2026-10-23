-- ================================================================
-- 038: Doctor and nurse pictures: gender, photo_url and photo storage
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
-- ================================================================
--
-- WHY
-- Patients see a doctor's or nurse's picture when booking, on Care team,
-- on an appointment and on Today: their uploaded photo if they have one,
-- otherwise a doctor or nurse illustration matching their gender
-- (lib/widgets/provider_avatar.dart). The live database had neither
-- column: a check on 2026-10-21 found users without gender or photo_url
-- and no storage buckets, so 030_provider_photos.sql never ran there.
-- Screens that ask users for gender, photo_url (Care team, the next-visit
-- card) fail outright without them.
--
-- WHAT IT DOES
-- * users.gender ('male', 'female', 'other' or NULL for "prefer not to
--   say"), the same values patients.gender uses. A clinician sets it at
--   sign-up or in their settings; the existing "update own row" policy
--   covers it, and the role/status lock (010) does not touch it.
-- * users.photo_url, the provider-photos bucket and its policies, all as
--   in 030, written so they can be re-run.
-- ================================================================

BEGIN;

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_gender_check;
ALTER TABLE public.users ADD CONSTRAINT users_gender_check
  CHECK (gender IS NULL OR gender IN ('male', 'female', 'other'));

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Public read (patients and facility admins see these); each person
-- writes only inside a folder named after their own user id.
INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-photos', 'provider-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "provider_photos_public_read"  ON storage.objects;
DROP POLICY IF EXISTS "provider_photos_owner_write"  ON storage.objects;
DROP POLICY IF EXISTS "provider_photos_owner_update" ON storage.objects;
DROP POLICY IF EXISTS "provider_photos_owner_delete" ON storage.objects;

CREATE POLICY "provider_photos_public_read" ON storage.objects
FOR SELECT USING (bucket_id = 'provider-photos');

CREATE POLICY "provider_photos_owner_write" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "provider_photos_owner_update" ON storage.objects
FOR UPDATE TO authenticated USING (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "provider_photos_owner_delete" ON storage.objects
FOR DELETE TO authenticated USING (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect three rows: column gender, column photo_url, bucket provider-photos.
SELECT 'column' AS kind, column_name AS name
FROM   information_schema.columns
WHERE  table_schema = 'public' AND table_name = 'users' AND column_name IN ('gender', 'photo_url')
UNION ALL
SELECT 'bucket', id FROM storage.buckets WHERE id = 'provider-photos';
