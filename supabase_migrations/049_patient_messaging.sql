-- ================================================================
-- 049: Patients can start a conversation with their clinicians,
--      and only with them
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 041 and 042. Safe to run more than once.
--
-- WHY (from checks/049_precheck.sql, run live 2026-11-03)
-- The app is gaining "Message your doctor" (from Care team, Appointments
-- and a New message button). The live table would let that work, but:
--   * "Users can send messages" only checks that you are the sender, so
--     a patient could message ANYONE, including other patients;
--   * the receiver of a message could change its text, not just mark it
--     read (the update rule covers every column);
--   * patient_id ("which patient this is about") must be an account, so
--     a parent could not write about her child (a dependant profile);
--   * signed-out visitors held every right on the table (row level
--     security stopped them; the rights go too).
--
-- WHAT
--   1. message_contacts(): the clinicians a patient may write to, with
--      who they care for: her care team and her children's, and anyone
--      she has an appointment or consultation with (cancelled
--      appointments do not count), plus anyone who has written to her.
--   2. A patient may only send to those people. Staff are not changed.
--   3. A receiver can only mark a message read.
--   4. patient_id may be an account or a dependant profile; a patient
--      may only say a message is about herself or her own dependant.
-- ================================================================

BEGIN;

-- ── 1. Who a patient may write to ───────────────────────────────
-- Everyone the signed-in patient may message, once each, with the
-- names of the people (her and her dependants) they look after.
CREATE OR REPLACE FUNCTION public.message_contacts()
RETURNS TABLE (
  user_id      uuid,
  full_name    text,
  role         text,
  photo_url    text,
  gender       text,
  cares_for    uuid[],
  cares_for_names text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;

  RETURN QUERY
  WITH people AS (            -- her and her dependants, with every id they go by
    SELECT u.id AS pid, coalesce(nullif(btrim(u.full_name), ''), 'You') AS pname,
           ARRAY[u.id::text, coalesce(u.medilink_id, '')] AS keys, 0 AS ord
    FROM users u WHERE u.id = v_me
    UNION ALL
    SELECT d.id, coalesce(nullif(btrim(d.full_name), ''), 'Your dependant'),
           ARRAY[d.id::text, coalesce(d.medilink_id, '')], 1
    FROM dependent_profiles d WHERE d.guardian_id = v_me
  ),
  links AS (
    SELECT ct.provider_id::text AS staff, p.pid, p.pname, p.ord
    FROM care_team ct JOIN people p ON ct.patient_id = p.pid
    UNION
    SELECT a.provider_id::text, p.pid, p.pname, p.ord
    FROM appointments a JOIN people p ON a.patient_id = p.pid
    WHERE a.provider_id IS NOT NULL AND coalesce(a.status, '') <> 'cancelled'
    UNION
    SELECT c.provider_id::text, p.pid, p.pname, p.ord
    FROM consultations c JOIN people p ON c.patient_id::text = ANY (p.keys)
    WHERE c.provider_id IS NOT NULL
    UNION
    SELECT m.sender_id::text, v_me, NULL::text, 2      -- wrote to her first
    FROM messages m WHERE m.receiver_id = v_me
  )
  SELECT s.id,
         coalesce(nullif(btrim(s.full_name), ''), 'Your clinician'),
         s.role,
         s.photo_url,
         s.gender,
         array_agg(DISTINCT l.pid) FILTER (WHERE l.pname IS NOT NULL),
         array_agg(DISTINCT l.pname) FILTER (WHERE l.pname IS NOT NULL)
  FROM links l
  JOIN users s ON s.id::text = l.staff
  WHERE s.id <> v_me AND coalesce(s.role, 'patient') <> 'patient'
  GROUP BY s.id, s.full_name, s.role, s.photo_url, s.gender
  ORDER BY coalesce(nullif(btrim(s.full_name), ''), 'Your clinician');
END;
$$;

REVOKE ALL ON FUNCTION public.message_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.message_contacts() TO authenticated;

CREATE OR REPLACE FUNCTION public.patient_can_message(p_to uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM message_contacts() c WHERE c.user_id = p_to);
$$;

REVOKE ALL ON FUNCTION public.patient_can_message(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.patient_can_message(uuid) TO authenticated;

-- ── 2 & 3. The rules on messages ────────────────────────────────
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
DROP POLICY IF EXISTS "messages_send" ON public.messages;
CREATE POLICY "messages_send" ON public.messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND (coalesce(get_my_role(), 'patient') <> 'patient' OR patient_can_message(receiver_id))
);

DROP POLICY IF EXISTS "Users can mark messages as read" ON public.messages;
DROP POLICY IF EXISTS "messages_mark_read" ON public.messages;
CREATE POLICY "messages_mark_read" ON public.messages
FOR UPDATE TO authenticated
USING (receiver_id = auth.uid())
WITH CHECK (receiver_id = auth.uid());

-- Reading is unchanged: you see what you sent or received.
DROP POLICY IF EXISTS "Users can view their messages" ON public.messages;
DROP POLICY IF EXISTS "messages_read_own" ON public.messages;
CREATE POLICY "messages_read_own" ON public.messages
FOR SELECT TO authenticated
USING (sender_id = auth.uid() OR receiver_id = auth.uid());

REVOKE ALL ON public.messages FROM anon, authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;
GRANT UPDATE (read, read_at) ON public.messages TO authenticated;

-- ── 4. "About whom": an account or a dependant ──────────────────
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_patient_id_fkey;

CREATE OR REPLACE FUNCTION public.check_message_about()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.patient_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.patient_id)
     AND NOT EXISTS (SELECT 1 FROM dependent_profiles WHERE id = NEW.patient_id) THEN
    RAISE EXCEPTION 'A message can only be about an AfiCare account or a dependant profile';
  END IF;
  -- A patient may only say a message is about herself or her dependant.
  IF coalesce((SELECT role FROM users WHERE id = NEW.sender_id), 'patient') = 'patient'
     AND NEW.patient_id <> NEW.sender_id
     AND NOT EXISTS (SELECT 1 FROM dependent_profiles
                     WHERE id = NEW.patient_id AND guardian_id = NEW.sender_id) THEN
    RAISE EXCEPTION 'You can only write about yourself or someone you look after';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_message_about ON public.messages;
CREATE TRIGGER trg_check_message_about
BEFORE INSERT OR UPDATE OF patient_id ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.check_message_about();

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'message_contacts exists, signed-in only' AS check_name,
         has_function_privilege('authenticated', 'public.message_contacts()', 'EXECUTE')
         AND NOT has_function_privilege('anon', 'public.message_contacts()', 'EXECUTE') AS passed
  UNION ALL
  SELECT 2, 'patients can only write to their clinicians',
         EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages'
                 AND policyname = 'messages_send' AND with_check ILIKE '%patient_can_message%')
         AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages'
                         AND policyname = 'Users can send messages')
  UNION ALL
  SELECT 3, 'a receiver can only mark a message read',
         has_column_privilege('authenticated', 'public.messages', 'read', 'UPDATE')
         AND NOT has_column_privilege('authenticated', 'public.messages', 'content', 'UPDATE')
  UNION ALL
  SELECT 4, 'everyone still sees only their own messages',
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages'
          AND cmd = 'SELECT') = 1
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'messages'
                     AND policyname = 'messages_read_own')
  UNION ALL
  SELECT 5, 'a message can be about a child on a parent''s account',
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'messages_patient_id_fkey')
         AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_check_message_about'
                     AND tgrelid = 'public.messages'::regclass)
  UNION ALL
  SELECT 6, 'signed-out visitors have no rights on messages',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND table_name = 'messages' AND grantee = 'anon')
) checks
ORDER BY n;
