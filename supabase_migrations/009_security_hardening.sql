-- ================================================================
-- 009_security_hardening.sql
--
-- Closes two gaps found in a full security audit (2026-09-01):
--
--  A) `referrals`, `triage_assessments`, `households`, `patient_modules`
--     were dropped and recreated by 008_canonical_schema.sql with RLS
--     left OFF (Postgres default for a freshly created table). Any
--     authenticated user — and possibly the public anon key, see the
--     note on `users` below — could read/write every patient's
--     referrals and triage records system-wide.
--
--  B) Patient PIN login verified the PIN and derived the Supabase auth
--     password entirely on the client: the bcrypt `pin_hash` was
--     fetched via the anon key pre-login and checked in Dart, and the
--     derivation secret was a hardcoded fallback shipped in every
--     public APK/web build. This migration moves the PIN hash into a
--     table with RLS enabled and ZERO policies — reachable only by the
--     service-role key used inside the new `patient-auth` Edge
--     Function (see supabase/functions/patient-auth). No client, no
--     matter how the anon-key policies on `users` drift in the future,
--     can ever read a PIN hash again.
--
-- Run this AFTER every file already applied to the project (008 and
-- everything in aficare-agent/migrations/ — see supabase_migrations/
-- README.md for the full applied order). Idempotent: safe to re-run.
-- ================================================================

BEGIN;

-- ------------------------------------------------------------------
-- PART A: RLS on tables 008 left unprotected
-- ------------------------------------------------------------------

-- referrals: patient_id is the TEXT medilink_id (own or dependent's),
-- from/to_provider_id are auth.uid()s.
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "patient_select_own_referrals"    ON public.referrals;
DROP POLICY IF EXISTS "guardian_select_dep_referrals"   ON public.referrals;
DROP POLICY IF EXISTS "provider_select_own_referrals"   ON public.referrals;
DROP POLICY IF EXISTS "provider_insert_referrals"       ON public.referrals;
DROP POLICY IF EXISTS "provider_update_own_referrals"   ON public.referrals;
DROP POLICY IF EXISTS "admin_all_referrals"              ON public.referrals;

CREATE POLICY "patient_select_own_referrals" ON public.referrals FOR SELECT
  USING (patient_id = (SELECT medilink_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "guardian_select_dep_referrals" ON public.referrals FOR SELECT
  USING (patient_id IN (SELECT medilink_id FROM public.dependent_profiles WHERE guardian_id = auth.uid()));

CREATE POLICY "provider_select_own_referrals" ON public.referrals FOR SELECT
  USING (from_provider_id = auth.uid() OR to_provider_id = auth.uid());

CREATE POLICY "provider_insert_referrals" ON public.referrals FOR INSERT
  WITH CHECK (from_provider_id = auth.uid() AND get_my_role() IN ('doctor', 'nurse', 'chw'));

CREATE POLICY "provider_update_own_referrals" ON public.referrals FOR UPDATE
  USING (from_provider_id = auth.uid() OR to_provider_id = auth.uid());

CREATE POLICY "admin_all_referrals" ON public.referrals FOR ALL
  USING (get_my_role() = 'admin');

-- triage_assessments: same patient_id shape; provider_id/assessed_by are auth.uid()s.
ALTER TABLE public.triage_assessments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "patient_select_own_triage"   ON public.triage_assessments;
DROP POLICY IF EXISTS "guardian_select_dep_triage"  ON public.triage_assessments;
DROP POLICY IF EXISTS "provider_select_own_triage"  ON public.triage_assessments;
DROP POLICY IF EXISTS "provider_insert_triage"      ON public.triage_assessments;
DROP POLICY IF EXISTS "provider_update_own_triage"  ON public.triage_assessments;
DROP POLICY IF EXISTS "admin_all_triage"             ON public.triage_assessments;

CREATE POLICY "patient_select_own_triage" ON public.triage_assessments FOR SELECT
  USING (patient_id = (SELECT medilink_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "guardian_select_dep_triage" ON public.triage_assessments FOR SELECT
  USING (patient_id IN (SELECT medilink_id FROM public.dependent_profiles WHERE guardian_id = auth.uid()));

CREATE POLICY "provider_select_own_triage" ON public.triage_assessments FOR SELECT
  USING (provider_id = auth.uid() OR assessed_by = auth.uid());

CREATE POLICY "provider_insert_triage" ON public.triage_assessments FOR INSERT
  WITH CHECK (assessed_by = auth.uid() AND get_my_role() IN ('doctor', 'nurse', 'chw'));

CREATE POLICY "provider_update_own_triage" ON public.triage_assessments FOR UPDATE
  USING (provider_id = auth.uid() OR assessed_by = auth.uid());

CREATE POLICY "admin_all_triage" ON public.triage_assessments FOR ALL
  USING (get_my_role() = 'admin');

-- households: CHW-owned, no per-patient row. Renamed from chv_households
-- in 008 — the old policy on chv_households no longer applies to this table.
ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chw_all_own_households" ON public.households;
DROP POLICY IF EXISTS "admin_all_households"    ON public.households;

CREATE POLICY "chw_all_own_households" ON public.households FOR ALL
  USING (chv_id = auth.uid() AND get_my_role() = 'chw')
  WITH CHECK (chv_id = auth.uid() AND get_my_role() = 'chw');

CREATE POLICY "admin_all_households" ON public.households FOR ALL
  USING (get_my_role() = 'admin');

-- chv_visits / community_screenings: re-assert RLS regardless of whether
-- remaining_tables.sql / tier2_medication_chw.sql already ran against this
-- database — ENABLE ROW LEVEL SECURITY is idempotent and safe either way.
ALTER TABLE public.chv_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_screenings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chw_all_own_visits" ON public.chv_visits;
DROP POLICY IF EXISTS "patient_select_own_visits" ON public.chv_visits;
DROP POLICY IF EXISTS "admin_all_visits" ON public.chv_visits;

CREATE POLICY "chw_all_own_visits" ON public.chv_visits FOR ALL
  USING (chv_id = auth.uid() AND get_my_role() = 'chw')
  WITH CHECK (chv_id = auth.uid() AND get_my_role() = 'chw');

CREATE POLICY "patient_select_own_visits" ON public.chv_visits FOR SELECT
  USING (patient_id = (SELECT medilink_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "admin_all_visits" ON public.chv_visits FOR ALL
  USING (get_my_role() = 'admin');

DROP POLICY IF EXISTS "chw_all_own_screenings" ON public.community_screenings;
DROP POLICY IF EXISTS "patient_select_own_screenings" ON public.community_screenings;
DROP POLICY IF EXISTS "admin_all_screenings" ON public.community_screenings;

CREATE POLICY "chw_all_own_screenings" ON public.community_screenings FOR ALL
  USING (chv_id = auth.uid() AND get_my_role() = 'chw')
  WITH CHECK (chv_id = auth.uid() AND get_my_role() = 'chw');

CREATE POLICY "patient_select_own_screenings" ON public.community_screenings FOR SELECT
  USING (patient_id = (SELECT medilink_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "admin_all_screenings" ON public.community_screenings FOR ALL
  USING (get_my_role() = 'admin');

-- patient_modules: not wired into the app yet (see 008's own note). Enable
-- RLS with an admin-only policy so it defaults to closed, not open, the day
-- someone does start using it — the CI guardrail below still requires
-- whoever adds the real feature to add real patient/provider policies.
ALTER TABLE public.patient_modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_patient_modules" ON public.patient_modules;
CREATE POLICY "admin_all_patient_modules" ON public.patient_modules FOR ALL
  USING (get_my_role() = 'admin');

-- ------------------------------------------------------------------
-- PART B: move PIN credentials out of `users` into a vault-like table
-- ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.patient_credentials (
  user_id         uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  pin_hash        text NOT NULL,
  failed_attempts integer NOT NULL DEFAULT 0,
  locked_until    timestamptz,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- RLS enabled, NO policies at all — deliberately unreachable by anon or
-- authenticated roles. Only the service-role key (used exclusively inside
-- the patient-auth Edge Function) bypasses RLS and can read/write this
-- table. This is the guardrail against a repeat of the `users` "allow all"
-- policy incident: even a misconfigured policy on `users` can no longer
-- leak a PIN hash, because the hash isn't there anymore.
ALTER TABLE public.patient_credentials ENABLE ROW LEVEL SECURITY;

-- Backfill from the old column, then drop it so there is exactly one
-- place PIN hashes can ever live.
INSERT INTO public.patient_credentials (user_id, pin_hash)
SELECT id, pin_hash FROM public.users
WHERE pin_hash IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.users DROP COLUMN IF EXISTS pin_hash;

COMMIT;

-- ================================================================
-- VERIFY after running (all rows should show rowsecurity = true, and
-- patient_credentials should show zero policies):
--
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- SELECT tablename, policyname FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'patient_credentials';
-- ================================================================
