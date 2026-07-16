# 🔥 CRITICAL FIX: Infinite Recursion in Supabase RLS

## Error You're Seeing

```
PostgrestException(message: infinite recursion detected in policy 
for relation "users", code: 42P17, details: Internal Server Error)
```

## Root Cause

The Supabase Row Level Security (RLS) policies on the `users` table are calling themselves infinitely:

1. User tries to load profile
2. RLS policy checks `get_my_role()` function
3. `get_my_role()` queries `users` table
4. This triggers RLS again → infinite loop
5. Postgres detects recursion and fails

## ✅ Solution

Apply migration `007_fix_users_rls_recursion.sql` to your Supabase database.

---

## 🚀 Quick Fix (3 Steps)

### Step 1: Open Supabase Dashboard

1. Go to: https://supabase.com/dashboard
2. Select your AfiCare project
3. Click "SQL Editor" in left sidebar

### Step 2: Run the Fix SQL

Copy and paste this SQL into the editor:

```sql
-- ================================================================
-- FIX: Infinite recursion in users table RLS
-- ================================================================

-- 1. Recreate get_my_role() as plpgsql (prevents inlining)
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

-- 2. Drop problematic policies
DROP POLICY IF EXISTS "users_select_admin"     ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin"     ON users;

-- 3. Recreate with (SELECT ...) wrapper
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

-- 4. Verify
SELECT policyname, cmd FROM pg_policies
WHERE tablename = 'users' ORDER BY policyname;
```

### Step 3: Click "Run" Button

You should see:
```
Success. No rows returned
```

---

## 🧪 Test the Fix

### On Your Phone:

1. Open AfiCare app
2. Try to login
3. Should now load profile successfully ✅

### If Still Fails:

The issue might be in other tables too. Run this comprehensive fix:

```sql
-- ================================================================
-- COMPREHENSIVE FIX: All RLS policies
-- ================================================================

-- Fix get_my_role() function
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

-- Fix ALL policies that use get_my_role()
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

-- Recreate users policies
CREATE POLICY "users_select_admin"
ON users FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "users_select_consulted"
ON users FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND medilink_id::text IN (
    SELECT patient_id::text FROM consultations
    WHERE provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "users_update_admin"
ON users FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

-- Recreate patients policies
CREATE POLICY "patients_select_consulted"
ON patients FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND id::text IN (
    SELECT u.id::text FROM users u
    JOIN consultations c ON c.patient_id::text = u.medilink_id::text
    WHERE c.provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "patients_select_admin"
ON patients FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

-- Recreate consultations policies
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

-- Recreate facilities policies
CREATE POLICY "facilities_insert_provider"
ON facilities FOR INSERT
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse', 'admin'));

CREATE POLICY "facilities_update_admin"
ON facilities FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

-- Recreate audit_log policies
CREATE POLICY "audit_log_select_admin"
ON audit_log FOR SELECT
USING ((SELECT get_my_role()) = 'admin');
```

---

## 🔍 Verify the Fix

Run this query to check policies:

```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

You should see all policies listed without errors.

---

## 🎯 Alternative: Disable RLS Temporarily (Testing Only)

If you just want to test the app quickly:

```sql
-- WARNING: This removes all security!
-- Only use for local testing!

ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE consultations DISABLE ROW LEVEL SECURITY;
```

Then re-enable after testing:

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
```

---

## 📊 What Changed

### Before (Broken):
```sql
CREATE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE SQL  -- ← Can be inlined, loses SECURITY DEFINER
SECURITY DEFINER
...
```

### After (Fixed):
```sql
CREATE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE plpgsql  -- ← Cannot be inlined, keeps SECURITY DEFINER
SECURITY DEFINER
SET search_path = public  -- ← Security best practice
...
```

---

## 🆘 Still Not Working?

### Check Supabase Connection:

1. Open `aficare_flutter/lib/config/supabase_config.dart`
2. Verify URL and keys are correct
3. Make sure you're using the right Supabase project

### Check User Exists:

```sql
SELECT id, email, role, medilink_id
FROM users
WHERE email = 'your-test-email@example.com';
```

### Check Auth:

```sql
SELECT * FROM auth.users LIMIT 5;
```

---

## ✅ Success Checklist

- [ ] Ran SQL fix in Supabase dashboard
- [ ] Saw "Success" message
- [ ] Verified policies with SELECT query
- [ ] Tested login on phone
- [ ] Profile loads without error
- [ ] Dashboard appears (not blank)

---

**Status**: Fix ready to apply
**Time to fix**: 2 minutes
**Next**: Run the SQL in Supabase dashboard
