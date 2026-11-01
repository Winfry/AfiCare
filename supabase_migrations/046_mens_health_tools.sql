-- 046: Men's health — the rebuilt Sexual health, Metabolic health and
-- Lifestyle check-ups.
--
-- 1. Removes results saved by the old broken tools. Those three tools
--    asked the heart-risk questions, so their saved "Sexual health" (etc.)
--    results hold heart answers and a meaningless level. They are the rows
--    of those three types whose answers are a plain list; the rebuilt
--    tools save answers by question. (Pre-check: 1 such row.)
-- 2. Each tool may only save its own levels (the old rule allowed any of
--    six words for any tool, and none of the new ones).
-- 3. Tidies access: only signed-in people, only their own rows, and only
--    read / add / delete (nobody needs to edit a past result).
-- Safe to run more than once.

BEGIN;

-- ── 1. results from the broken tools ────────────────────────────
DELETE FROM public.mens_health_screenings
WHERE screening_type IN ('lifestyle', 'erectile', 'metabolic')
  AND jsonb_typeof(responses -> 'answers') IS DISTINCT FROM 'object';

-- ── 2. levels per tool ──────────────────────────────────────────
ALTER TABLE public.mens_health_screenings
  DROP CONSTRAINT IF EXISTS mens_health_screenings_risk_level_check;
ALTER TABLE public.mens_health_screenings
  DROP CONSTRAINT IF EXISTS mens_health_screenings_level_for_tool;
ALTER TABLE public.mens_health_screenings
  ADD CONSTRAINT mens_health_screenings_level_for_tool CHECK (
    (screening_type = 'cardiovascular' AND risk_level IN ('low', 'moderate', 'high', 'very_high'))
    OR (screening_type = 'prostate'  AND risk_level IN ('mild', 'moderate', 'severe'))
    OR (screening_type = 'erectile'  AND risk_level IN ('none', 'mild', 'mild_moderate', 'moderate', 'severe', 'unscored'))
    OR (screening_type = 'metabolic' AND risk_level IN ('unlikely', 'unclear', 'likely'))
    OR (screening_type = 'lifestyle' AND risk_level IN ('on_track', 'some', 'several'))
  );

-- ── 3. access ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "Patients own mens health screenings" ON public.mens_health_screenings;
DROP POLICY IF EXISTS "mens_health_screenings_own" ON public.mens_health_screenings;
CREATE POLICY "mens_health_screenings_own" ON public.mens_health_screenings
FOR ALL TO authenticated
USING (patient_id = auth.uid())
WITH CHECK (patient_id = auth.uid());

REVOKE ALL ON public.mens_health_screenings FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.mens_health_screenings TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'no results left from the broken tools' AS check_name,
         NOT EXISTS (SELECT 1 FROM public.mens_health_screenings
                     WHERE screening_type IN ('lifestyle', 'erectile', 'metabolic')
                       AND jsonb_typeof(responses -> 'answers') IS DISTINCT FROM 'object') AS passed
  UNION ALL
  SELECT 2, 'each tool saves only its own levels',
         EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conname = 'mens_health_screenings_level_for_tool'
                   AND conrelid = 'public.mens_health_screenings'::regclass)
         AND NOT EXISTS (SELECT 1 FROM pg_constraint
                         WHERE conname = 'mens_health_screenings_risk_level_check'
                           AND conrelid = 'public.mens_health_screenings'::regclass)
  UNION ALL
  SELECT 3, 'each man sees and adds only his own results',
         (SELECT count(*) FROM pg_policies
          WHERE schemaname = 'public' AND tablename = 'mens_health_screenings') = 1
         AND EXISTS (SELECT 1 FROM pg_policies
                     WHERE schemaname = 'public' AND tablename = 'mens_health_screenings'
                       AND policyname = 'mens_health_screenings_own'
                       AND with_check IS NOT NULL)
  UNION ALL
  SELECT 4, 'signed-out visitors have no access',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND table_name = 'mens_health_screenings'
                       AND grantee = 'anon')
  UNION ALL
  SELECT 5, 'signed-in people may only read, add and delete',
         (SELECT string_agg(privilege_type, ',' ORDER BY privilege_type)
          FROM information_schema.role_table_grants
          WHERE table_schema = 'public' AND table_name = 'mens_health_screenings'
            AND grantee = 'authenticated') = 'DELETE,INSERT,SELECT'
  UNION ALL
  SELECT 6, 'row level security still on',
         (SELECT relrowsecurity FROM pg_class
          WHERE oid = 'public.mens_health_screenings'::regclass)
) checks
ORDER BY n;
