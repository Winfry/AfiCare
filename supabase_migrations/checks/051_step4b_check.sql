-- ================================================================
-- 051 — Step 4b: the database check
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result. No patient details: names of tables, columns and
-- rules, and counts only.
--
-- The patient audit (docs/patient_audit_2026-10-28.md, "Needs a database
-- check first") had 13 open questions. Step 4a answered 7 (messages,
-- men's health, "parent", home facility, access codes). These are the
-- rest, plus two that protect fixes made in 4a:
--   A  2.5   Lab results: can a patient read hers, and are orders and
--            results linked (the app loads them together)?
--   B  4.4   Mental wellbeing tables: what do their patient ids point at?
--   C  4.6   Disability profiles: links, the one-per-person rule the app
--            relies on, and who can read and write
--   D  3.7   Medicine dose times: stored with or without a time zone?
--   E  5.3   The caregiver view reads these columns: do they all exist?
--   F  4a    Expenses and medicine doses: may a patient change and
--            delete her own (deletes and "Mark taken" now wait for the
--            database to confirm)?
--
-- Counts use query_to_xml so a table that does not exist on this
-- database leaves its row out instead of stopping the whole check.
-- ================================================================

WITH expected(tbl, col) AS (
  VALUES
    -- what caregiver_view() (036) reads
    ('prescriptions', 'id'), ('prescriptions', 'patient_id'), ('prescriptions', 'provider_id'),
    ('prescriptions', 'medication_name'), ('prescriptions', 'dosage'), ('prescriptions', 'frequency'),
    ('prescriptions', 'duration'), ('prescriptions', 'instructions'), ('prescriptions', 'issued_at'),
    ('prescriptions', 'status'),
    ('lab_orders', 'id'), ('lab_orders', 'patient_id'), ('lab_orders', 'test_name'),
    ('lab_orders', 'status'), ('lab_orders', 'ordered_at'),
    ('lab_results', 'lab_order_id'), ('lab_results', 'result_value'), ('lab_results', 'result_unit'),
    ('lab_results', 'reference_range_low'), ('lab_results', 'reference_range_high'),
    ('lab_results', 'result_flag'), ('lab_results', 'resulted_at')
)
SELECT * FROM (
  -- ── A. Lab results ─────────────────────────────────────────────
  SELECT 'A' AS part, t AS item, 'table' AS check_name,
         CASE WHEN c.oid IS NULL THEN 'MISSING'
              ELSE 'exists, RLS ' || CASE WHEN c.relrowsecurity THEN 'on' ELSE 'OFF' END END AS detail
  FROM unnest(ARRAY['lab_orders', 'lab_results']) AS t
  LEFT JOIN pg_class c ON c.relname = t AND c.relnamespace = 'public'::regnamespace
  UNION ALL
  SELECT 'A', tablename, 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('lab_orders', 'lab_results')
  UNION ALL
  SELECT 'A', conrelid::regclass::text, 'link: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE contype = 'f' AND conrelid IN (to_regclass('public.lab_orders'), to_regclass('public.lab_results'))
  UNION ALL
  SELECT 'A', 'lab_orders', 'column patient_id type',
         coalesce((SELECT data_type FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'lab_orders' AND column_name = 'patient_id'), 'MISSING')
  UNION ALL
  SELECT 'A', 'lab_orders', 'rows', (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM public.lab_orders', false, true, '')))[1]::text
  WHERE to_regclass('public.lab_orders') IS NOT NULL
  UNION ALL
  SELECT 'A', 'lab_results', 'rows', (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM public.lab_results', false, true, '')))[1]::text
  WHERE to_regclass('public.lab_results') IS NOT NULL

  -- ── B. Mental wellbeing tables: what patient_id points at ──────
  UNION ALL
  SELECT 'B', conrelid::regclass::text, 'constraint: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid IN (to_regclass('public.mood_entries'), to_regclass('public.mental_health_screenings'))
  UNION ALL
  SELECT 'B', 'patients', 'table exists',
         CASE WHEN to_regclass('public.patients') IS NULL THEN 'no' ELSE 'yes' END
  UNION ALL
  SELECT 'B', 'patients', 'patient accounts without a patients row',
         (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM public.users u WHERE u.role = ''patient'' AND NOT EXISTS (SELECT 1 FROM public.patients p WHERE p.id = u.id)', false, true, '')))[1]::text
  WHERE to_regclass('public.patients') IS NOT NULL

  -- ── C. Disability profiles ─────────────────────────────────────
  UNION ALL
  SELECT 'C', 'disability_profiles', 'table',
         CASE WHEN c.oid IS NULL THEN 'MISSING'
              ELSE 'exists, RLS ' || CASE WHEN c.relrowsecurity THEN 'on' ELSE 'OFF' END END
  FROM (SELECT to_regclass('public.disability_profiles') AS oid) x
  LEFT JOIN pg_class c ON c.oid = x.oid
  UNION ALL
  SELECT 'C', 'disability_profiles', 'column: ' || column_name,
         data_type || CASE WHEN is_nullable = 'NO' THEN ' not null' ELSE '' END
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'disability_profiles'
  UNION ALL
  SELECT 'C', 'disability_profiles', 'constraint: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint WHERE conrelid = to_regclass('public.disability_profiles')
  UNION ALL
  SELECT 'C', 'disability_profiles', 'unique index: ' || indexrelid::regclass::text,
         pg_get_indexdef(indexrelid)
  FROM pg_index WHERE indrelid = to_regclass('public.disability_profiles') AND indisunique
  UNION ALL
  SELECT 'C', 'disability_profiles', 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename = 'disability_profiles'
  UNION ALL
  SELECT 'C', 'disability_profiles', 'grants to ' || grantee,
         string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND table_name = 'disability_profiles' AND grantee IN ('anon', 'authenticated')
  GROUP BY grantee
  UNION ALL
  SELECT 'C', 'disability_profiles', 'rows', (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM public.disability_profiles', false, true, '')))[1]::text
  WHERE to_regclass('public.disability_profiles') IS NOT NULL

  -- ── D. Medicine dose times ─────────────────────────────────────
  UNION ALL
  SELECT 'D', table_name, 'column ' || column_name || ' type', data_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND ((table_name = 'adherence_log' AND column_name IN ('scheduled_time', 'taken_time'))
      OR (table_name = 'medication_reminders' AND column_name IN ('times', 'start_date', 'end_date')))

  -- ── E. Columns the caregiver view reads ────────────────────────
  UNION ALL
  SELECT 'E', e.tbl || '.' || e.col, 'column exists',
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns ic
                           WHERE ic.table_schema = 'public' AND ic.table_name = e.tbl AND ic.column_name = e.col)
              THEN 'ok' ELSE 'MISSING' END
  FROM expected e
  UNION ALL
  SELECT 'E', 'caregiver_view', 'function exists',
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'caregiver_view'
                           AND pronamespace = 'public'::regnamespace) THEN 'yes' ELSE 'no' END

  -- ── F. Expenses and doses: her own changes and deletes ─────────
  UNION ALL
  SELECT 'F', tablename, 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('medical_expenses', 'adherence_log')
  UNION ALL
  SELECT 'F', table_name, 'grants to ' || grantee,
         string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND table_name IN ('medical_expenses', 'adherence_log')
    AND grantee IN ('anon', 'authenticated')
  GROUP BY table_name, grantee
) checks
ORDER BY part, item, check_name;
