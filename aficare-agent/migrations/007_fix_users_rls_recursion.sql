-- ================================================================
-- Migration 007: Fix infinite recursion in users table RLS
--
-- Problem: users_select_admin and users_select_consulted call
-- get_my_role() which queries the users table, triggering RLS
-- evaluation on users again → infinite loop.
--
-- Root cause: LANGUAGE SQL functions can be inlined by Postgres,
-- which strips the SECURITY DEFINER flag and applies RLS to the
-- inlined query body → recursion.
--
-- Fix:
--   a) Change get_my_role() to LANGUAGE plpgsql (cannot be inlined)
--   b) Add SET search_path = public (security best practice)
--   c) Wrap calls in (SELECT ...) as extra inlining prevention
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================

-- 1. Recreate get_my_role() as plpgsql — prevents inlining
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

-- 2. Drop the problematic users-table policies
DROP POLICY IF EXISTS "users_select_admin"     ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin"     ON users;

-- 3. Recreate with (SELECT ...) wrapper as extra safety
CREATE POLICY "users_select_admin"
ON users FOR SELECT
USING (
  (SELECT get_my_role()) = 'admin'
);

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
USING (
  (SELECT get_my_role()) = 'admin'
);

-- ================================================================
-- VERIFY after running:
--
-- SELECT policyname, cmd, qual FROM pg_policies
-- WHERE tablename = 'users' ORDER BY policyname;
-- ================================================================
