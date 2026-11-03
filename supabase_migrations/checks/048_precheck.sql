-- ================================================================
-- 048 pre-check: why patients' Referrals page is always empty
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result.
--
-- The patient's page looks referrals up by account id. Doctors save
-- them under the MediLink ID (ML-NBO-...) and CHWs under the account id,
-- and the policies from 009 only let a patient read MediLink ones. This
-- shows what the live table really holds, without any patient details.
-- ================================================================

SELECT * FROM (
  -- 1. The columns, and their types
  SELECT 1 AS n, column_name AS item, 'column' AS check_name,
         data_type || CASE WHEN is_nullable = 'NO' THEN ' not null' ELSE '' END AS detail
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'referrals'

  UNION ALL
  -- 2. Row level security, and every policy
  SELECT 2, 'referrals', 'RLS',
         CASE WHEN relrowsecurity THEN 'on' ELSE 'OFF' END
  FROM pg_class WHERE oid = to_regclass('public.referrals')
  UNION ALL
  SELECT 2, 'referrals', 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename = 'referrals'

  UNION ALL
  -- 3. Grants
  SELECT 3, 'referrals', 'grants to ' || grantee,
         string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND table_name = 'referrals' AND grantee IN ('anon', 'authenticated')
  GROUP BY grantee

  UNION ALL
  -- 4. What patient_id holds, counted by kind (no ids shown)
  SELECT 4, 'patient_id holds', kind, count(*)::text
  FROM (
    SELECT CASE
      WHEN r.patient_id IS NULL OR btrim(r.patient_id::text) = '' THEN 'empty'
      WHEN EXISTS (SELECT 1 FROM public.users u WHERE u.id::text = r.patient_id::text) THEN 'an account id'
      WHEN EXISTS (SELECT 1 FROM public.users u WHERE u.medilink_id = r.patient_id::text) THEN 'an account MediLink ID'
      WHEN EXISTS (SELECT 1 FROM public.dependent_profiles d WHERE d.id::text = r.patient_id::text) THEN 'a dependant id'
      WHEN EXISTS (SELECT 1 FROM public.dependent_profiles d WHERE d.medilink_id = r.patient_id::text) THEN 'a dependant MediLink ID'
      ELSE 'matches nobody'
    END AS kind
    FROM public.referrals r
  ) k
  GROUP BY kind

  UNION ALL
  -- 5. How many referrals, by status
  SELECT 5, 'referrals', 'status ' || coalesce(status, '(none)'), count(*)::text
  FROM public.referrals GROUP BY status

  UNION ALL
  -- 6. Helper the fix will use
  SELECT 6, 'is_self_or_my_dependant', 'function exists',
         coalesce((SELECT 'yes (' || pg_get_function_identity_arguments(p.oid) || ')'
                   FROM pg_proc p WHERE p.proname = 'is_self_or_my_dependant'
                     AND p.pronamespace = 'public'::regnamespace LIMIT 1), 'no')
  UNION ALL
  SELECT 6, 'my_referrals', 'function exists (expect no)',
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'my_referrals') THEN 'yes' ELSE 'no' END
) checks
ORDER BY n, item, check_name;
