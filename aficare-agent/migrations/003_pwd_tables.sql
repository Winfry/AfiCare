-- ================================================================
-- AfiCare MediLink — Migration 003: PWD Disability Profiles
-- Migration: 003_pwd_tables.sql
--
-- What this creates:
--   1. disability_profiles   — one row per patient; both patient and
--                               provider fill fields in the same row
--   2. RLS policies          — patient owns their profile; providers
--                               can update clinical fields only
--
-- Design notes:
--   • caregiver is stored as JSONB (always accessed via the profile,
--     never queried independently).
--   • specialist_referrals and assistive_devices are TEXT ARRAY
--     (simple list, no need for a join table at this scale).
--   • disability_types is TEXT ARRAY (maps to DisabilityType enum names).
--   • Migration 001 added disability_type TEXT to patients; that column
--     is intentionally kept for backward compat but this table is the
--     canonical source.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================


-- ================================================================
-- 1. DISABILITY PROFILES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS disability_profiles (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id                  UUID NOT NULL REFERENCES patients (id) ON DELETE CASCADE,

    -- ---- Patient-reported fields ----

    -- e.g. ['visual', 'hearing'] — values must match DisabilityType enum names
    disability_types            TEXT[]   NOT NULL DEFAULT '{}',

    severity                    TEXT     NOT NULL DEFAULT 'mild'
                                    CHECK (severity IN ('mild', 'moderate', 'severe')),

    is_congenital               BOOLEAN  NOT NULL DEFAULT FALSE,
    onset_date                  DATE,

    -- Assistive devices currently used
    assistive_devices           TEXT[]   NOT NULL DEFAULT '{}',

    -- ---- Provider-filled clinical fields ----

    -- Formal medical diagnosis e.g. "Spastic Diplegia Cerebral Palsy"
    clinical_diagnosis          TEXT,

    -- Free-form notes visible to other clinicians
    provider_notes              TEXT,

    -- Whether patient needs a caregiver present for informed consent
    requires_caregiver_for_consent  BOOLEAN NOT NULL DEFAULT FALSE,

    -- Specialist referrals recommended by the provider
    specialist_referrals        TEXT[]   NOT NULL DEFAULT '{}',

    -- ---- Caregiver (embedded as JSONB) ----
    -- Schema mirrors CaregiverDesignation.toMap():
    --   { name, phone, relationship, permissions[], access_code,
    --     code_expiry, is_active, designated_at }
    caregiver                   JSONB,

    -- ---- Metadata ----
    last_updated                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 'patient' or provider user UUID
    updated_by                  TEXT NOT NULL,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One profile per patient
    CONSTRAINT disability_profiles_patient_id_unique UNIQUE (patient_id)
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_disability_profiles_patient_id
    ON disability_profiles (patient_id);

CREATE INDEX IF NOT EXISTS idx_disability_profiles_severity
    ON disability_profiles (severity);

-- GIN index so we can filter on disability types array efficiently
-- e.g. WHERE 'visual' = ANY(disability_types)
CREATE INDEX IF NOT EXISTS idx_disability_profiles_types_gin
    ON disability_profiles USING GIN (disability_types);


-- ================================================================
-- 2. ENABLE RLS
-- ================================================================

ALTER TABLE disability_profiles ENABLE ROW LEVEL SECURITY;


-- ================================================================
-- 3. RLS POLICIES
-- ================================================================

-- Drop existing policies if re-running this migration
DROP POLICY IF EXISTS "dp_select_own"       ON disability_profiles;
DROP POLICY IF EXISTS "dp_select_provider"  ON disability_profiles;
DROP POLICY IF EXISTS "dp_select_admin"     ON disability_profiles;
DROP POLICY IF EXISTS "dp_insert_own"       ON disability_profiles;
DROP POLICY IF EXISTS "dp_update_own"       ON disability_profiles;
DROP POLICY IF EXISTS "dp_update_provider"  ON disability_profiles;
DROP POLICY IF EXISTS "dp_update_admin"     ON disability_profiles;
DROP POLICY IF EXISTS "dp_delete_own"       ON disability_profiles;
DROP POLICY IF EXISTS "dp_delete_admin"     ON disability_profiles;


-- 3a. Patient reads their own profile
CREATE POLICY "dp_select_own" ON disability_profiles
    FOR SELECT
    USING (
        patient_id::text = (auth.uid())::text
    );


-- 3b. Provider reads any patient profile they have a consultation with
--     (mirrors the patient RLS pattern from 002_rls_policies.sql)
CREATE POLICY "dp_select_provider" ON disability_profiles
    FOR SELECT
    USING (
        get_my_role() IN ('doctor', 'nurse')
        AND EXISTS (
            SELECT 1
            FROM   consultations c
            WHERE  c.patient_id::text = disability_profiles.patient_id::text
        )
    );


-- 3c. Admin reads everything
CREATE POLICY "dp_select_admin" ON disability_profiles
    FOR SELECT
    USING (get_my_role() = 'admin');


-- 3d. Patient inserts their own profile (self-registration)
CREATE POLICY "dp_insert_own" ON disability_profiles
    FOR INSERT
    WITH CHECK (
        patient_id::text = (auth.uid())::text
    );


-- 3e. Patient updates their own patient-reported fields
--     (The WITH CHECK is broad; column-level security comes from
--      the application layer: patient only sends patient fields.)
CREATE POLICY "dp_update_own" ON disability_profiles
    FOR UPDATE
    USING  (patient_id::text = (auth.uid())::text)
    WITH CHECK (patient_id::text = (auth.uid())::text);


-- 3f. Provider updates clinical fields on any patient profile
--     they have a consultation with
CREATE POLICY "dp_update_provider" ON disability_profiles
    FOR UPDATE
    USING (
        get_my_role() IN ('doctor', 'nurse')
        AND EXISTS (
            SELECT 1
            FROM   consultations c
            WHERE  c.patient_id::text = disability_profiles.patient_id::text
        )
    )
    WITH CHECK (
        get_my_role() IN ('doctor', 'nurse')
    );


-- 3g. Admin can update anything
CREATE POLICY "dp_update_admin" ON disability_profiles
    FOR UPDATE
    USING  (get_my_role() = 'admin')
    WITH CHECK (get_my_role() = 'admin');


-- 3h. Patient deletes their own profile
CREATE POLICY "dp_delete_own" ON disability_profiles
    FOR DELETE
    USING (patient_id::text = (auth.uid())::text);


-- 3i. Admin deletes any profile
CREATE POLICY "dp_delete_admin" ON disability_profiles
    FOR DELETE
    USING (get_my_role() = 'admin');


-- ================================================================
-- 4. HELPER: upsert_disability_profile
--    Convenience function called from the Flutter app so the client
--    only needs one RPC call instead of INSERT … ON CONFLICT.
-- ================================================================

CREATE OR REPLACE FUNCTION upsert_disability_profile(
    p_patient_id                   UUID,
    p_disability_types             TEXT[],
    p_severity                     TEXT,
    p_is_congenital                BOOLEAN,
    p_onset_date                   DATE,
    p_assistive_devices            TEXT[],
    p_clinical_diagnosis           TEXT     DEFAULT NULL,
    p_provider_notes               TEXT     DEFAULT NULL,
    p_requires_caregiver_consent   BOOLEAN  DEFAULT FALSE,
    p_specialist_referrals         TEXT[]   DEFAULT '{}',
    p_caregiver                    JSONB    DEFAULT NULL,
    p_updated_by                   TEXT     DEFAULT 'patient'
)
RETURNS disability_profiles
LANGUAGE plpgsql
SECURITY DEFINER       -- runs as table owner, bypasses RLS for the upsert
AS $$
DECLARE
    v_result disability_profiles;
BEGIN
    -- Only the patient themselves OR a provider with a consultation
    -- OR an admin may call this function.
    IF (auth.uid())::text != p_patient_id::text
       AND get_my_role() NOT IN ('doctor', 'nurse', 'admin')
    THEN
        RAISE EXCEPTION 'Not authorised to update disability profile for patient %', p_patient_id;
    END IF;

    INSERT INTO disability_profiles (
        patient_id,
        disability_types,
        severity,
        is_congenital,
        onset_date,
        assistive_devices,
        clinical_diagnosis,
        provider_notes,
        requires_caregiver_for_consent,
        specialist_referrals,
        caregiver,
        last_updated,
        updated_by
    )
    VALUES (
        p_patient_id,
        p_disability_types,
        p_severity,
        p_is_congenital,
        p_onset_date,
        p_assistive_devices,
        p_clinical_diagnosis,
        p_provider_notes,
        p_requires_caregiver_consent,
        p_specialist_referrals,
        p_caregiver,
        NOW(),
        p_updated_by
    )
    ON CONFLICT (patient_id) DO UPDATE
        SET disability_types                 = EXCLUDED.disability_types,
            severity                         = EXCLUDED.severity,
            is_congenital                    = EXCLUDED.is_congenital,
            onset_date                       = EXCLUDED.onset_date,
            assistive_devices                = EXCLUDED.assistive_devices,
            -- Provider fields: only overwrite when caller is a provider/admin
            clinical_diagnosis               = CASE
                WHEN get_my_role() IN ('doctor', 'nurse', 'admin')
                    THEN EXCLUDED.clinical_diagnosis
                ELSE disability_profiles.clinical_diagnosis
            END,
            provider_notes                   = CASE
                WHEN get_my_role() IN ('doctor', 'nurse', 'admin')
                    THEN EXCLUDED.provider_notes
                ELSE disability_profiles.provider_notes
            END,
            requires_caregiver_for_consent   = CASE
                WHEN get_my_role() IN ('doctor', 'nurse', 'admin')
                    THEN EXCLUDED.requires_caregiver_for_consent
                ELSE disability_profiles.requires_caregiver_for_consent
            END,
            specialist_referrals             = CASE
                WHEN get_my_role() IN ('doctor', 'nurse', 'admin')
                    THEN EXCLUDED.specialist_referrals
                ELSE disability_profiles.specialist_referrals
            END,
            caregiver                        = EXCLUDED.caregiver,
            last_updated                     = NOW(),
            updated_by                       = EXCLUDED.updated_by
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$;


-- ================================================================
-- 5. VERIFICATION QUERIES (run after migration to confirm success)
-- ================================================================

-- SELECT table_name, column_name, data_type
-- FROM   information_schema.columns
-- WHERE  table_name = 'disability_profiles'
-- ORDER  BY ordinal_position;

-- SELECT policyname, cmd, qual, with_check
-- FROM   pg_policies
-- WHERE  tablename = 'disability_profiles'
-- ORDER  BY policyname;
