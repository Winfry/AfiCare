-- ================================================================
-- 041: A proper pregnancy record
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run 040 first. Safe to run more than once.
-- ================================================================
--
-- WHY
-- • Maternal care saved the last-period date into patients.notes, a
--   column the live database doesn't have, so it never saved: no week,
--   no trimester, no due date.
-- • anc_visits.patient_id had to be a patients row. A patient who had
--   never saved her medical profile has none, so her first visit failed.
-- • Women's health and Maternal care kept pregnancy in two unrelated
--   places. (The pre-check found no data in either, so nothing moves.)
--
-- WHAT THIS DOES
-- • pregnancies: one row per pregnancy. At most one ongoing per person;
--   past ones stay, so a second pregnancy never mixes with the first.
--   The due date comes from the last period (LMP + 280 days), a scan,
--   or a clinician; due_date_source says which.
-- • anc_visits belong to a pregnancy (pregnancy_id) and to an account
--   (patient_id → users, no longer → patients).
-- • Who can see a pregnancy and its visits: the woman herself (read and
--   write), her doctors and nurses (read only: care team, an appointment
--   with her, or a consultation with her), and admins.
--   provider_can_see_patient() holds that rule so both tables match.
-- ================================================================

BEGIN;

-- ── 1. Who counts as "her doctors and nurses" ───────────────────
CREATE OR REPLACE FUNCTION public.provider_can_see_patient(p_patient_id UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT get_my_role() IN ('doctor', 'nurse') AND (
    EXISTS (SELECT 1 FROM public.care_team ct
            WHERE ct.provider_id = auth.uid() AND ct.patient_id = p_patient_id)
    OR EXISTS (SELECT 1 FROM public.appointments a
               WHERE a.provider_id = auth.uid() AND a.patient_id = p_patient_id
                 AND a.status <> 'cancelled')
    -- consultations.patient_id holds the MediLink ID on the live database
    -- (older rows may hold the account id), so both are accepted.
    OR EXISTS (SELECT 1 FROM public.consultations c
               JOIN public.users u ON u.id = p_patient_id
               WHERE c.provider_id::text = auth.uid()::text
                 AND c.patient_id::text IN (u.id::text, u.medilink_id))
  );
$$;

REVOKE ALL ON FUNCTION public.provider_can_see_patient(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_can_see_patient(UUID) TO authenticated;

-- ── 2. The pregnancies table ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pregnancies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  -- First day of the last period before the pregnancy, when known.
  lmp_date DATE,
  due_date DATE NOT NULL,
  due_date_source TEXT NOT NULL DEFAULT 'lmp'
    CHECK (due_date_source IN ('lmp', 'scan', 'clinician')),
  status TEXT NOT NULL DEFAULT 'ongoing'
    CHECK (status IN ('ongoing', 'ended')),
  -- How it ended, in the woman's own choice of words: 'not_said' is
  -- always accepted.
  outcome TEXT
    CHECK (outcome IN ('birth', 'loss', 'other', 'not_said')),
  ended_on DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pregnancies_end_fields CHECK (
    (status = 'ongoing' AND outcome IS NULL AND ended_on IS NULL)
    OR (status = 'ended' AND outcome IS NOT NULL AND ended_on IS NOT NULL)
  ),
  CONSTRAINT pregnancies_lmp_when_from_lmp CHECK (due_date_source <> 'lmp' OR lmp_date IS NOT NULL),
  CONSTRAINT pregnancies_lmp_before_due CHECK (lmp_date IS NULL OR lmp_date < due_date)
);

CREATE UNIQUE INDEX IF NOT EXISTS pregnancies_one_ongoing
  ON public.pregnancies (patient_id) WHERE status = 'ongoing';
CREATE INDEX IF NOT EXISTS pregnancies_patient_id ON public.pregnancies (patient_id);

DROP TRIGGER IF EXISTS pregnancies_updated_at ON public.pregnancies;
CREATE TRIGGER pregnancies_updated_at
BEFORE UPDATE ON public.pregnancies
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.pregnancies ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pregnancies TO authenticated;

DROP POLICY IF EXISTS "pregnancies_own" ON public.pregnancies;
DROP POLICY IF EXISTS "pregnancies_select_her_providers" ON public.pregnancies;
DROP POLICY IF EXISTS "pregnancies_select_admin" ON public.pregnancies;

CREATE POLICY "pregnancies_own" ON public.pregnancies
FOR ALL TO authenticated
USING (patient_id = auth.uid())
WITH CHECK (patient_id = auth.uid());

CREATE POLICY "pregnancies_select_her_providers" ON public.pregnancies
FOR SELECT TO authenticated
USING (provider_can_see_patient(patient_id));

CREATE POLICY "pregnancies_select_admin" ON public.pregnancies
FOR SELECT TO authenticated
USING (get_my_role() = 'admin');

-- ── 3. ANC visits belong to a pregnancy and to an account ──────
ALTER TABLE public.anc_visits
  ADD COLUMN IF NOT EXISTS pregnancy_id UUID REFERENCES public.pregnancies(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS anc_visits_pregnancy_id ON public.anc_visits (pregnancy_id);

-- Every visit needs a pregnancy. Old visits without one (the pre-check
-- found none) would block this, so it only applies when there are none.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.anc_visits WHERE pregnancy_id IS NULL) THEN
    ALTER TABLE public.anc_visits ALTER COLUMN pregnancy_id SET NOT NULL;
  END IF;
END;
$$;

ALTER TABLE public.anc_visits DROP CONSTRAINT IF EXISTS anc_visits_patient_id_fkey;
ALTER TABLE public.anc_visits
  ADD CONSTRAINT anc_visits_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- A visit and its pregnancy must be the same woman's.
CREATE OR REPLACE FUNCTION public.check_anc_visit_pregnancy()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.pregnancy_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pregnancies p
    WHERE p.id = NEW.pregnancy_id AND p.patient_id = NEW.patient_id
  ) THEN
    RAISE EXCEPTION 'This visit and this pregnancy belong to different people';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_anc_visit_pregnancy ON public.anc_visits;
CREATE TRIGGER trg_check_anc_visit_pregnancy
BEFORE INSERT OR UPDATE OF patient_id, pregnancy_id ON public.anc_visits
FOR EACH ROW EXECUTE FUNCTION public.check_anc_visit_pregnancy();

-- Her doctors and nurses: the same rule as for the pregnancy itself.
DROP POLICY IF EXISTS "Providers read ANC visits" ON public.anc_visits;
DROP POLICY IF EXISTS "anc_visits_select_her_providers" ON public.anc_visits;
CREATE POLICY "anc_visits_select_her_providers" ON public.anc_visits
FOR SELECT TO authenticated
USING (provider_can_see_patient(patient_id));

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'table pregnancies' AS check_name,
         to_regclass('public.pregnancies') IS NOT NULL AS passed
  UNION ALL
  SELECT 2, 'one ongoing pregnancy per person',
         EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'pregnancies_one_ongoing')
  UNION ALL
  SELECT 3, 'pregnancies row level security on',
         (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.pregnancies'))
  UNION ALL
  SELECT 4, 'pregnancies policies (3)',
         (SELECT count(*) FROM pg_policies WHERE tablename = 'pregnancies'
          AND policyname IN ('pregnancies_own', 'pregnancies_select_her_providers',
                             'pregnancies_select_admin')) = 3
  UNION ALL
  SELECT 5, 'anc_visits.pregnancy_id required',
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'anc_visits'
                   AND column_name = 'pregnancy_id' AND is_nullable = 'NO')
  UNION ALL
  SELECT 6, 'anc_visits.patient_id points at users',
         EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conname = 'anc_visits_patient_id_fkey'
                   AND confrelid = 'public.users'::regclass)
  UNION ALL
  SELECT 7, 'trigger trg_check_anc_visit_pregnancy',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_check_anc_visit_pregnancy')
  UNION ALL
  SELECT 8, 'anc_visits provider policy replaced',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'anc_visits'
                 AND policyname = 'anc_visits_select_her_providers')
         AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'anc_visits'
                         AND policyname = 'Providers read ANC visits')
  UNION ALL
  SELECT 9, 'function provider_can_see_patient',
         EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'provider_can_see_patient')
) checks
ORDER BY n;
