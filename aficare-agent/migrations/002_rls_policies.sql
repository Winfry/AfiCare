-- ================================================================
-- AfiCare RLS Policies — v2 (fixed type casting)
-- Migration: 002_rls_policies.sql
--
-- Fix: every comparison casts BOTH sides to ::text
-- This works whether columns are UUID or TEXT type.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================


-- ================================================================
-- SECTION 1: HELPER FUNCTION
-- Reads the current user's role WITHOUT hitting RLS
-- (SECURITY DEFINER bypasses RLS to avoid infinite recursion)
-- ================================================================

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT role
  FROM   users
  WHERE  id::text = (auth.uid())::text
$$;


-- ================================================================
-- SECTION 2: ENABLE RLS ON ALL TABLES
-- ================================================================

ALTER TABLE users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients      ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities    ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log     ENABLE ROW LEVEL SECURITY;


-- ================================================================
-- SECTION 3: USERS TABLE
-- ================================================================

DROP POLICY IF EXISTS "users_select_own"       ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_select_admin"     ON users;
DROP POLICY IF EXISTS "users_insert_own"       ON users;
DROP POLICY IF EXISTS "users_update_own"       ON users;
DROP POLICY IF EXISTS "users_update_admin"     ON users;

-- Every user sees their own record
CREATE POLICY "users_select_own"
ON users FOR SELECT
USING (
  id::text = (auth.uid())::text
);

-- Providers see patients they have previously consulted
CREATE POLICY "users_select_consulted"
ON users FOR SELECT
USING (
  get_my_role() IN ('doctor', 'nurse')
  AND medilink_id::text IN (
    SELECT patient_id::text
    FROM   consultations
    WHERE  provider_id::text = (auth.uid())::text
  )
);

-- Admins see all users
CREATE POLICY "users_select_admin"
ON users FOR SELECT
USING (
  get_my_role() = 'admin'
);

-- User can only insert their own row on registration
CREATE POLICY "users_insert_own"
ON users FOR INSERT
WITH CHECK (
  id::text = (auth.uid())::text
);

-- Users update their own record
CREATE POLICY "users_update_own"
ON users FOR UPDATE
USING (
  id::text = (auth.uid())::text
);

-- Admins update any user record
CREATE POLICY "users_update_admin"
ON users FOR UPDATE
USING (
  get_my_role() = 'admin'
);


-- ================================================================
-- SECTION 4: PATIENTS TABLE
-- ================================================================

DROP POLICY IF EXISTS "patients_select_own"       ON patients;
DROP POLICY IF EXISTS "patients_select_consulted" ON patients;
DROP POLICY IF EXISTS "patients_select_admin"     ON patients;
DROP POLICY IF EXISTS "patients_insert_own"       ON patients;
DROP POLICY IF EXISTS "patients_update_own"       ON patients;

-- Patient sees only their own extended record
CREATE POLICY "patients_select_own"
ON patients FOR SELECT
USING (
  id::text = (auth.uid())::text
);

-- Provider sees patients they have consulted
CREATE POLICY "patients_select_consulted"
ON patients FOR SELECT
USING (
  get_my_role() IN ('doctor', 'nurse')
  AND id::text IN (
    SELECT u.id::text
    FROM   users        u
    JOIN   consultations c
           ON c.patient_id::text = u.medilink_id::text
    WHERE  c.provider_id::text = (auth.uid())::text
  )
);

-- Admins see all patient records
CREATE POLICY "patients_select_admin"
ON patients FOR SELECT
USING (
  get_my_role() = 'admin'
);

-- Patient creates their own record on registration
CREATE POLICY "patients_insert_own"
ON patients FOR INSERT
WITH CHECK (
  id::text = (auth.uid())::text
);

-- Patient updates their own record
CREATE POLICY "patients_update_own"
ON patients FOR UPDATE
USING (
  id::text = (auth.uid())::text
);


-- ================================================================
-- SECTION 5: CONSULTATIONS TABLE
-- NOTE: patient_id stores the medilink_id (text)
--       provider_id stores the provider UUID (text)
-- ================================================================

DROP POLICY IF EXISTS "consultations_select_patient"  ON consultations;
DROP POLICY IF EXISTS "consultations_select_provider" ON consultations;
DROP POLICY IF EXISTS "consultations_select_admin"    ON consultations;
DROP POLICY IF EXISTS "consultations_insert_provider" ON consultations;
DROP POLICY IF EXISTS "consultations_update_provider" ON consultations;

-- Patient sees consultations where they are the patient
-- (matched via their medilink_id)
CREATE POLICY "consultations_select_patient"
ON consultations FOR SELECT
USING (
  patient_id::text IN (
    SELECT medilink_id::text
    FROM   users
    WHERE  id::text = (auth.uid())::text
  )
);

-- Provider sees consultations they created
CREATE POLICY "consultations_select_provider"
ON consultations FOR SELECT
USING (
  provider_id::text = (auth.uid())::text
);

-- Admins see all consultations
CREATE POLICY "consultations_select_admin"
ON consultations FOR SELECT
USING (
  get_my_role() = 'admin'
);

-- Only doctors and nurses can create consultations
-- and only with their own provider_id
CREATE POLICY "consultations_insert_provider"
ON consultations FOR INSERT
WITH CHECK (
  provider_id::text = (auth.uid())::text
  AND get_my_role() IN ('doctor', 'nurse')
);

-- Providers update only their own consultations
CREATE POLICY "consultations_update_provider"
ON consultations FOR UPDATE
USING (
  provider_id::text = (auth.uid())::text
  AND get_my_role() IN ('doctor', 'nurse')
);


-- ================================================================
-- SECTION 6: FACILITIES TABLE
-- ================================================================

DROP POLICY IF EXISTS "facilities_select_all"      ON facilities;
DROP POLICY IF EXISTS "facilities_insert_provider" ON facilities;
DROP POLICY IF EXISTS "facilities_update_admin"    ON facilities;

-- Anyone (including unauthenticated) can list facilities
-- Needed on the register screen before login
CREATE POLICY "facilities_select_all"
ON facilities FOR SELECT
USING (true);

-- Providers and admins can register new facilities
CREATE POLICY "facilities_insert_provider"
ON facilities FOR INSERT
WITH CHECK (
  get_my_role() IN ('doctor', 'nurse', 'admin')
);

-- Only admins can edit facility details
CREATE POLICY "facilities_update_admin"
ON facilities FOR UPDATE
USING (
  get_my_role() = 'admin'
);


-- ================================================================
-- SECTION 7: ACCESS_CODES TABLE
-- ================================================================

DROP POLICY IF EXISTS "access_codes_select" ON access_codes;
DROP POLICY IF EXISTS "access_codes_insert" ON access_codes;
DROP POLICY IF EXISTS "access_codes_update" ON access_codes;

-- Any authenticated user can look up a code to verify it
CREATE POLICY "access_codes_select"
ON access_codes FOR SELECT
USING (
  auth.role() = 'authenticated'
);

-- Any authenticated user can generate a new code
CREATE POLICY "access_codes_insert"
ON access_codes FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated'
);

-- Any authenticated user can mark a code as used
CREATE POLICY "access_codes_update"
ON access_codes FOR UPDATE
USING (
  auth.role() = 'authenticated'
);


-- ================================================================
-- SECTION 8: AUDIT_LOG TABLE
-- ================================================================

DROP POLICY IF EXISTS "audit_log_select_admin" ON audit_log;
DROP POLICY IF EXISTS "audit_log_insert"       ON audit_log;

-- Only admins read the full audit trail
CREATE POLICY "audit_log_select_admin"
ON audit_log FOR SELECT
USING (
  get_my_role() = 'admin'
);

-- Any authenticated action can be logged
CREATE POLICY "audit_log_insert"
ON audit_log FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated'
);


-- ================================================================
-- VERIFY: run this after to confirm all policies were created
--
-- SELECT tablename, policyname, cmd, qual
-- FROM   pg_policies
-- WHERE  schemaname = 'public'
-- ORDER  BY tablename, policyname;
-- ================================================================
