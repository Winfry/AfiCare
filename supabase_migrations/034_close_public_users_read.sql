-- ================================================================
-- 034: Close anonymous read access to public.users
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 033_restore_patient_own_policies.sql
-- ================================================================
--
-- WHY
-- The live database had a policy on users that is in no migration file
-- (it was added by hand in the dashboard):
--
--   "Allow phone lookup for login"  FOR SELECT  TO public  USING (true)
--
-- `public` includes the anonymous role, so anyone holding the app's
-- publishable key — which ships inside the web app — could read every
-- row of users without logging in: names, emails, phone numbers,
-- MediLink IDs and roles. Confirmed 2026-10-12: an unauthenticated
-- request returned all 15 accounts.
--
-- Phone + PIN login no longer needs it (the `patient-auth` Edge Function
-- does that lookup with the service role). The only remaining caller is
-- MediLink ID login, which looks up the account's email before sign-in.
-- That moves to login_email_for_medilink() below, which returns one
-- email for one exact ID and nothing else.
--
-- Because that policy also happened to be what let staff search patients
-- and let patients see their care team's names, those two legitimate
-- reads get explicit policies here so nothing else breaks:
--   * staff (doctor, nurse, radiologist, chw, facility_admin) can read
--     user rows — patient search and lookups need this;
--   * any signed-in user can read STAFF rows (role <> 'patient') — care
--     team, messages and provider names need this. Patients still
--     cannot read other patients.
-- Own-row, admin and access-code policies already exist and are kept.
--
-- APP CHANGE REQUIRED: AuthProvider.signInWithMedilinkId must call the
-- RPC. Deploy the app change together with this migration, or MediLink
-- ID login will fail until it is deployed. Phone + PIN login is
-- unaffected either way.
-- ================================================================

BEGIN;

-- 1. MediLink ID → email, for the login screen only. SECURITY DEFINER so
--    it can read users without any policy granting anon access. Exact
--    match only, so it cannot be used to list or search accounts.
CREATE OR REPLACE FUNCTION public.login_email_for_medilink(p_medilink_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF p_medilink_id IS NULL OR length(trim(p_medilink_id)) = 0 THEN
    RETURN NULL;
  END IF;
  RETURN (
    SELECT email
    FROM   users
    WHERE  medilink_id = upper(trim(p_medilink_id))
       OR  medilink_id = trim(p_medilink_id)
    LIMIT  1
  );
END;
$$;

REVOKE ALL ON FUNCTION public.login_email_for_medilink(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_email_for_medilink(text) TO anon, authenticated;

-- 2. Remove the policy that made the whole table public.
DROP POLICY IF EXISTS "Allow phone lookup for login" ON public.users;

-- 3. Explicit replacements for the legitimate reads it was covering.
DROP POLICY IF EXISTS "users_select_staff" ON public.users;
CREATE POLICY "users_select_staff"
ON public.users FOR SELECT
TO authenticated
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse', 'radiologist', 'chw', 'facility_admin')
);

DROP POLICY IF EXISTS "users_select_staff_rows" ON public.users;
CREATE POLICY "users_select_staff_rows"
ON public.users FOR SELECT
TO authenticated
USING (
  role <> 'patient'
);

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- 1. "Allow phone lookup for login" must be gone; the two new
--    policies must be listed.
SELECT policyname, cmd, roles
FROM   pg_policies
WHERE  schemaname = 'public' AND tablename = 'users'
ORDER  BY policyname;

-- 2. The role/status lock from 010 must exist. If this returns no row,
--    run 010_role_escalation_fix.sql too: without it a signed-in user
--    can change their own role.
SELECT tgname
FROM   pg_trigger
WHERE  tgrelid = 'public.users'::regclass
  AND  tgname = 'trg_enforce_role_status_lock';
