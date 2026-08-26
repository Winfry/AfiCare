-- Tier 1 Life-Saving Features: Mental Health, ANC, Vaccinations, Emergency Profile
-- Run this in Supabase SQL Editor

-- 1. Mental Health Screenings (PHQ-9, GAD-7)
CREATE TABLE IF NOT EXISTS mental_health_screenings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  tool_type TEXT NOT NULL CHECK (tool_type IN ('PHQ-9', 'GAD-7')),
  answers JSONB NOT NULL DEFAULT '[]'::jsonb,
  total_score INT NOT NULL DEFAULT 0,
  severity TEXT NOT NULL DEFAULT 'none',
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mh_screenings_patient ON mental_health_screenings(patient_id, completed_at DESC);

-- 2. Mood Entries
CREATE TABLE IF NOT EXISTS mood_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  mood INT NOT NULL CHECK (mood BETWEEN 1 AND 5),
  journal TEXT,
  factors JSONB DEFAULT '[]'::jsonb,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mood_entries_patient ON mood_entries(patient_id, recorded_at DESC);

-- 3. ANC Visits
CREATE TABLE IF NOT EXISTS anc_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  visit_number INT NOT NULL DEFAULT 1,
  gestational_weeks INT NOT NULL DEFAULT 0,
  trimester TEXT NOT NULL CHECK (trimester IN ('first', 'second', 'third')),
  visit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  fundal_height DECIMAL(5,1),
  fetal_heart_rate INT,
  systolic_bp INT,
  diastolic_bp INT,
  weight DECIMAL(5,1),
  hemoglobin DECIMAL(4,1),
  urine_protein TEXT,
  urine_glucose TEXT,
  hiv_tested BOOLEAN,
  hiv_result TEXT,
  notes TEXT,
  danger_signs JSONB DEFAULT '[]'::jsonb,
  next_visit_date TEXT,
  facility TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_anc_visits_patient ON anc_visits(patient_id, visit_date DESC);

-- 4. Vaccination Records
CREATE TABLE IF NOT EXISTS vaccination_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  vaccine_name TEXT NOT NULL,
  vaccine_type TEXT,
  date_given TIMESTAMPTZ NOT NULL DEFAULT now(),
  next_due_date TIMESTAMPTZ,
  facility TEXT,
  batch_number TEXT,
  administered_by TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'due', 'overdue', 'skipped')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vaccination_records_patient ON vaccination_records(patient_id, date_given DESC);

-- 5. Emergency Profiles
CREATE TABLE IF NOT EXISTS emergency_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  blood_type TEXT,
  allergies JSONB DEFAULT '[]'::jsonb,
  chronic_conditions JSONB DEFAULT '[]'::jsonb,
  current_medications JSONB DEFAULT '[]'::jsonb,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  emergency_contact_relationship TEXT,
  emergency_contact2_name TEXT,
  emergency_contact2_phone TEXT,
  emergency_contact2_relationship TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_emergency_profiles_patient ON emergency_profiles(patient_id);

-- Enable Row Level Security
ALTER TABLE mental_health_screenings ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE anc_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccination_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies: patients can read/write their own data
CREATE POLICY "Patients own mental health screenings"
  ON mental_health_screenings FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Patients own mood entries"
  ON mood_entries FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Patients own ANC visits"
  ON anc_visits FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Patients own vaccination records"
  ON vaccination_records FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Patients own emergency profile"
  ON emergency_profiles FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

-- Providers can read their patients' data
CREATE POLICY "Providers read mental health screenings"
  ON mental_health_screenings FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = mental_health_screenings.patient_id
  ));

CREATE POLICY "Providers read mood entries"
  ON mood_entries FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = mood_entries.patient_id
  ));

CREATE POLICY "Providers read ANC visits"
  ON anc_visits FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = anc_visits.patient_id
  ));

CREATE POLICY "Providers read vaccination records"
  ON vaccination_records FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = vaccination_records.patient_id
  ));

CREATE POLICY "Providers read emergency profiles"
  ON emergency_profiles FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = emergency_profiles.patient_id
  ));

-- Admin access
CREATE POLICY "Admins full access mental health"
  ON mental_health_screenings FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins full access mood"
  ON mood_entries FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins full access ANC"
  ON anc_visits FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins full access vaccination"
  ON vaccination_records FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins full access emergency"
  ON emergency_profiles FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));
