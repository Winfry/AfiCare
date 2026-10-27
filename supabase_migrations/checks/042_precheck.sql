-- ================================================================
-- 042 PRE-CHECK: the rest of step 3 ("saves that always fail")
-- READ-ONLY. It only looks; it changes nothing.
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Then copy ALL rows (Export → Copy as CSV) and paste them back.
--
-- Covers:
--   money     medication_costs, insurance_claims, receipts,
--             medical_expenses, and the storage buckets
--   settings  user_preferences
--   dependant every table the app writes to for a dependant:
--             emergency_profiles, vaccination_records, adherence_log,
--             prescriptions, referrals, lab_orders, care_team,
--             medication_reminders, dependent_profiles, patients
--   unknowns  consultations (a consultation for a dependant)
--
-- One row per table and kind, so it stays under the editor's 100-row
-- limit. Counts are numbers only: no names, no personal details.
-- ================================================================
WITH t(name) AS (VALUES
  ('medication_costs'), ('insurance_claims'), ('receipts'), ('medical_expenses'),
  ('user_preferences'),
  ('emergency_profiles'), ('vaccination_records'), ('adherence_log'), ('prescriptions'),
  ('referrals'), ('lab_orders'), ('care_team'), ('medication_reminders'),
  ('dependent_profiles'), ('patients'), ('consultations')
)
SELECT section, item, detail FROM (

  -- 1. Tables the app uses that don't exist at all
  SELECT 1 AS n, t.name AS section, 'MISSING TABLE' AS item, 'the app reads/writes it, but it does not exist' AS detail
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
  -- 3. Keys and checks (foreign keys show which "patient" a table accepts)
  SELECT 3, k.conrelid::regclass::text, 'constraints',
         string_agg(k.conname || ': ' || pg_get_constraintdef(k.oid), ' | ' ORDER BY k.conname)
  FROM pg_constraint k
  JOIN t ON to_regclass('public.' || t.name) = k.conrelid
  GROUP BY k.conrelid

  UNION ALL
  -- 4. Who may read/write what
  SELECT 4, p.tablename::text, 'policies',
         string_agg(p.policyname || ' [' || p.cmd || ' ' || array_to_string(p.roles, ',') || ']'
                    || ' USING: ' || coalesce(p.qual, '-') || ' CHECK: ' || coalesce(p.with_check, '-'),
                    ' || ' ORDER BY p.policyname)
  FROM pg_policies p
  JOIN t ON t.name = p.tablename
  WHERE p.schemaname = 'public'
  GROUP BY p.tablename

  UNION ALL
  -- 5. Triggers, with what they run
  SELECT 5, tg.tgrelid::regclass::text, 'triggers',
         string_agg(tg.tgname || ' runs ' || regexp_replace(pg_get_functiondef(f.oid), '\s+', ' ', 'g'),
                    ' || ' ORDER BY tg.tgname)
  FROM pg_trigger tg
  JOIN pg_proc f ON f.oid = tg.tgfoid
  JOIN t ON to_regclass('public.' || t.name) = tg.tgrelid
  WHERE NOT tg.tgisinternal
  GROUP BY tg.tgrelid

  UNION ALL
  -- 6. Storage buckets (receipts and provider photos live here)
  SELECT 6, 'storage', 'bucket ' || b.id,
         'public ' || b.public
         || ' · size limit ' || coalesce(b.file_size_limit::text, 'none')
         || ' · types ' || coalesce(array_to_string(b.allowed_mime_types, ','), 'any')
  FROM storage.buckets b

  UNION ALL
  SELECT 6, 'storage', 'no buckets at all', '-'
  WHERE NOT EXISTS (SELECT 1 FROM storage.buckets)

  UNION ALL
  -- 7. Storage permissions
  SELECT 7, 'storage', 'policies',
         string_agg(p.policyname || ' [' || p.cmd || ' ' || array_to_string(p.roles, ',') || ']'
                    || ' USING: ' || coalesce(p.qual, '-') || ' CHECK: ' || coalesce(p.with_check, '-'),
                    ' || ' ORDER BY p.policyname)
  FROM pg_policies p
  WHERE p.schemaname = 'storage' AND p.tablename = 'objects'

  UNION ALL
  -- 8. Dependants that exist, and whether any dependant data is stored
  SELECT 8, 'data', 'dependant profiles', count(*)::text FROM public.dependent_profiles

) checks
ORDER BY n, section, item;
