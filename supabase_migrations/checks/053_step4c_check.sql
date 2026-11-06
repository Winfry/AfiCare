-- ================================================================
-- 053 — Step 4c: the database check
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result. No patient details: names of tables, columns,
-- rules and extensions, and counts only. A "!" after a column type
-- means it must be filled in (not null).
--
-- Step 4c removes the "fake" buttons. Four of them need the database:
--   A  Accessibility  user_preferences: which settings columns exist
--                     (Bold text needs a new one), and may a patient
--                     save her own row?
--   B  Insurance      patients: is there anywhere to keep the insurer's
--                     name (today only insurance_id, the policy number)?
--   C  Photo          users.photo_url, every storage bucket, every
--                     storage rule, and anything on users that could
--                     refuse a patient changing her own photo_url
--   D  Follow-ups     consultations' follow-up columns and appointments'
--                     columns, to tell "booked" from "not booked"
--   E  Helpers        the functions the new photo rules would reuse
--   F  SMS (next)     what the SMS stage will rely on: pg_cron / pg_net,
--                     phone numbers on accounts, reminder columns
-- ================================================================

-- ── A, B, D, F: columns (one row per table, so the editor's 100-row
--    limit cannot cut anything off) ─────────────────────────────
SELECT 'columns' AS kind, table_name AS name,
       string_agg(column_name || ' ' || data_type
                    || CASE WHEN is_nullable = 'NO' THEN '!' ELSE '' END,
                  ', ' ORDER BY ordinal_position) AS detail
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND (
       table_name = 'user_preferences'
    OR (table_name = 'patients'      AND (column_name LIKE 'insur%' OR column_name = 'id'))
    OR (table_name = 'users'         AND column_name IN ('id', 'phone', 'photo_url', 'role'))
    OR (table_name = 'consultations' AND (column_name LIKE 'follow%' OR column_name IN ('patient_id', 'created_at')))
    OR  table_name = 'appointments'
    OR  table_name = 'medication_reminders'
  )
GROUP  BY table_name

UNION ALL
-- ── A, C: rules on the tables touched ───────────────────────────
SELECT 'rule', tablename || ': ' || policyname,
       cmd || ' to ' || array_to_string(roles, ',')
         || ' | using: '      || COALESCE(qual, '-')
         || ' | with check: ' || COALESCE(with_check, '-')
FROM   pg_policies
WHERE  (schemaname = 'public'  AND tablename IN ('user_preferences', 'users', 'patients'))
   OR  (schemaname = 'storage' AND tablename = 'objects')

UNION ALL
-- ── A, B, F: CHECK rules on these tables (e.g. which reminder
--    frequencies medication_reminders accepts: 5 and 6 a day?) ──
SELECT 'check rule', rel.relname || ': ' || con.conname, pg_get_constraintdef(con.oid)
FROM   pg_constraint con
JOIN   pg_class rel     ON rel.oid = con.conrelid
JOIN   pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE  nsp.nspname = 'public'
  AND  con.contype = 'c'
  AND  rel.relname IN ('medication_reminders', 'user_preferences', 'patients', 'appointments')

UNION ALL
-- ── C: buckets ──────────────────────────────────────────────────
SELECT 'bucket', id,
       'public=' || public::text
         || COALESCE(' size_limit=' || file_size_limit::text, '')
         || COALESCE(' types=' || array_to_string(allowed_mime_types, ','), '')
FROM   storage.buckets

UNION ALL
-- ── C: triggers on users and patients (could refuse an update) ──
SELECT 'trigger', event_object_table || ': ' || trigger_name,
       action_timing || ' ' || event_manipulation || ' → ' || action_statement
FROM   information_schema.triggers
WHERE  event_object_schema = 'public'
  AND  event_object_table IN ('users', 'patients', 'user_preferences')

UNION ALL
-- ── E: helper functions ─────────────────────────────────────────
SELECT 'function', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       'security definer=' || p.prosecdef::text
FROM   pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname IN ('provider_can_see_patient', 'is_self_or_my_dependant', 'get_my_role')

UNION ALL
-- ── F: extensions (installed, or available to switch on) ────────
SELECT 'extension', name,
       'installed=' || COALESCE(installed_version, 'no') || ' available=' || default_version
FROM   pg_available_extensions
WHERE  name IN ('pg_cron', 'pg_net', 'http')

UNION ALL
-- ── Counts (no details) ─────────────────────────────────────────
SELECT 'count', 'patient accounts', COUNT(*)::text
FROM   public.users WHERE role = 'patient'
UNION ALL
SELECT 'count', 'patient accounts with a phone number', COUNT(*)::text
FROM   public.users WHERE role = 'patient' AND COALESCE(phone, '') <> ''
UNION ALL
SELECT 'count', 'patient accounts with a photo_url', COUNT(*)::text
FROM   public.users WHERE role = 'patient' AND COALESCE(photo_url, '') <> ''
UNION ALL
SELECT 'count', 'user_preferences rows', COUNT(*)::text
FROM   public.user_preferences

ORDER  BY 1, 2;
