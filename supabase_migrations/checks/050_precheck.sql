-- ================================================================
-- 050 pre-check: the "Your care" step of patient sign-up
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result.
--
-- On that step a new patient picks a home facility and adds people she
-- cares for. Three questions:
--   * which relationships does dependent_profiles accept? (sign-up
--     offers child, parent, other; "People I care for" also grandchild
--     and sibling)
--   * can a patient save her home facility (users.facility_id)?
--   * has going Back and Continue already saved the same child twice?
-- Counts only: no names or details are shown.
-- ================================================================

SELECT * FROM (
  -- 1. dependent_profiles: columns
  SELECT 1 AS n, 'dependent_profiles' AS item, 'column: ' || column_name AS check_name,
         data_type || CASE WHEN is_nullable = 'NO' THEN ' not null' ELSE '' END AS detail
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'dependent_profiles'

  UNION ALL
  -- 2. dependent_profiles: constraints (the relationship rule is here)
  SELECT 2, 'dependent_profiles', 'constraint: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint WHERE conrelid = to_regclass('public.dependent_profiles')

  UNION ALL
  -- 3. dependent_profiles: policies
  SELECT 3, 'dependent_profiles', 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename = 'dependent_profiles'

  UNION ALL
  -- 4. Relationships in use today, and how many of each
  SELECT 4, 'dependent_profiles', 'relationship in use: ' || coalesce(relationship, '(none)'), count(*)::text
  FROM public.dependent_profiles GROUP BY relationship

  UNION ALL
  -- 5. Possible duplicates: same guardian, same name (ignoring case and
  --    spaces) and same date of birth, more than once
  SELECT 5, 'dependent_profiles', 'guardians with the same person saved twice or more',
         count(*)::text
  FROM (
    SELECT guardian_id
    FROM public.dependent_profiles
    GROUP BY guardian_id, lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')), date_of_birth
    HAVING count(*) > 1
  ) dups
  UNION ALL
  SELECT 5, 'dependent_profiles', 'extra copies in total',
         coalesce(sum(c - 1), 0)::text
  FROM (
    SELECT count(*) AS c
    FROM public.dependent_profiles
    GROUP BY guardian_id, lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')), date_of_birth
    HAVING count(*) > 1
  ) dups

  UNION ALL
  -- 6. Home facility: does users.facility_id exist, and what does it point at?
  SELECT 6, 'users', 'column facility_id',
         coalesce((SELECT data_type FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'facility_id'), 'MISSING')
  UNION ALL
  SELECT 6, 'users', 'constraint: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid = 'public.users'::regclass AND pg_get_constraintdef(oid) ILIKE '%facility%'
  UNION ALL
  SELECT 6, 'users', 'patients with a home facility',
         (SELECT count(*) FROM public.users WHERE role = 'patient' AND facility_id IS NOT NULL)::text
  UNION ALL
  SELECT 6, 'users', 'can signed-in people update facility_id',
         CASE WHEN has_column_privilege('authenticated', 'public.users', 'facility_id', 'UPDATE')
              THEN 'yes' ELSE 'no' END
  UNION ALL
  -- Triggers on users that might refuse the change
  SELECT 6, 'users', 'trigger: ' || tgname, pg_get_triggerdef(oid)
  FROM pg_trigger WHERE tgrelid = 'public.users'::regclass AND NOT tgisinternal

  UNION ALL
  -- 7. Facilities list: can a patient read it?
  SELECT 7, 'facilities', 'RLS',
         CASE WHEN relrowsecurity THEN 'on' ELSE 'off' END
  FROM pg_class WHERE oid = to_regclass('public.facilities')
  UNION ALL
  SELECT 7, 'facilities', 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') || ' | using: ' || coalesce(qual, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename = 'facilities'
  UNION ALL
  SELECT 7, 'facilities', 'how many', (SELECT count(*) FROM public.facilities)::text
) checks
ORDER BY n, item, check_name;
