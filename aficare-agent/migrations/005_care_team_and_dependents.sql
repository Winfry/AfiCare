-- ── Migration 005: Care Team + Dependent Profiles ────────────────────────────
-- Run after 004_prescriptions_appointments.sql

-- ── dependent_profiles ──────────────────────────────────────
-- Children have no Supabase auth account; guardian accesses all their data.
CREATE TABLE IF NOT EXISTS dependent_profiles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guardian_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL,
  date_of_birth DATE,
  gender        TEXT CHECK (gender IN ('male','female','other')),
  relationship  TEXT NOT NULL CHECK (relationship IN ('child','grandchild','sibling','other')),
  blood_type    TEXT,
  medilink_id   TEXT UNIQUE,   -- 'ML-DEP-XXXXXX' prefix, distinct from ML-NBO-
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE dependent_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "guardian_all_dependents" ON dependent_profiles FOR ALL
  USING (guardian_id = auth.uid()) WITH CHECK (guardian_id = auth.uid());
CREATE POLICY "admin_all_dependents" ON dependent_profiles FOR ALL
  USING (get_my_role() = 'admin');

-- ── care_team ────────────────────────────────────────────────
-- NOTE: patient_id has NO FK constraint intentionally —
-- dependent UUIDs (from dependent_profiles) are not in patients(id).
-- RLS enforces legitimate access; FK would reject dependent entries.
CREATE TABLE IF NOT EXISTS care_team (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL,   -- auth.uid() OR dependent_profiles.id
  provider_id     UUID NOT NULL REFERENCES users(id),
  specialty_label TEXT,            -- e.g. 'My Gynaecologist'
  notes           TEXT,
  is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(patient_id, provider_id)
);
ALTER TABLE care_team ENABLE ROW LEVEL SECURITY;
-- Patient reads/writes own entries (patient_id = auth.uid())
CREATE POLICY "patient_select_care_team" ON care_team FOR SELECT USING (patient_id = auth.uid());
CREATE POLICY "patient_insert_care_team" ON care_team FOR INSERT WITH CHECK (patient_id = auth.uid());
CREATE POLICY "patient_update_care_team" ON care_team FOR UPDATE USING (patient_id = auth.uid());
CREATE POLICY "patient_delete_care_team" ON care_team FOR DELETE USING (patient_id = auth.uid());
-- Guardian reads/writes dependent entries
CREATE POLICY "guardian_select_dep_care_team" ON care_team FOR SELECT
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_insert_dep_care_team" ON care_team FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_update_dep_care_team" ON care_team FOR UPDATE
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_delete_dep_care_team" ON care_team FOR DELETE
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
-- Provider sees their own care team appearances
CREATE POLICY "provider_select_care_team" ON care_team FOR SELECT
  USING (provider_id = auth.uid() AND get_my_role() IN ('doctor','nurse'));
CREATE POLICY "admin_all_care_team" ON care_team FOR ALL USING (get_my_role() = 'admin');

-- ── Extend existing table RLS for guardian → dependent access ─
CREATE POLICY "guardian_read_dep_prescriptions" ON prescriptions FOR SELECT
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_read_dep_appointments" ON appointments FOR SELECT
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_insert_dep_appointments" ON appointments FOR INSERT
  WITH CHECK (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid()));
CREATE POLICY "guardian_cancel_dep_appointments" ON appointments FOR UPDATE
  USING (patient_id IN (SELECT id FROM dependent_profiles WHERE guardian_id = auth.uid())
    AND status IN ('pending','confirmed'));

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_care_team_patient_id   ON care_team(patient_id);
CREATE INDEX IF NOT EXISTS idx_care_team_provider_id  ON care_team(provider_id);
CREATE INDEX IF NOT EXISTS idx_dependents_guardian_id ON dependent_profiles(guardian_id);
CREATE INDEX IF NOT EXISTS idx_dependents_medilink    ON dependent_profiles(medilink_id);
