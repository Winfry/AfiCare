-- AfiCare MediLink - Supabase Database Schema
-- Run this in your Supabase SQL Editor to set up the database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('patient', 'doctor', 'nurse', 'admin')),
    phone TEXT,
    medilink_id TEXT UNIQUE,
    hospital_id TEXT,
    department TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create index for MediLink ID lookups
CREATE INDEX IF NOT EXISTS idx_users_medilink_id ON users(medilink_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ============================================
-- PATIENTS TABLE (Extended patient info)
-- ============================================
CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    date_of_birth DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    blood_type TEXT,
    allergies TEXT[],
    chronic_conditions TEXT[],
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    address TEXT,
    insurance_id TEXT
);

-- ============================================
-- CONSULTATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id),
    provider_id UUID NOT NULL REFERENCES users(id),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    chief_complaint TEXT NOT NULL,
    symptoms TEXT[] NOT NULL,
    vital_signs JSONB NOT NULL DEFAULT '{}'::jsonb,
    triage_level TEXT NOT NULL CHECK (triage_level IN ('emergency', 'urgent', 'less_urgent', 'non_urgent')),
    diagnoses JSONB NOT NULL DEFAULT '[]'::jsonb,
    recommendations TEXT[] NOT NULL DEFAULT '{}',
    notes TEXT,
    follow_up_required BOOLEAN DEFAULT FALSE,
    follow_up_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consultations_patient ON consultations(patient_id);
CREATE INDEX IF NOT EXISTS idx_consultations_provider ON consultations(provider_id);
CREATE INDEX IF NOT EXISTS idx_consultations_timestamp ON consultations(timestamp DESC);

-- ============================================
-- ACCESS CODES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS access_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    permissions TEXT[] DEFAULT ARRAY['view_records'],
    is_used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES users(id),
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_access_codes_code ON access_codes(code);
CREATE INDEX IF NOT EXISTS idx_access_codes_patient ON access_codes(patient_id);

-- ============================================
-- AUDIT LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action TEXT NOT NULL,
    user_id UUID REFERENCES users(id),
    patient_id UUID REFERENCES users(id),
    details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    user_agent TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_patient ON audit_log(patient_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view own profile"
    ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Providers can view patient profiles with access"
    ON users FOR SELECT
    USING (
        role = 'patient' AND
        EXISTS (
            SELECT 1 FROM access_codes
            WHERE patient_id = users.id
            AND used_by = auth.uid()
            AND expires_at > NOW()
        )
    );

-- Consultations policies
CREATE POLICY "Patients can view own consultations"
    ON consultations FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can view consultations they created"
    ON consultations FOR SELECT
    USING (provider_id = auth.uid());

CREATE POLICY "Providers can create consultations"
    ON consultations FOR INSERT
    WITH CHECK (provider_id = auth.uid());

-- Access codes policies
CREATE POLICY "Patients can manage own access codes"
    ON access_codes FOR ALL
    USING (patient_id = auth.uid());

CREATE POLICY "Anyone can verify access codes"
    ON access_codes FOR SELECT
    USING (TRUE);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to generate MediLink ID
CREATE OR REPLACE FUNCTION generate_medilink_id()
RETURNS TEXT AS $$
DECLARE
    new_id TEXT;
BEGIN
    new_id := 'ML-NBO-' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================

-- Insert demo users (uncomment to use)
/*
INSERT INTO users (id, email, full_name, role, medilink_id, department) VALUES
    ('11111111-1111-1111-1111-111111111111', 'patient@demo.com', 'John Doe', 'patient', 'ML-NBO-DEMO01', NULL),
    ('22222222-2222-2222-2222-222222222222', 'doctor@demo.com', 'Dr. Mary Wanjiku', 'doctor', NULL, 'Internal Medicine'),
    ('33333333-3333-3333-3333-333333333333', 'admin@demo.com', 'Admin Peter', 'admin', NULL, 'Administration');
*/

-- ============================================
-- GRANTS
-- ============================================

-- Grant access to authenticated users
-- ============================================
-- MEDICAL EXPENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS medical_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('medication', 'consultation', 'labTest', 'procedure', 'hospitalStay', 'other')),
    amount DECIMAL(12, 2) NOT NULL,
    currency TEXT DEFAULT 'KES',
    description TEXT NOT NULL,
    date DATE NOT NULL,
    facility_name TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_patient ON medical_expenses(patient_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON medical_expenses(date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON medical_expenses(category);

ALTER TABLE medical_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage own expenses"
    ON medical_expenses FOR ALL
    USING (patient_id = auth.uid());

CREATE TRIGGER expenses_updated_at
    BEFORE UPDATE ON medical_expenses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

GRANT SELECT, INSERT, UPDATE, DELETE ON medical_expenses TO authenticated;

-- ============================================
-- GRANTS
-- ============================================

-- ============================================
-- PRESCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    medication_name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    frequency TEXT NOT NULL,
    duration TEXT NOT NULL,
    instructions TEXT,
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rx_patient ON prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_rx_provider ON prescriptions(provider_id);
CREATE INDEX IF NOT EXISTS idx_rx_status ON prescriptions(status);

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own prescriptions"
    ON prescriptions FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can view prescriptions they created"
    ON prescriptions FOR SELECT
    USING (provider_id = auth.uid());

CREATE POLICY "Providers can create prescriptions"
    ON prescriptions FOR INSERT
    WITH CHECK (provider_id = auth.uid());

CREATE POLICY "Providers can update own prescriptions"
    ON prescriptions FOR UPDATE
    USING (provider_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON prescriptions TO authenticated;

-- ============================================
-- FACILITIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS facilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT DEFAULT 'clinic',
    county TEXT,
    sub_county TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE facilities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view facilities"
    ON facilities FOR SELECT
    USING (TRUE);

CREATE POLICY "Authenticated users can register facilities"
    ON facilities FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

GRANT SELECT, INSERT ON facilities TO authenticated;

-- ============================================
-- APPOINTMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    facility_id UUID REFERENCES facilities(id) ON DELETE SET NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INT DEFAULT 30,
    type TEXT NOT NULL DEFAULT 'in-person' CHECK (type IN ('in-person', 'telehealth')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
    chief_complaint TEXT,
    notes TEXT,
    is_follow_up BOOLEAN DEFAULT FALSE,
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_appt_patient ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appt_provider ON appointments(provider_id);
CREATE INDEX IF NOT EXISTS idx_appt_scheduled ON appointments(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_appt_status ON appointments(status);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own appointments"
    ON appointments FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Patients can book appointments"
    ON appointments FOR INSERT
    WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Providers can view their appointments"
    ON appointments FOR SELECT
    USING (provider_id = auth.uid());

CREATE POLICY "Providers can update appointment status"
    ON appointments FOR UPDATE
    USING (provider_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON appointments TO authenticated;

-- ============================================
-- DEPENDENT PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS dependent_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guardian_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    date_of_birth DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    relationship TEXT NOT NULL,
    blood_type TEXT,
    medilink_id TEXT UNIQUE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dep_guardian ON dependent_profiles(guardian_id);

ALTER TABLE dependent_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage own dependents"
    ON dependent_profiles FOR ALL
    USING (guardian_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON dependent_profiles TO authenticated;

-- ============================================
-- CARE TEAM TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS care_team (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    specialty_label TEXT,
    notes TEXT,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(patient_id, provider_id)
);

CREATE INDEX IF NOT EXISTS idx_ct_patient ON care_team(patient_id);
CREATE INDEX IF NOT EXISTS idx_ct_provider ON care_team(provider_id);

ALTER TABLE care_team ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage care team"
    ON care_team FOR ALL
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can view care team assignments"
    ON care_team FOR SELECT
    USING (provider_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON care_team TO authenticated;

-- ============================================
-- DISABILITY PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS disability_profiles (
    patient_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    disability_types TEXT[] NOT NULL DEFAULT '{}',
    severity TEXT NOT NULL DEFAULT 'mild' CHECK (severity IN ('mild', 'moderate', 'severe')),
    is_congenital BOOLEAN DEFAULT FALSE,
    onset_date DATE,
    assistive_devices TEXT[] DEFAULT '{}',
    clinical_diagnosis TEXT,
    provider_notes TEXT,
    requires_caregiver_for_consent BOOLEAN DEFAULT FALSE,
    specialist_referrals TEXT[] DEFAULT '{}',
    caregiver JSONB DEFAULT '{}'::jsonb,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    updated_by TEXT DEFAULT 'patient'
);

ALTER TABLE disability_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage own disability profile"
    ON disability_profiles FOR ALL
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can view disability profiles"
    ON disability_profiles FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM care_team WHERE provider_id = auth.uid() AND patient_id = disability_profiles.patient_id
    ));

GRANT SELECT, INSERT, UPDATE ON disability_profiles TO authenticated;

-- ============================================
-- GRANTS
-- ============================================
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON patients TO authenticated;
GRANT SELECT, INSERT ON consultations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON access_codes TO authenticated;
GRANT INSERT ON audit_log TO authenticated;
