-- Tier 2: Medication Reminders + CHW Role
-- Run this in Supabase SQL Editor AFTER tier1_features.sql

-- 1. Medication Reminders
CREATE TABLE IF NOT EXISTS medication_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  medication_name TEXT NOT NULL,
  dosage TEXT NOT NULL DEFAULT '',
  frequency TEXT NOT NULL DEFAULT 'once_daily',
  times JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  notes TEXT,
  prescription_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_reminders_patient ON medication_reminders(patient_id, is_active);

-- 2. CHV (Community Health Volunteer) Visits
CREATE TABLE IF NOT EXISTS chv_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  visit_type TEXT NOT NULL DEFAULT 'routine',
  visit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  systolic_bp INT,
  diastolic_bp INT,
  weight DECIMAL(5,1),
  temperature DECIMAL(4,1),
  pulse INT,
  flags JSONB DEFAULT '[]'::jsonb,
  notes TEXT,
  follow_up_required BOOLEAN DEFAULT false,
  follow_up_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chv_visits_chv ON chv_visits(chv_id, visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_chv_visits_patient ON chv_visits(patient_id, visit_date DESC);

-- Enable RLS
ALTER TABLE medication_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE chv_visits ENABLE ROW LEVEL SECURITY;

-- RLS: patients own medication reminders
CREATE POLICY "Patients own medication reminders"
  ON medication_reminders FOR ALL
  USING (patient_id = auth.uid())
  WITH CHECK (patient_id = auth.uid());

-- RLS: providers can read their patients' reminders
CREATE POLICY "Providers read medication reminders"
  ON medication_reminders FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = medication_reminders.patient_id
  ));

-- RLS: CHV owns their visits
CREATE POLICY "CHV own visits"
  ON chv_visits FOR ALL
  USING (chv_id = auth.uid())
  WITH CHECK (chv_id = auth.uid());

-- RLS: providers can read CHV visits for their patients
CREATE POLICY "Providers read CHV visits"
  ON chv_visits FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM care_team ct
    WHERE ct.provider_id = auth.uid() AND ct.patient_id = chv_visits.patient_id
  ));

-- RLS: Admins full access
CREATE POLICY "Admins full access medication"
  ON medication_reminders FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins full access chv"
  ON chv_visits FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Add 'chw' to users role check constraint (if it exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_role_check') THEN
    ALTER TABLE users DROP CONSTRAINT users_role_check;
    ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('patient', 'doctor', 'nurse', 'radiologist', 'admin', 'chw'));
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
