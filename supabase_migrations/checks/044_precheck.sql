-- ================================================================
-- 044 PRE-CHECK: rebuilding "Share my records"
-- READ-ONLY. It only looks; it changes nothing.
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Then copy ALL rows (Export → Copy as CSV) and paste them back.
--
-- Covers:
--   sharing   access_codes: its columns, keys, rules, triggers, who is
--             granted what, and any function or rule that uses it
--   records   the tables a share would read from: users, patients,
--             emergency_profiles, consultations, prescriptions,
--             lab_orders, lab_results, vaccination_records,
--             dependent_profiles
--   logging   audit_log (who opened whose record)
--   helpers   the shared functions earlier steps added
--
-- Counts are numbers only: no codes, no names, no personal details.
-- ================================================================
WITH t(name) AS (VALUES
  ('access_codes'), ('audit_log'),
  ('users'), ('patients'), ('emergency_profiles'), ('consultations'),
  ('prescriptions'), ('lab_orders'), ('lab_results'), ('vaccination_records'),
  ('dependent_profiles')
),
-- Only the sharing tables need their rules and triggers in full.
s(name) AS (VALUES ('access_codes'), ('audit_log'))
SELECT section, item, detail FROM (

  -- 1. Tables a share would use that don't exist at all
  SELECT 1 AS n, t.name AS section, 'MISSING TABLE' AS item, 'does not exist' AS detail
  FROM t WHERE to_regclass('public.' || t.name) IS NULL

  UNION ALL
  -- 2. Columns (with row count and whether row level security is on)
  SELECT 2, c.table_name::text,
         'columns · ' || (
           SELECT (xpath('/row/c/text()',
                   query_to_xml(format('SELECT count(*) AS c FROM public.%I', c.table_name), false, true, '')))[1]::text
         ) || ' rows · RLS ' || (
           SELECT CASE WHEN relrowsecurity THEN 'on' ELSE 'OFF' END
           FROM pg_class WHERE oid = to_regclass('public.' || c.table_name)
         ),
         string_agg(
           c.column_name || ' '
           || CASE WHEN c.data_type IN ('USER-DEFINED', 'ARRAY') THEN c.udt_name ELSE c.data_type END
           || CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END
           || coalesce(' DEFAULT ' || c.column_default, ''),
           ' | ' ORDER BY c.ordinal_position)
  FROM information_schema.columns c
  JOIN t ON t.name = c.table_name
  WHERE c.table_schema = 'public'
  GROUP BY c.table_name

  UNION ALL
  -- 3. Keys and checks on the sharing tables
  SELECT 3, k.conrelid::regclass::text, 'constraints',
         string_agg(k.conname || ': ' || pg_get_constraintdef(k.oid), ' | ' ORDER BY k.conname)
  FROM pg_constraint k
  JOIN s ON to_regclass('public.' || s.name) = k.conrelid
  GROUP BY k.conrelid

  UNION ALL
  -- 4. Who may read/write the sharing tables
  SELECT 4, p.tablename::text, 'policies',
         string_agg(p.policyname || ' [' || p.cmd || ' ' || array_to_string(p.roles, ',') || ']'
                    || ' USING: ' || coalesce(p.qual, '-') || ' CHECK: ' || coalesce(p.with_check, '-'),
                    ' || ' ORDER BY p.policyname)
  FROM pg_policies p
  JOIN s ON s.name = p.tablename
  WHERE p.schemaname = 'public'
  GROUP BY p.tablename

  UNION ALL
  SELECT 4, s.name, 'policies', 'NONE'
  FROM s
  WHERE to_regclass('public.' || s.name) IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'public' AND p.tablename = s.name)

  UNION ALL
  -- 5. Rules on OTHER tables that open records through access_codes
  SELECT 5, p.tablename::text, 'policy using access_codes: ' || p.policyname,
         '[' || p.cmd || '] USING: ' || coalesce(p.qual, '-') || ' CHECK: ' || coalesce(p.with_check, '-')
  FROM pg_policies p
  WHERE p.schemaname = 'public'
    AND p.tablename <> 'access_codes'
    AND (coalesce(p.qual, '') ILIKE '%access_codes%' OR coalesce(p.with_check, '') ILIKE '%access_codes%')

  UNION ALL
  -- 6. Triggers on the sharing tables
  SELECT 6, tg.tgrelid::regclass::text, 'triggers',
         string_agg(tg.tgname || ' runs ' || f.proname, ' | ' ORDER BY tg.tgname)
  FROM pg_trigger tg
  JOIN pg_proc f ON f.oid = tg.tgfoid
  JOIN s ON to_regclass('public.' || s.name) = tg.tgrelid
  WHERE NOT tg.tgisinternal
  GROUP BY tg.tgrelid

  UNION ALL
  -- 7. Database functions that mention access_codes
  SELECT 7, 'functions', 'uses access_codes: ' || f.proname,
         pg_get_function_identity_arguments(f.oid)
         || CASE WHEN f.prosecdef THEN ' · SECURITY DEFINER' ELSE '' END
  FROM pg_proc f
  JOIN pg_namespace ns ON ns.oid = f.pronamespace
  WHERE ns.nspname = 'public' AND f.prosrc ILIKE '%access_codes%'

  UNION ALL
  -- 8. What signed-in and signed-out users are granted on access_codes
  SELECT 8, 'access_codes', 'grants',
         string_agg(g.grantee || ':' || g.privilege_type, ', ' ORDER BY g.grantee, g.privilege_type)
  FROM information_schema.role_table_grants g
  WHERE g.table_schema = 'public' AND g.table_name = 'access_codes'
    AND g.grantee IN ('anon', 'authenticated')

  UNION ALL
  -- 9. What is in access_codes now (numbers only)
  SELECT 9, 'access_codes', 'codes by length',
         coalesce(string_agg(len || ' chars: ' || cnt, ', ' ORDER BY len), 'no codes')
  FROM (
    SELECT length(code) AS len, count(*) AS cnt
    FROM public.access_codes GROUP BY length(code)
  ) x

  UNION ALL
  SELECT 9, 'access_codes', 'still open (not used, not expired)',
         count(*)::text
  FROM public.access_codes
  WHERE NOT coalesce(is_used, false) AND expires_at > now()

  UNION ALL
  SELECT 9, 'access_codes', 'ever opened by someone (used_by set)',
         count(*)::text
  FROM public.access_codes WHERE used_by IS NOT NULL

  UNION ALL
  SELECT 9, 'access_codes', 'codes for someone without an account (a dependant)',
         count(*)::text
  FROM public.access_codes a
  WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = a.patient_id)

  UNION ALL
  -- 10. The audit log: which actions are already written
  SELECT 10, 'audit_log', 'actions so far',
         coalesce(string_agg(action || ': ' || cnt, ', ' ORDER BY action), 'empty')
  FROM (SELECT action, count(*) AS cnt FROM public.audit_log GROUP BY action) x

  UNION ALL
  -- 11. Roles that exist (decides who may open a share)
  SELECT 11, 'users', 'accounts by role',
         string_agg(coalesce(role::text, '(none)') || ': ' || cnt, ', ' ORDER BY role::text)
  FROM (SELECT role, count(*) AS cnt FROM public.users GROUP BY role) x

  UNION ALL
  -- 12. Helpers from earlier steps, and random-code support
  SELECT 12, 'helpers', h.fn,
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc f JOIN pg_namespace ns ON ns.oid = f.pronamespace
                           WHERE f.proname = h.fn AND ns.nspname IN ('public', 'extensions', 'pg_catalog'))
              THEN 'exists' ELSE 'MISSING' END
  FROM (VALUES ('get_my_role'), ('is_self_or_my_dependant'), ('provider_can_see_patient'),
               ('gen_random_uuid'), ('gen_random_bytes')) h(fn)

) checks
ORDER BY n, section, item;
