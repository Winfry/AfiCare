-- ================================================================
-- AfiCare - Consolidated Backend Fixes
-- ----------------------------------------------------------------
-- What this does, in plain English:
--
-- PART A: Ensures the disability_profiles and user_preferences
--   tables + their RLS policies exist and match the intended schema
--   (they exist in the database; this drops/recreates the policies
--   so re-runs never conflict).
--
-- PART B: Re-applies the Row Level Security (RLS) fix for the
--   "infinite recursion" error on patients / consultations /
--   facilities / audit_log. Uses the get_my_role() function so the
--   role lookup no longer loops.
--
-- This script is SAFE TO RE-RUN (every statement is idempotent).
-- Paste it into: Supabase Dashboard -> SQL Editor -> Run.
-- ================================================================

-- ================================================================
-- PART A: disability_profiles + user_preferences (policies)
-- ================================================================

-- A1. disability_profiles (PWD feature)
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

DROP POLICY IF EXISTS "Patients can manage own disability profile" ON disability_profiles;
CREATE POLICY "Patients can manage own disability profile"
    ON disability_profiles FOR ALL
    USING (patient_id = auth.uid());

DROP POLICY IF EXISTS "Providers can view disability profiles" ON disability_profiles;
CREATE POLICY "Providers can view disability profiles"
    ON disability_profiles FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM care_team WHERE provider_id = auth.uid() AND patient_id = disability_profiles.patient_id
    ));

GRANT SELECT, INSERT, UPDATE ON disability_profiles TO authenticated;

-- A2. user_preferences (app preferences feature)
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

DROP POLICY IF EXISTS "Users can manage own preferences" ON user_preferences;
CREATE POLICY "Users can manage own preferences"
    ON user_preferences FOR ALL
    USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON user_preferences TO authenticated;

-- ================================================================
-- PART B: RLS infinite-recursion fix (get_my_role pattern)
-- ================================================================

-- B1. The safe role-lookup function
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT role
    FROM   users
    WHERE  id::text = (auth.uid())::text
  );
END;
$$;

-- B2. Drop the old recursive policies (safe if they don't exist)
DROP POLICY IF EXISTS "users_select_admin" ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin" ON users;

DROP POLICY IF EXISTS "patients_select_consulted" ON patients;
DROP POLICY IF EXISTS "patients_select_admin" ON patients;

DROP POLICY IF EXISTS "consultations_select_admin" ON consultations;
DROP POLICY IF EXISTS "consultations_insert_provider" ON consultations;
DROP POLICY IF EXISTS "consultations_update_provider" ON consultations;

DROP POLICY IF EXISTS "facilities_insert_provider" ON facilities;
DROP POLICY IF EXISTS "facilities_update_admin" ON facilities;

DROP POLICY IF EXISTS "audit_log_select_admin" ON audit_log;

-- B3. Recreate with recursion-safe policies
CREATE POLICY "users_select_admin"
ON users FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "users_select_consulted"
ON users FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND medilink_id::text IN (
    SELECT patient_id::text
    FROM   consultations
    WHERE  provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "users_update_admin"
ON users FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "patients_select_consulted"
ON patients FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND id::text IN (
    SELECT u.id::text
    FROM   users u
    JOIN   consultations c ON c.patient_id::text = u.medilink_id::text
    WHERE  c.provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "patients_select_admin"
ON patients FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "consultations_select_admin"
ON consultations FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "consultations_insert_provider"
ON consultations FOR INSERT
WITH CHECK (
  provider_id::text = (auth.uid())::text
  AND (SELECT get_my_role()) IN ('doctor', 'nurse')
);

CREATE POLICY "consultations_update_provider"
ON consultations FOR UPDATE
USING (
  provider_id::text = (auth.uid())::text
  AND (SELECT get_my_role()) IN ('doctor', 'nurse')
);

CREATE POLICY "facilities_insert_provider"
ON facilities FOR INSERT
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse', 'admin'));

CREATE POLICY "facilities_update_admin"
ON facilities FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "audit_log_select_admin"
ON audit_log FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

-- ================================================================
-- Verify: should list all policies per table
-- ================================================================
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('disability_profiles', 'user_preferences', 'users', 'patients', 'consultations', 'facilities', 'audit_log')
ORDER BY tablename, policyname;
