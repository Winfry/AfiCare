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
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON patients TO authenticated;
GRANT SELECT, INSERT ON consultations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON access_codes TO authenticated;
GRANT INSERT ON audit_log TO authenticated;
