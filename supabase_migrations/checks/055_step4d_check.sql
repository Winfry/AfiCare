-- ================================================================
-- 055 — Step 4d: the database check
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result. No patient details: names of tables, columns,
-- rules and functions, and counts only. A "!" after a column type
-- means it must be filled in (not null). Each table's rules come back
-- as ONE row (rules separated by " ‖ "), so the editor's 100-row limit
-- cannot cut anything off.
--
-- What 4d needs to know:
--   A  Privacy        every rule on users and facilities (any staff
--                     member can read every account today), and how
--                     staff are linked to a facility
--   B  Children's     prescriptions and adherence_log: columns, links
--      medicines      (foreign keys), rules and triggers, to let a
--                     parent add and tick off her child's medicines
--   C  Deleting       may a patient delete her own medicine costs,
--                     claims, receipts (and their pictures), vaccination
--                     records and disability profile?
--   D  Money          medication_costs / insurance_claims / receipts
--                     columns (claim status, paid amount, facility)
--   E  Vaccines       vaccination_records columns and CHECK rules
--                     (can adults record tetanus, HPV, "Other"?)
--   F  Emergency      emergency_profiles columns (to tell "cleared"
--                     from "never filled in")
--   G  Reschedule     the reschedule_appointment function as it is
--                     live (it keeps "Confirmed" today)
-- ================================================================

-- ── B, D, E, F: columns, one row per table ─────────────────────
SELECT 'columns' AS kind, table_name AS name,
       string_agg(column_name || ' ' || data_type
                    || CASE WHEN is_nullable = 'NO' THEN '!' ELSE '' END,
                  ', ' ORDER BY ordinal_position) AS detail
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND (
       table_name IN ('prescriptions', 'adherence_log', 'medication_costs',
                      'insurance_claims', 'receipts', 'vaccination_records',
                      'emergency_profiles', 'disability_profiles',
                      'user_preferences', 'facilities')
    OR (table_name = 'users' AND column_name IN
          ('id', 'role', 'status', 'facility_id', 'medilink_id', 'phone',
           'email', 'full_name', 'specialization', 'department'))
    OR (table_name = 'appointments' AND column_name IN
          ('id', 'patient_id', 'provider_id', 'facility_id', 'status',
           'scheduled_at', 'duration_minutes'))
  )
GROUP  BY table_name

UNION ALL
-- ── A, B, C: rules, one row per table ──────────────────────────
SELECT 'rules', schemaname || '.' || tablename,
       string_agg(policyname || ' [' || cmd || ' to ' || array_to_string(roles, ',')
                    || '] using: ' || COALESCE(qual, '-')
                    || ' | check: ' || COALESCE(with_check, '-'),
                  ' ‖ ' ORDER BY policyname)
FROM   pg_policies
WHERE  (schemaname = 'public' AND tablename IN
          ('users', 'facilities', 'prescriptions', 'adherence_log',
           'medication_costs', 'insurance_claims', 'receipts',
           'vaccination_records', 'emergency_profiles', 'disability_profiles',
           'dependent_profiles', 'appointments'))
   OR  (schemaname = 'storage' AND tablename = 'objects')
GROUP  BY schemaname, tablename

UNION ALL
-- ── B: links to other tables ───────────────────────────────────
SELECT 'link', rel.relname || '.' || con.conname, pg_get_constraintdef(con.oid)
FROM   pg_constraint con
JOIN   pg_class rel     ON rel.oid = con.conrelid
JOIN   pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE  nsp.nspname = 'public'
  AND  con.contype = 'f'
  AND  rel.relname IN ('prescriptions', 'adherence_log', 'medication_costs',
                       'insurance_claims', 'receipts', 'vaccination_records',
                       'disability_profiles')

UNION ALL
-- ── D, E: CHECK rules ──────────────────────────────────────────
SELECT 'check rule', rel.relname || '.' || con.conname, pg_get_constraintdef(con.oid)
FROM   pg_constraint con
JOIN   pg_class rel     ON rel.oid = con.conrelid
JOIN   pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE  nsp.nspname = 'public'
  AND  con.contype = 'c'
  AND  rel.relname IN ('prescriptions', 'adherence_log', 'medication_costs',
                       'insurance_claims', 'receipts', 'vaccination_records',
                       'emergency_profiles', 'appointments')

UNION ALL
-- ── B: triggers ────────────────────────────────────────────────
SELECT 'trigger', event_object_table || '.' || trigger_name,
       string_agg(DISTINCT action_timing || ' ' || event_manipulation, ', ')
         || ' → ' || MAX(action_statement)
FROM   information_schema.triggers
WHERE  event_object_schema = 'public'
  AND  event_object_table IN ('prescriptions', 'adherence_log', 'vaccination_records',
                              'users', 'dependent_profiles', 'facilities')
GROUP  BY event_object_table, trigger_name

UNION ALL
-- ── C: buckets ─────────────────────────────────────────────────
SELECT 'bucket', id,
       'public=' || public::text
         || COALESCE(' size_limit=' || file_size_limit::text, '')
FROM   storage.buckets

UNION ALL
-- ── A, B, G: functions as they are live (full text) ────────────
SELECT 'function', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       'security definer=' || p.prosecdef::text || E'\n' || pg_get_functiondef(p.oid)
FROM   pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname IN ('reschedule_appointment', 'provider_can_see_patient',
                     'is_self_or_my_dependant', 'check_record_patient',
                     'delete_records_of_removed_patient', 'get_my_role')

UNION ALL
-- ── Counts (no details) ────────────────────────────────────────
SELECT 'count', 'accounts by role', string_agg(role || '=' || n, ', ' ORDER BY role)
FROM   (SELECT COALESCE(role, '?') AS role, COUNT(*)::text AS n
        FROM public.users GROUP BY 1) r
UNION ALL
SELECT 'count', 'staff accounts with a facility_id',
       COUNT(*)::text
FROM   public.users
WHERE  role <> 'patient' AND facility_id IS NOT NULL
UNION ALL
SELECT 'count', 'patient accounts with a facility_id',
       COUNT(*)::text
FROM   public.users
WHERE  role = 'patient' AND facility_id IS NOT NULL
UNION ALL
SELECT 'count', 'prescriptions / written by the patient herself',
       COUNT(*)::text || ' / ' || COUNT(*) FILTER (WHERE provider_id = patient_id)::text
FROM   public.prescriptions
UNION ALL
SELECT 'count', 'adherence_log rows', COUNT(*)::text FROM public.adherence_log
UNION ALL
SELECT 'count', 'vaccination_records rows', COUNT(*)::text FROM public.vaccination_records
UNION ALL
SELECT 'count', 'medication_costs / insurance_claims / receipts rows',
       (SELECT COUNT(*) FROM public.medication_costs)::text || ' / '
         || (SELECT COUNT(*) FROM public.insurance_claims)::text || ' / '
         || (SELECT COUNT(*) FROM public.receipts)::text

ORDER  BY 1, 2;
