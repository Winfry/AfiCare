-- 046 pre-check: Men's health screenings, before the three tools are rebuilt.
-- READ-ONLY. It only looks; it changes nothing. Paste into the Supabase SQL
-- Editor, press Run, and send back the whole result (one table).

WITH t AS (SELECT to_regclass('public.mens_health_screenings') AS rel)
SELECT 1 AS n, 'table exists' AS what,
       CASE WHEN rel IS NULL THEN 'NO' ELSE 'yes' END AS detail
FROM t

UNION ALL
-- every column: name, type, nullable, default
SELECT 2, 'column ' || c.column_name,
       c.data_type || CASE WHEN c.is_nullable = 'NO' THEN ' not null' ELSE '' END
       || COALESCE(' default ' || c.column_default, '')
FROM information_schema.columns c
WHERE c.table_schema = 'public' AND c.table_name = 'mens_health_screenings'

UNION ALL
-- every rule on the table (CHECKs show which words are allowed; FKs where patient_id points)
SELECT 3, 'constraint ' || con.conname, pg_get_constraintdef(con.oid)
FROM pg_constraint con
WHERE con.conrelid = to_regclass('public.mens_health_screenings')

UNION ALL
-- who may read and write
SELECT 4, 'policy ' || p.policyname,
       p.cmd || ' to ' || array_to_string(p.roles, ',') || ' using ' || COALESCE(p.qual, '-')
       || ' check ' || COALESCE(p.with_check, '-')
FROM pg_policies p
WHERE p.schemaname = 'public' AND p.tablename = 'mens_health_screenings'

UNION ALL
SELECT 5, 'row level security on',
       CASE WHEN c.relrowsecurity THEN 'yes' ELSE 'NO' END
FROM pg_class c
WHERE c.oid = to_regclass('public.mens_health_screenings')

UNION ALL
SELECT 6, 'trigger ' || tg.tgname, pg_get_triggerdef(tg.oid)
FROM pg_trigger tg
WHERE tg.tgrelid = to_regclass('public.mens_health_screenings') AND NOT tg.tgisinternal

UNION ALL
SELECT 7, 'grant ' || g.grantee, string_agg(g.privilege_type, ',' ORDER BY g.privilege_type)
FROM information_schema.role_table_grants g
WHERE g.table_schema = 'public' AND g.table_name = 'mens_health_screenings'
  AND g.grantee IN ('anon', 'authenticated')
GROUP BY g.grantee

UNION ALL
-- how many saved results of each tool and level (no personal details)
SELECT 8, 'rows ' || screening_type || ' / ' || risk_level, count(*)::text
FROM public.mens_health_screenings
GROUP BY screening_type, risk_level

UNION ALL
-- results saved by the broken tools: they hold heart-risk answers (7 numbers)
SELECT 9, 'wrong-question rows ' || screening_type,
       count(*)::text || ' rows, answers lengths: '
       || string_agg(DISTINCT CASE WHEN jsonb_typeof(responses::jsonb -> 'answers') = 'array'
                                 THEN jsonb_array_length(responses::jsonb -> 'answers')::text
                                 ELSE 'none' END, ',')
FROM public.mens_health_screenings
WHERE screening_type IN ('lifestyle', 'erectile', 'metabolic')
GROUP BY screening_type

UNION ALL
SELECT 10, 'total rows', count(*)::text FROM public.mens_health_screenings

ORDER BY n, what;
