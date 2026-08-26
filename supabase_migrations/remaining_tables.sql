-- AfiCare: Remaining Tables Migration
-- Safe to run multiple times — uses IF NOT EXISTS for everything

-- ═══════════════════════════════════════════════════════════════════
-- 1. MENTAL HEALTH SCREENINGS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS mental_health_screenings (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    screening_type TEXT NOT NULL CHECK (screening_type IN ('phq9', 'gad7', 'phq2', 'gad2')),
    responses JSONB NOT NULL DEFAULT '{}',
    risk_score INT NOT NULL DEFAULT 0,
    risk_level TEXT NOT NULL CHECK (risk_level IN ('minimal', 'mild', 'moderate', 'severe')),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE mental_health_screenings ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own mental health screenings" ON mental_health_screenings FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. MOOD ENTRIES
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS mood_entries (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mood INT NOT NULL CHECK (mood BETWEEN 1 AND 5),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own mood entries" ON mood_entries FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. ANC VISITS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS anc_visits (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    visit_number INT NOT NULL,
    visit_date DATE NOT NULL,
    gestational_weeks INT,
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    weight_kg DECIMAL(5,2),
    hemoglobin DECIMAL(3,1),
    fundal_height_cm INT,
    fetal_heart_rate INT,
    urinalysis TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE anc_visits ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own ANC visits" ON anc_visits FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. VACCINATION RECORDS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS vaccination_records (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vaccine_name TEXT NOT NULL,
    dose_number INT NOT NULL DEFAULT 1,
    date_administered DATE NOT NULL,
    facility_name TEXT,
    next_due_date DATE,
    batch_number TEXT,
    administered_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE vaccination_records ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own vaccination records" ON vaccination_records FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 5. EMERGENCY PROFILES
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS emergency_profiles (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blood_type TEXT,
    allergies TEXT[],
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    emergency_contact_relationship TEXT,
    medical_conditions TEXT[],
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE emergency_profiles ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own emergency profile" ON emergency_profiles FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. MEDICATION REMINDERS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS medication_reminders (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    medication_name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    frequency TEXT NOT NULL,
    reminder_times JSONB NOT NULL DEFAULT '[]',
    is_active BOOLEAN NOT NULL DEFAULT true,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE medication_reminders ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own medication reminders" ON medication_reminders FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. MEDICATION COSTS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS medication_costs (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    medication_name TEXT NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    pharmacy TEXT,
    payment_method TEXT CHECK (payment_method IN ('cash', 'nhif', 'insurance', 'mpesa', 'subsidized')),
    purchase_date DATE NOT NULL,
    prescription_id TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE medication_costs ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own medication costs" ON medication_costs FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 8. INSURANCE CLAIMS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS insurance_claims (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    claim_number TEXT UNIQUE,
    insurance_provider TEXT NOT NULL,
    policy_number TEXT NOT NULL,
    claim_type TEXT NOT NULL CHECK (claim_type IN ('outpatient', 'inpatient', 'emergency', 'maternity', 'chronic', 'dental', 'optical', 'other')),
    amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected', 'paid')),
    service_date DATE NOT NULL,
    facility_name TEXT,
    diagnosis TEXT,
    documents JSONB DEFAULT '[]',
    submitted_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE insurance_claims ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own insurance claims" ON insurance_claims FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 9. PRE-AUTH REQUESTS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS pre_auth_requests (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    claim_id TEXT NOT NULL REFERENCES insurance_claims(id),
    service_type TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    responded_at TIMESTAMPTZ,
    notes TEXT
  );
  ALTER TABLE pre_auth_requests ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own pre-auth requests" ON pre_auth_requests FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 10. MENS HEALTH SCREENINGS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS mens_health_screenings (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    screening_type TEXT NOT NULL CHECK (screening_type IN ('cardiovascular', 'prostate', 'lifestyle', 'erectile', 'metabolic')),
    responses JSONB NOT NULL DEFAULT '{}',
    risk_score INT NOT NULL DEFAULT 0,
    risk_level TEXT NOT NULL CHECK (risk_level IN ('low', 'moderate', 'high', 'very_high', 'mild', 'severe')),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE mens_health_screenings ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own mens health screenings" ON mens_health_screenings FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 11. CAREGIVER ACCESS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS caregiver_access (
    id TEXT PRIMARY KEY,
    caregiver_user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000' REFERENCES auth.users(id) ON DELETE CASCADE,
    dependent_patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    access_code TEXT NOT NULL UNIQUE,
    access_level TEXT NOT NULL DEFAULT 'full' CHECK (access_level IN ('full', 'medical_only', 'appointments_only', 'emergency_only')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    granted_by_patient_id UUID NOT NULL REFERENCES auth.users(id),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ
  );
  ALTER TABLE caregiver_access ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients manage own caregiver access" ON caregiver_access FOR ALL USING (granted_by_patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 12. CAREGIVER ACTIVITY
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS caregiver_activity (
    id TEXT PRIMARY KEY,
    access_id TEXT NOT NULL REFERENCES caregiver_access(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE caregiver_activity ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients see own caregiver activity" ON caregiver_activity FOR ALL
    USING (access_id IN (SELECT id FROM caregiver_access WHERE granted_by_patient_id = auth.uid()));
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 13. RECEIPTS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS receipts (
    id TEXT PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT,
    facility_name TEXT,
    total_amount DECIMAL(10,2),
    service_type TEXT CHECK (service_type IN ('Consultation', 'Lab Test', 'Imaging', 'Medication', 'Surgery', 'Dental', 'Optical', 'Maternity', 'Other')),
    payment_method TEXT CHECK (payment_method IN ('cash', 'nhif', 'insurance', 'mpesa', 'card', 'subsidized')),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Patients own receipts" ON receipts FOR ALL USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 14. CHV HOUSEHOLDS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS chv_households (
    id TEXT PRIMARY KEY,
    chw_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    household_name TEXT NOT NULL,
    location TEXT,
    county TEXT,
    sub_county TEXT,
    ward TEXT,
    has_mosquito_nets BOOLEAN NOT NULL DEFAULT false,
    has_safe_water BOOLEAN NOT NULL DEFAULT false,
    has_toilet BOOLEAN NOT NULL DEFAULT false,
    has_handwashing_facility BOOLEAN NOT NULL DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE chv_households ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "CHWs own households" ON chv_households FOR ALL USING (chw_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 15. CHV HOUSEHOLD MEMBERS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS chv_household_members (
    id TEXT PRIMARY KEY,
    household_id TEXT NOT NULL REFERENCES chv_households(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    age INT,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    relationship_to_head TEXT,
    is_pregnant BOOLEAN NOT NULL DEFAULT false,
    is_child_under_5 BOOLEAN NOT NULL DEFAULT false,
    has_chronic_condition BOOLEAN NOT NULL DEFAULT false,
    chronic_condition_name TEXT,
    patient_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE chv_household_members ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "CHWs manage own household members" ON chv_household_members FOR ALL
    USING (household_id IN (SELECT id FROM chv_households WHERE chw_id = auth.uid()));
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 16. COMMUNITY SCREENINGS
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS community_screenings (
    id TEXT PRIMARY KEY,
    chw_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES auth.users(id),
    household_member_id TEXT REFERENCES chv_household_members(id),
    screening_type TEXT NOT NULL CHECK (screening_type IN ('malaria_rdt', 'tb_screening', 'malnutrition_muac', 'blood_pressure', 'blood_sugar', 'visual_acuity')),
    results JSONB NOT NULL DEFAULT '{}',
    outcome TEXT NOT NULL CHECK (outcome IN ('normal', 'abnormal', 'referred')),
    facility_referred_to TEXT,
    notes TEXT,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE community_screenings ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "CHWs own community screenings" ON community_screenings FOR ALL USING (chw_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 17. CHV VISITS (may already exist from tier2)
-- ═══════════════════════════════════════════════════════════════════
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS chv_visits (
    id TEXT PRIMARY KEY,
    chw_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    visit_type TEXT NOT NULL CHECK (visit_type IN ('routine', 'follow_up', 'emergency', 'prenatal', 'postnatal', 'child_wellness', 'chronic_disease')),
    notes TEXT,
    flags TEXT[],
    vitals JSONB DEFAULT '{}',
    visit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE chv_visits ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "CHWs own visits" ON chv_visits FOR ALL USING (chw_id = auth.uid());
  CREATE POLICY "Patients see own CHW visits" ON chv_visits FOR SELECT USING (patient_id = auth.uid());
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;
