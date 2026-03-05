-- ================================================================
-- COMPLETE FIX: All Infinite Recursion Issues in Supabase RLS
-- 
-- This fixes ALL tables that might have recursion problems
-- Copy and run this entire file in Supabase SQL Editor
-- ================================================================

-- ================================================================
-- STEP 1: Fix the get_my_role() function (CRITICAL)
-- ================================================================
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

-- ================================================================
-- STEP 2: Drop ALL policies that use get_my_role()
-- ================================================================

-- Users table
DROP POLICY IF EXISTS "users_select_admin" ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin" ON users;

-- Patients table
DROP POLICY IF EXISTS "patients_select_consulted" ON patients;
DROP POLICY IF EXISTS "patients_select_admin" ON patients;

-- Consultations table
DROP POLICY IF EXISTS "consultations_select_admin" ON consultations;
DROP POLICY IF EXISTS "consultations_insert_provider" ON consultations;
DROP POLICY IF EXISTS "consultations_update_provider" ON consultations;

-- Facilities table
DROP POLICY IF EXISTS "facilities_insert_provider" ON facilities;
DROP POLICY IF EXISTS "facilities_update_admin" ON facilities;

-- Audit log table
DROP POLICY IF EXISTS "audit_log_select_admin" ON audit_log;

-- ================================================================
-- STEP 3: Recreate ALL policies with proper (SELECT ...) wrapper
-- ================================================================

-- USERS TABLE POLICIES
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

-- PATIENTS TABLE POLICIES
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

-- CONSULTATIONS TABLE POLICIES
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

-- FACILITIES TABLE POLICIES
CREATE POLICY "facilities_insert_provider"
ON facilities FOR INSERT
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse', 'admin'));

CREATE POLICY "facilities_update_admin"
ON facilities FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

-- AUDIT LOG TABLE POLICIES
CREATE POLICY "audit_log_select_admin"
ON audit_log FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

-- ================================================================
-- STEP 4: Verify all policies were created
-- ================================================================
SELECT 
  tablename, 
  policyname, 
  cmd,
  CASE 
    WHEN qual LIKE '%get_my_role%' THEN '✓ Uses get_my_role'
    ELSE 'Simple policy'
  END as policy_type
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ================================================================
-- Expected output:
-- Should show all policies for:
-- - users (6 policies)
-- - patients (5 policies)  
-- - consultations (5 policies)
-- - facilities (3 policies)
-- - access_codes (3 policies)
-- - audit_log (2 policies)
-- ================================================================
