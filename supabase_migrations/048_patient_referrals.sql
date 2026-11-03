-- ================================================================
-- 048: Patients can see their referrals (and their dependants')
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 042 (it uses is_self_or_my_dependant). Safe to run more
-- than once.
--
-- WHY (from checks/048_precheck.sql, run live 2026-11-03)
-- The patient's Referrals page was always empty:
--   * a doctor's referral is saved under the patient's MediLink ID
--     (ML-NBO-… or ML-DEP-…), a CHW's under the account id;
--   * the page looked referrals up by account id only;
--   * the policies from 009 let a patient read only MediLink ones.
-- So neither kind could reach the patient. The table is empty today,
-- so nothing was lost; this fixes it before the first real referral.
--
-- WHAT
--   1. my_referrals(p_patient_id): the referrals of that person, saved
--      either way, with the referring clinician's name. Only for the
--      person themselves or the guardian of that dependant. The doctor's
--      private clinical notes for the receiving facility are left out.
--   2. Signed-out visitors lose all rights on referrals (row level
--      security already stopped them; this removes the rights too).
-- ================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.my_referrals(p_patient_id uuid)
RETURNS TABLE (
  id                 uuid,
  patient_id         text,
  from_provider_id   uuid,
  from_provider_name text,
  from_facility      text,
  to_facility        text,
  to_department      text,
  to_specialist      text,
  reason             text,
  urgency            text,
  status             text,
  created_at         timestamptz,
  responded_at       timestamptz,
  response_notes     text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_keys text[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;
  IF p_patient_id IS NULL OR NOT is_self_or_my_dependant(p_patient_id) THEN
    RAISE EXCEPTION 'You can only see your own referrals, or those of someone you look after.';
  END IF;

  -- Every way this person's referrals may have been saved.
  SELECT array_agg(DISTINCT upper(btrim(k))) INTO v_keys
  FROM (
    SELECT p_patient_id::text AS k
    UNION ALL
    SELECT u.medilink_id FROM users u WHERE u.id = p_patient_id AND u.medilink_id IS NOT NULL
    UNION ALL
    SELECT d.medilink_id FROM dependent_profiles d WHERE d.id = p_patient_id AND d.medilink_id IS NOT NULL
  ) keys
  WHERE btrim(k) <> '';

  RETURN QUERY
  SELECT r.id,
         r.patient_id,
         r.from_provider_id,
         nullif(btrim(pu.full_name), ''),
         r.from_facility,
         coalesce(nullif(btrim(r.to_facility), ''), 'Another facility'),
         r.to_department,
         r.to_specialist,
         coalesce(r.reason, ''),
         coalesce(r.urgency, 'routine'),
         coalesce(r.status, 'pending'),
         coalesce(r.created_at, now()),
         r.responded_at,
         r.response_notes
  FROM   referrals r
  LEFT JOIN users pu ON pu.id = r.from_provider_id
  WHERE  upper(btrim(r.patient_id)) = ANY (v_keys)
  ORDER  BY r.created_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.my_referrals(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_referrals(uuid) TO authenticated;

REVOKE ALL ON public.referrals FROM anon;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'my_referrals exists' AS check_name,
         EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'my_referrals'
                 AND pronamespace = 'public'::regnamespace) AS passed
  UNION ALL
  SELECT 2, 'signed-in people can use it',
         has_function_privilege('authenticated', 'public.my_referrals(uuid)', 'EXECUTE')
  UNION ALL
  SELECT 3, 'signed-out visitors cannot use it',
         NOT has_function_privilege('anon', 'public.my_referrals(uuid)', 'EXECUTE')
  UNION ALL
  SELECT 4, 'signed-out visitors have no rights on referrals',
         NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
                     WHERE table_schema = 'public' AND table_name = 'referrals' AND grantee = 'anon')
  UNION ALL
  SELECT 5, 'doctors, nurses and CHWs can still send referrals',
         EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'referrals'
                 AND policyname = 'provider_insert_referrals')
         AND has_table_privilege('authenticated', 'public.referrals', 'INSERT')
) checks
ORDER BY n;
