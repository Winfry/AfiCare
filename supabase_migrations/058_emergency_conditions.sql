-- ================================================================
-- 058: Step 4d-5 — a child's long-term conditions on the emergency page
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
--
-- WHY
--   The emergency page showed conditions but nothing could change them.
--   A parent can now edit a child's conditions there (an adult's own come
--   from Edit profile). They are kept in emergency_profiles.chronic_conditions,
--   which the original table design has; this makes sure it exists.
-- ================================================================

ALTER TABLE public.emergency_profiles
  ADD COLUMN IF NOT EXISTS chronic_conditions JSONB DEFAULT '[]'::jsonb;

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT 'emergency details can hold conditions' AS check_name,
       CASE WHEN EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = 'emergency_profiles'
           AND column_name = 'chronic_conditions'
       ) THEN 'ok' ELSE 'MISSING' END AS result;
