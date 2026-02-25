-- ================================================================
-- 006: Fix Supabase Security Advisor warnings
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================

-- ── FIX 1: Set search_path on get_my_role() ──────────────────
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role
  FROM   users
  WHERE  id::text = (auth.uid())::text
$$;

-- ── FIX 2: Drop "Allow all" policies that bypass RLS ────────
-- These policies use USING (true) FOR ALL, which makes RLS useless.
-- The proper per-role policies from 002_rls_policies.sql already exist.

DROP POLICY IF EXISTS "Allow all for users"          ON users;
DROP POLICY IF EXISTS "Allow all for patients"       ON patients;
DROP POLICY IF EXISTS "Allow all for consultations"  ON consultations;
DROP POLICY IF EXISTS "Allow all for access_codes"   ON access_codes;
DROP POLICY IF EXISTS "Allow all for audit_log"      ON audit_log;

-- ── VERIFY: list remaining policies ──────────────────────────
SELECT tablename, policyname, cmd, qual
FROM   pg_policies
WHERE  schemaname = 'public'
ORDER  BY tablename, policyname;
