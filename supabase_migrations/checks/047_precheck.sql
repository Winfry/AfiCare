-- ================================================================
-- 047 pre-check: who can really see Mental wellbeing and Women's health
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result.
--
-- Why: the Mental wellbeing page says "nobody sees this unless you
-- choose to share it", and the Women's health page says "you and the
-- clinicians caring for you (and caregivers)". Before changing that
-- wording we need the truth from the live database:
--   * Mental wellbeing is stored in mood_entries and
--     mental_health_screenings.
--   * Women's health (cycle, periods, symptoms) is stored inside the
--     account row, users.metadata -> 'maternal_health'. Whoever can read
--     a user row can read it.
-- Counts only: no one's health details are shown by this query.
-- ================================================================

WITH tables AS (
  SELECT unnest(ARRAY['mood_entries', 'mental_health_screenings', 'users']) AS t
)
SELECT * FROM (
  -- 1. Does each table exist, with row level security on?
  SELECT 1 AS n, t AS item, 'exists / RLS on' AS check_name,
         CASE WHEN c.oid IS NULL THEN 'MISSING'
              ELSE 'exists, RLS ' || CASE WHEN c.relrowsecurity THEN 'on' ELSE 'OFF' END END AS detail
  FROM tables
  LEFT JOIN pg_class c ON c.relname = t AND c.relnamespace = 'public'::regnamespace

  UNION ALL
  -- 2. Every policy on those tables: who (roles), what (command), when (rule)
  SELECT 2, p.tablename, 'policy: ' || p.policyname,
         p.cmd || ' to ' || array_to_string(p.roles, ',') ||
         ' | using: ' || coalesce(p.qual, '-') ||
         ' | check: ' || coalesce(p.with_check, '-')
  FROM pg_policies p
  WHERE p.schemaname = 'public' AND p.tablename IN (SELECT t FROM tables)

  UNION ALL
  -- 3. Table grants to signed-out (anon) and signed-in (authenticated)
  SELECT 3, g.table_name, 'grants to ' || g.grantee,
         string_agg(g.privilege_type, ',' ORDER BY g.privilege_type)
  FROM information_schema.role_table_grants g
  WHERE g.table_schema = 'public' AND g.table_name IN (SELECT t FROM tables)
    AND g.grantee IN ('anon', 'authenticated')
  GROUP BY g.table_name, g.grantee

  UNION ALL
  -- 4. How many accounts hold Women's health details, and of what role
  SELECT 4, 'users', 'accounts with women''s health details (role ' || coalesce(u.role, '?') || ')',
         count(*)::text
  FROM public.users u
  WHERE (u.metadata::jsonb) ? 'maternal_health'
  GROUP BY u.role

  UNION ALL
  -- 5. How many staff accounts exist (these may be able to read user rows)
  SELECT 5, 'users', 'accounts with role ' || coalesce(u.role, '?'), count(*)::text
  FROM public.users u
  GROUP BY u.role

  UNION ALL
  -- 6. How many rows the mental wellbeing tables hold (counts only)
  SELECT 6, 'mood_entries', 'rows', (SELECT count(*) FROM public.mood_entries)::text
  UNION ALL
  SELECT 6, 'mental_health_screenings', 'rows', (SELECT count(*) FROM public.mental_health_screenings)::text

  UNION ALL
  -- 7. Helper functions the policies may call: do they exist?
  SELECT 7, f.fname, 'function exists',
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc pr WHERE pr.proname = f.fname
                           AND pr.pronamespace = 'public'::regnamespace) THEN 'yes' ELSE 'no' END
  FROM unnest(ARRAY['provider_can_see_patient', 'get_my_role', 'is_self_or_my_dependant',
                    'caregiver_view']) AS f(fname)

  UNION ALL
  -- 8. Does the caregiver view ever read mental health or women's health?
  SELECT 8, 'caregiver_view', 'mentions ' || w.word,
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc pr WHERE pr.proname = 'caregiver_view'
                           AND pr.prosrc ILIKE '%' || w.word || '%') THEN 'yes' ELSE 'no' END
  FROM unnest(ARRAY['mood_entries', 'mental_health', 'maternal_health', 'metadata']) AS w(word)

  UNION ALL
  -- 9. Other database functions that read users.metadata (could pass it on)
  SELECT 9, pr.proname, 'function reads metadata', 'yes'
  FROM pg_proc pr
  WHERE pr.pronamespace = 'public'::regnamespace
    AND pr.prosrc ILIKE '%metadata%'
) checks
ORDER BY n, item, check_name;
