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
-- TRIAGE QUEUE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS triage_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES users(id),
    triage_level TEXT NOT NULL CHECK (triage_level IN ('emergency', 'urgent', 'less_urgent', 'non_urgent')),
    priority_score INT DEFAULT 0,
    estimated_wait_time INT DEFAULT 0,
    danger_signs TEXT[] DEFAULT '{}',
    chief_complaint TEXT,
    check_in_time TIMESTAMPTZ DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'in_consultation', 'completed', 'cancelled')),
    seen_by UUID REFERENCES users(id),
    seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_triage_status ON triage_queue(status);
CREATE INDEX IF NOT EXISTS idx_triage_priority ON triage_queue(priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_triage_checkin ON triage_queue(check_in_time);

ALTER TABLE triage_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Providers can view triage queue"
    ON triage_queue FOR SELECT
    USING (auth.role() IN ('doctor', 'nurse'));

CREATE POLICY "Triage queue insert"
    ON triage_queue FOR INSERT
    WITH CHECK (auth.role() IN ('doctor', 'nurse'));

CREATE POLICY "Triage queue update"
    ON triage_queue FOR UPDATE
    USING (auth.role() IN ('doctor', 'nurse'));

GRANT SELECT, INSERT, UPDATE ON triage_queue TO authenticated;

-- ============================================
-- LAB ORDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS lab_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    test_name TEXT NOT NULL,
    test_category TEXT DEFAULT 'other',
    priority TEXT NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine', 'urgent', 'stat')),
    status TEXT NOT NULL DEFAULT 'ordered' CHECK (status IN ('ordered', 'collected', 'processing', 'completed', 'cancelled')),
    ordered_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lo_patient ON lab_orders(patient_id);
CREATE INDEX IF NOT EXISTS idx_lo_status ON lab_orders(status);
CREATE INDEX IF NOT EXISTS idx_lo_category ON lab_orders(test_category);

ALTER TABLE lab_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own lab orders"
    ON lab_orders FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can manage lab orders"
    ON lab_orders FOR ALL
    USING (provider_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON lab_orders TO authenticated;

-- ============================================
-- LAB RESULTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS lab_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lab_order_id UUID NOT NULL REFERENCES lab_orders(id) ON DELETE CASCADE,
    result_value TEXT,
    result_unit TEXT,
    reference_range_low TEXT,
    reference_range_high TEXT,
    result_flag TEXT DEFAULT 'normal' CHECK (result_flag IN ('normal', 'abnormal', 'critical')),
    performed_by TEXT,
    resulted_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lr_order ON lab_results(lab_order_id);
CREATE INDEX IF NOT EXISTS idx_lr_flag ON lab_results(result_flag);

ALTER TABLE lab_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own lab results"
    ON lab_results FOR SELECT
    USING (EXISTS (SELECT 1 FROM lab_orders WHERE id = lab_results.lab_order_id AND patient_id = auth.uid()));

CREATE POLICY "Providers can view lab results"
    ON lab_results FOR SELECT
    USING (EXISTS (SELECT 1 FROM lab_orders WHERE id = lab_results.lab_order_id AND provider_id = auth.uid()));

CREATE POLICY "Lab techs can insert results"
    ON lab_results FOR INSERT
    WITH CHECK (auth.role() IN ('doctor', 'nurse'));

GRANT SELECT, INSERT ON lab_results TO authenticated;

-- ============================================
-- RADIOLOGY ORDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS radiology_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    study_type TEXT NOT NULL CHECK (study_type IN ('X-ray', 'CT', 'Ultrasound', 'MRI', 'PET-CT', 'Mammography', 'Other')),
    body_part TEXT NOT NULL,
    clinical_indication TEXT,
    priority TEXT NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine', 'urgent', 'stat')),
    status TEXT NOT NULL DEFAULT 'ordered' CHECK (status IN ('ordered', 'scheduled', 'performed', 'reported', 'cancelled')),
    ordered_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ro_patient ON radiology_orders(patient_id);
CREATE INDEX IF NOT EXISTS idx_ro_status ON radiology_orders(status);

ALTER TABLE radiology_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own radiology orders"
    ON radiology_orders FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can manage radiology orders"
    ON radiology_orders FOR ALL
    USING (provider_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON radiology_orders TO authenticated;

-- ============================================
-- RADIOLOGY REPORTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS radiology_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    radiology_order_id UUID NOT NULL REFERENCES radiology_orders(id) ON DELETE CASCADE,
    radiologist_name TEXT,
    findings TEXT NOT NULL,
    impression TEXT,
    recommendations TEXT,
    reported_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rr_order ON radiology_reports(radiology_order_id);

ALTER TABLE radiology_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own radiology reports"
    ON radiology_reports FOR SELECT
    USING (EXISTS (SELECT 1 FROM radiology_orders WHERE id = radiology_reports.radiology_order_id AND patient_id = auth.uid()));

CREATE POLICY "Providers can view radiology reports"
    ON radiology_reports FOR SELECT
    USING (EXISTS (SELECT 1 FROM radiology_orders WHERE id = radiology_reports.radiology_order_id AND provider_id = auth.uid()));

CREATE POLICY "Radiologists can insert reports"
    ON radiology_reports FOR INSERT
    WITH CHECK (auth.role() IN ('doctor', 'nurse'));

GRANT SELECT, INSERT ON radiology_reports TO authenticated;

-- ============================================
-- REFERRALS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_provider_id UUID NOT NULL REFERENCES users(id),
    to_facility_id UUID REFERENCES facilities(id) ON DELETE SET NULL,
    to_provider_id UUID REFERENCES users(id) ON DELETE SET NULL,
    to_specialty TEXT,
    reason TEXT NOT NULL,
    urgency TEXT NOT NULL DEFAULT 'routine' CHECK (urgency IN ('routine', 'urgent', 'emergency')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'completed', 'rejected', 'closed')),
    referral_notes TEXT,
    response_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ref_patient ON referrals(patient_id);
CREATE INDEX IF NOT EXISTS idx_ref_from ON referrals(from_provider_id);
CREATE INDEX IF NOT EXISTS idx_ref_to ON referrals(to_facility_id);
CREATE INDEX IF NOT EXISTS idx_ref_status ON referrals(status);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can view own referrals"
    ON referrals FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Referring providers can manage referrals"
    ON referrals FOR ALL
    USING (from_provider_id = auth.uid());

CREATE POLICY "Receiving providers can view referrals"
    ON referrals FOR SELECT
    USING (to_provider_id = auth.uid() OR to_facility_id IS NOT NULL);

GRANT SELECT, INSERT, UPDATE ON referrals TO authenticated;

-- ============================================
-- MESSAGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(id),
    receiver_id UUID NOT NULL REFERENCES users(id),
    patient_id UUID REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'lab_result', 'referral', 'appointment')),
    reference_id UUID,
    read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_msg_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_msg_patient ON messages(patient_id);
CREATE INDEX IF NOT EXISTS idx_msg_read ON messages(receiver_id, read);
CREATE INDEX IF NOT EXISTS idx_msg_created ON messages(created_at DESC);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can send messages"
    ON messages FOR INSERT
    WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can view their messages"
    ON messages FOR SELECT
    USING (sender_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "Users can mark messages as read"
    ON messages FOR UPDATE
    USING (receiver_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON messages TO authenticated;

-- ============================================
-- ADHERENCE LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS adherence_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_time TIMESTAMPTZ NOT NULL,
    taken_time TIMESTAMPTZ,
    skipped_reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'taken', 'skipped')),
    noted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_adh_prescription ON adherence_log(prescription_id);
CREATE INDEX IF NOT EXISTS idx_adh_patient ON adherence_log(patient_id);
CREATE INDEX IF NOT EXISTS idx_adh_scheduled ON adherence_log(scheduled_time);

ALTER TABLE adherence_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage own adherence"
    ON adherence_log FOR ALL
    USING (patient_id = auth.uid());

CREATE POLICY "Providers can view patient adherence"
    ON adherence_log FOR SELECT
    USING (EXISTS (SELECT 1 FROM prescriptions WHERE id = adherence_log.prescription_id AND provider_id = auth.uid()));

GRANT SELECT, INSERT, UPDATE ON adherence_log TO authenticated;

-- ============================================
-- USER PREFERENCES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    theme TEXT NOT NULL DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'high_contrast')),
    language TEXT NOT NULL DEFAULT 'en',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own preferences"
    ON user_preferences FOR ALL
    USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON user_preferences TO authenticated;

-- ============================================
-- GRANTS (Consolidated)
-- ============================================
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON patients TO authenticated;
GRANT SELECT, INSERT ON consultations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON access_codes TO authenticated;
GRANT INSERT ON audit_log TO authenticated;

-- ============================================
-- MIGRATION: Schema Fixes (v2)
-- ============================================

-- 1. Add status column to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'invited'));

-- 2. Add facility_id column (next to hospital_id for backward compat; migrate to facility_id going forward)
ALTER TABLE users ADD COLUMN IF NOT EXISTS facility_id UUID REFERENCES facilities(id) ON DELETE SET NULL;

-- 3. Add license_no and status to facilities
ALTER TABLE facilities ADD COLUMN IF NOT EXISTS license_no TEXT;
ALTER TABLE facilities ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('verified', 'pending', 'inactive'));

-- 4. Departments table
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    head_provider_id UUID REFERENCES users(id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view departments" ON departments;
CREATE POLICY "Anyone can view departments"
    ON departments FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "Admins can manage departments" ON departments;
CREATE POLICY "Admins can manage departments"
    ON departments FOR ALL USING (auth.role() IN ('admin'));
GRANT SELECT, INSERT, UPDATE, DELETE ON departments TO authenticated;

-- 5. System settings table
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    value JSONB NOT NULL DEFAULT '{}'::jsonb,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    UNIQUE(category, key)
);
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage system settings" ON system_settings;
CREATE POLICY "Admins can manage system settings"
    ON system_settings FOR ALL USING (auth.role() IN ('admin'));
DROP POLICY IF EXISTS "Anyone can view system settings" ON system_settings;
CREATE POLICY "Anyone can view system settings"
    ON system_settings FOR SELECT USING (TRUE);
GRANT SELECT, INSERT, UPDATE, DELETE ON system_settings TO authenticated;

-- 6. Audit log SELECT for admins
DROP POLICY IF EXISTS "Admins can view audit logs" ON audit_log;
CREATE POLICY "Admins can view audit logs"
    ON audit_log FOR SELECT
    USING (auth.role() IN ('admin'));

-- 7. Facilities UPDATE/DELETE for admins
DROP POLICY IF EXISTS "Anyone can view facilities" ON facilities;
CREATE POLICY "Anyone can view facilities"
    ON facilities FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "Authenticated users can register facilities" ON facilities;
CREATE POLICY "Authenticated users can register facilities"
    ON facilities FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admins can update facilities" ON facilities;
CREATE POLICY "Admins can update facilities"
    ON facilities FOR UPDATE
    USING (auth.role() IN ('admin'));
DROP POLICY IF EXISTS "Admins can delete facilities" ON facilities;
CREATE POLICY "Admins can delete facilities"
    ON facilities FOR DELETE
    USING (auth.role() IN ('admin'));

-- 8. Referrals UPDATE for receiving providers
DROP POLICY IF EXISTS "Receiving providers can update referrals" ON referrals;
CREATE POLICY "Receiving providers can update referrals"
    ON referrals FOR UPDATE
    USING (to_provider_id = auth.uid() OR auth.role() IN ('admin'));

-- 9. Triage assessments table (matches Dart TriageAssessment model)
CREATE TABLE IF NOT EXISTS triage_assessments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES users(id),
    consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
    assessed_at TIMESTAMPTZ DEFAULT NOW(),
    chief_complaint TEXT NOT NULL,
    symptoms TEXT[] NOT NULL DEFAULT '{}',
    triage_level TEXT NOT NULL CHECK (triage_level IN ('emergency', 'urgent', 'less_urgent', 'non_urgent')),
    temperature DECIMAL(5,2),
    systolic_bp INT,
    diastolic_bp INT,
    heart_rate INT,
    respiratory_rate INT,
    oxygen_saturation DECIMAL(4,1),
    weight DECIMAL(5,1),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ta_patient ON triage_assessments(patient_id);
CREATE INDEX IF NOT EXISTS idx_ta_provider ON triage_assessments(provider_id);
ALTER TABLE triage_assessments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Patients can view own triage" ON triage_assessments;
CREATE POLICY "Patients can view own triage"
    ON triage_assessments FOR SELECT
    USING (patient_id = auth.uid());
DROP POLICY IF EXISTS "Providers can manage triage" ON triage_assessments;
CREATE POLICY "Providers can manage triage"
    ON triage_assessments FOR ALL
    USING (provider_id = auth.uid());
GRANT SELECT, INSERT, UPDATE ON triage_assessments TO authenticated;

-- 10. Grant SELECT on audit_log for authenticated (needed for admin policy)
GRANT SELECT ON audit_log TO authenticated;
-- Fix facilities grants
GRANT UPDATE, DELETE ON facilities TO authenticated;
