-- ================================================================
-- 035: Make triage_queue's policies check the user's AfiCare role
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Needs get_my_role() from 010_role_escalation_fix.sql
-- ================================================================
--
-- WHY
-- The three live policies on triage_queue (from aficare_flutter/supabase/
-- schema.sql) test  auth.role() IN ('doctor', 'nurse').  auth.role() is
-- the Postgres role of the request, which is always 'anon' or
-- 'authenticated', never an AfiCare role. So the test is never true:
-- nobody can read, add or update the queue, and the staff notifications
-- screen's "waiting in triage" list is always empty. Nothing was exposed;
-- the feature simply could not work.
--
-- get_my_role() reads the signed-in user's role from public.users, which
-- is what these policies meant. Patients may also read their own entries.
-- ================================================================

BEGIN;

DROP POLICY IF EXISTS "Providers can view triage queue" ON public.triage_queue;
DROP POLICY IF EXISTS "Triage queue insert" ON public.triage_queue;
DROP POLICY IF EXISTS "Triage queue update" ON public.triage_queue;

CREATE POLICY "triage_queue_select_staff"
ON public.triage_queue FOR SELECT
TO authenticated
USING ((SELECT get_my_role()) IN ('doctor', 'nurse', 'facility_admin'));

CREATE POLICY "triage_queue_select_own"
ON public.triage_queue FOR SELECT
TO authenticated
USING (patient_id = (SELECT auth.uid()));

CREATE POLICY "triage_queue_insert_staff"
ON public.triage_queue FOR INSERT
TO authenticated
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse'));

CREATE POLICY "triage_queue_update_staff"
ON public.triage_queue FOR UPDATE
TO authenticated
USING ((SELECT get_my_role()) IN ('doctor', 'nurse'))
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse'));

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect exactly four rows, all starting with triage_queue_.
SELECT policyname, cmd, roles
FROM   pg_policies
WHERE  schemaname = 'public' AND tablename = 'triage_queue'
ORDER  BY policyname;
