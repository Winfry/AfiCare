-- ================================================================
-- QUICK FIX: Infinite Recursion in Supabase RLS
-- 
-- Copy this entire file and run in Supabase SQL Editor
-- ================================================================

-- Step 1: Fix the get_my_role() function
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

-- Step 2: Drop problematic policies
DROP POLICY IF EXISTS "users_select_admin" ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin" ON users;

-- Step 3: Recreate with proper wrapping
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

-- Step 4: Verify (should show 6 policies for users table)
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'users' 
ORDER BY policyname;
