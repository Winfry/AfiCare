-- ================================================================
-- 047: Mental wellbeing and Women's health are private to the patient
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
--
-- WHY (from checks/047_precheck.sql, run live 2026-11-03)
--   * Mental wellbeing (mood_entries, mental_health_screenings): the page
--     promises "nobody sees this unless you choose to share it", but
--     doctors on the patient's care team could read it, and the admin
--     could read AND change it. No doctor screen uses it.
--   * Women's health (cycle, periods, symptoms, screening dates) was
--     saved inside the account row, users.metadata -> 'maternal_health'.
--     Every doctor, nurse, radiologist, CHW and facility admin can read
--     every account row (policy users_select_staff, from 034), so any of
--     them, at any facility, could read it.
--   Decision (2026-11-03): both are for the patient only.
--
-- WHAT
--   1. mood_entries and mental_health_screenings: every policy replaced
--      by one: the patient reads and adds her own, nobody else. Signed-out
--      visitors get no access at all.
--   2. New table womens_health_records: one row per patient, readable
--      and writable by her only.
--   3. Any Women's health details already in users.metadata are copied
--      there and then removed from the account row. (Pre-check: none
--      yet.) The updated app also moves an old copy over by itself, so
--      running this before or after the app update is fine; running it
--      again later picks up anything the old app wrote in between.
--
-- Pregnancies are not changed: a pregnancy started from Women's health
-- is shared with the clinicians caring for her, as on Maternal care
-- (041), and the page says so.
-- ================================================================

BEGIN;

-- ── 1. Mental wellbeing: hers only ─────────────────────────────
DO $$
DECLARE
  t text;
  p record;
BEGIN
  FOREACH t IN ARRAY ARRAY['mood_entries', 'mental_health_screenings'] LOOP
    FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = t LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated '
      'USING (patient_id = auth.uid()) WITH CHECK (patient_id = auth.uid())',
      t || '_own', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
    EXECUTE format('GRANT SELECT, INSERT, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- ── 2. Women's health: its own table, hers only ────────────────
CREATE TABLE IF NOT EXISTS public.womens_health_records (
  patient_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  record     JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT womens_health_records_is_object CHECK (jsonb_typeof(record) = 'object')
);

ALTER TABLE public.womens_health_records ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies
           WHERE schemaname = 'public' AND tablename = 'womens_health_records' LOOP
    EXECUTE format('DROP POLICY %I ON public.womens_health_records', p.policyname);
  END LOOP;
END $$;

CREATE POLICY "womens_health_records_own" ON public.womens_health_records
FOR ALL TO authenticated
USING (patient_id = auth.uid())
WITH CHECK (patient_id = auth.uid());

REVOKE ALL ON public.womens_health_records FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.womens_health_records TO authenticated;

-- ── 3. Move anything already in the account row ────────────────
-- A copy already in the new table is newer (the updated app writes
-- there), so it is kept.
INSERT INTO public.womens_health_records (patient_id, record, updated_at)
SELECT u.id, u.metadata::jsonb -> 'maternal_health', now()
FROM   public.users u
WHERE  jsonb_typeof(u.metadata::jsonb -> 'maternal_health') = 'object'
ON CONFLICT (patient_id) DO NOTHING;

-- Then take it out of the account row. The column may be json or jsonb.
DO $$
DECLARE
  v_type text;
BEGIN
  SELECT data_type INTO v_type FROM information_schema.columns
  WHERE  table_schema = 'public' AND table_name = 'users' AND column_name = 'metadata';
  IF v_type = 'jsonb' THEN
    UPDATE public.users SET metadata = metadata - 'maternal_health'
    WHERE  metadata ? 'maternal_health';
  ELSIF v_type = 'json' THEN
    UPDATE public.users SET metadata = (metadata::jsonb - 'maternal_health')::json
    WHERE  metadata::jsonb ? 'maternal_health';
  END IF;
END $$;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'mood entries: only her own (one policy)' AS check_name,
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'mood_entries') = 1
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'mood_entries'
                     AND policyname = 'mood_entries_own' AND with_check IS NOT NULL) AS passed
  UNION ALL
  SELECT 2, 'mental health questionnaires: only her own (one policy)',
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'mental_health_screenings') = 1
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'mental_health_screenings'
                     AND policyname = 'mental_health_screenings_own' AND with_check IS NOT NULL)
  UNION ALL
  SELECT 3, 'women''s health table exists, only her own (one policy)',
         to_regclass('public.womens_health_records') IS NOT NULL
         AND (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'womens_health_records') = 1
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'womens_health_records'
                     AND policyname = 'womens_health_records_own' AND with_check IS NOT NULL)
  UNION ALL
  SELECT 4, 'row level security on for all three',
         (SELECT bool_and(relrowsecurity) FROM pg_class
          WHERE relnamespace = 'public'::regnamespace
            AND relname IN ('mood_entries', 'mental_health_screenings', 'womens_health_records'))
  UNION ALL
  SELECT 5, 'signed-out visitors have no access to any of the three',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND grantee = 'anon'
                       AND table_name IN ('mood_entries', 'mental_health_screenings', 'womens_health_records'))
  UNION ALL
  SELECT 6, 'no women''s health details left in any account row',
         NOT EXISTS (SELECT 1 FROM public.users WHERE (metadata::jsonb) ? 'maternal_health')
  UNION ALL
  SELECT 7, 'nobody can change their own role (lock from 010 still there)',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.users'::regclass
                 AND tgname = 'trg_enforce_role_status_lock')
) checks
ORDER BY n;
