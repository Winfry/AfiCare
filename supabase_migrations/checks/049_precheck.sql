-- ================================================================
-- 049 pre-check: can a patient start a conversation with her doctor?
-- READ-ONLY. Changes nothing. Run in Supabase SQL Editor and send back
-- the whole result.
--
-- The patient's Messages page can only reply: "Message" on her care
-- team opens an empty inbox. Before building "start a conversation" we
-- need to know what the live messages table is and who it lets write
-- to whom. No message text is shown: counts only.
-- ================================================================

SELECT * FROM (
  -- 1. Does the table exist? Its columns and types
  SELECT 1 AS n, 'messages' AS item, 'table exists' AS check_name,
         CASE WHEN to_regclass('public.messages') IS NULL THEN 'NO' ELSE 'yes' END AS detail
  UNION ALL
  SELECT 1, column_name, 'column',
         data_type || CASE WHEN is_nullable = 'NO' THEN ' not null' ELSE '' END
         || CASE WHEN column_default IS NOT NULL THEN ' default ' || column_default ELSE '' END
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'messages'

  UNION ALL
  -- 2. Row level security, and every policy
  SELECT 2, 'messages', 'RLS', CASE WHEN relrowsecurity THEN 'on' ELSE 'OFF' END
  FROM pg_class WHERE oid = to_regclass('public.messages')
  UNION ALL
  SELECT 2, 'messages', 'policy: ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') ||
         ' | using: ' || coalesce(qual, '-') || ' | check: ' || coalesce(with_check, '-')
  FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages'

  UNION ALL
  -- 3. Grants
  SELECT 3, 'messages', 'grants to ' || grantee,
         string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND table_name = 'messages' AND grantee IN ('anon', 'authenticated')
  GROUP BY grantee

  UNION ALL
  -- 4. Constraints (foreign keys, checks)
  SELECT 4, 'messages', 'constraint: ' || conname, pg_get_constraintdef(oid)
  FROM pg_constraint WHERE conrelid = to_regclass('public.messages')

  UNION ALL
  -- 5. Triggers on the table
  SELECT 5, 'messages', 'trigger: ' || tgname, pg_get_triggerdef(oid)
  FROM pg_trigger WHERE tgrelid = to_regclass('public.messages') AND NOT tgisinternal

  UNION ALL
  -- 6. Is it in the realtime feed (for live new messages)?
  SELECT 6, 'messages', 'in realtime publication',
         CASE WHEN EXISTS (SELECT 1 FROM pg_publication_tables
                           WHERE pubname = 'supabase_realtime' AND tablename = 'messages')
              THEN 'yes' ELSE 'no' END

  UNION ALL
  -- 7. Helpers a fix could use
  SELECT 7, f, 'function exists',
         CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = f AND pronamespace = 'public'::regnamespace)
              THEN 'yes' ELSE 'no' END
  FROM unnest(ARRAY['provider_can_see_patient', 'is_self_or_my_dependant', 'get_my_role']) AS f
  UNION ALL
  SELECT 7, 'care_team', 'table exists',
         CASE WHEN to_regclass('public.care_team') IS NULL THEN 'NO' ELSE 'yes' END
) checks
ORDER BY n, item, check_name;

-- Counts of messages, by who sent to whom (roles only), if the table
-- exists. Run separately only if the result above says the table exists:
-- SELECT su.role AS sender_role, ru.role AS receiver_role, count(*)
-- FROM public.messages m
-- LEFT JOIN public.users su ON su.id = m.sender_id
-- LEFT JOIN public.users ru ON ru.id = m.receiver_id
-- GROUP BY 1, 2;
