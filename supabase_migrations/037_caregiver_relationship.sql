-- ================================================================
-- 037: Say who a caregiver is to the patient
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Needs 036_caregiver_access.sql
-- ================================================================
--
-- WHY
-- "Caregiver" covers very different people: a daughter, a spouse, a paid
-- carer, a nurse the family hired. Until now every caregiver looked the
-- same in both lists ("Wanjiru · view only"). The patient now says who
-- the person is when making the code, so the lists read
-- "Wanjiru · Child" and, on the caregiver's side, "you're their child".
--
-- THE RELATIONSHIP IS ONLY A LABEL
-- It never changes what the caregiver can see (that is access_level,
-- chosen separately) and it gives no authority to consent or decide for
-- the patient. A nurse treating the patient at a facility uses the
-- provider side, not a caregiver code; 'nurse' here means a nurse the
-- patient arranged privately.
--
-- WHAT IT DOES
-- * Adds caregiver_access.relationship (NULL for codes made before this).
-- * create_caregiver_code takes p_relationship. It defaults to NULL so an
--   app version from before this migration keeps working; the current
--   app always sends one.
-- * my_caregiver_grants() and people_i_care_for() return it.
-- ================================================================

BEGIN;

ALTER TABLE public.caregiver_access ADD COLUMN IF NOT EXISTS relationship TEXT;

ALTER TABLE public.caregiver_access DROP CONSTRAINT IF EXISTS caregiver_access_relationship_check;
ALTER TABLE public.caregiver_access ADD CONSTRAINT caregiver_access_relationship_check
  CHECK (relationship IS NULL OR relationship IN
         ('spouse', 'parent', 'child', 'sibling', 'relative', 'friend', 'paid_carer', 'nurse', 'other'));

-- ── Patient: create a code, now saying who it is for ────────────────
-- Same as 036 apart from the relationship. The one-argument version is
-- dropped so there is a single function to call.
DROP FUNCTION IF EXISTS public.create_caregiver_code(text);

CREATE OR REPLACE FUNCTION public.create_caregiver_code(p_level text, p_relationship text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes    bytea;
  v_code     text;
  v_id       text := gen_random_uuid()::text;
  v_expires  timestamptz := now() + interval '48 hours';
  v_pending  int;
  i          int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;
  IF p_level IS NULL OR p_level NOT IN ('full', 'medical_only', 'appointments_only', 'emergency_only') THEN
    RAISE EXCEPTION 'Choose what this code should open.';
  END IF;
  IF p_relationship IS NOT NULL AND p_relationship NOT IN
     ('spouse', 'parent', 'child', 'sibling', 'relative', 'friend', 'paid_carer', 'nurse', 'other') THEN
    RAISE EXCEPTION 'Choose who this person is to you.';
  END IF;

  SELECT count(*) INTO v_pending
  FROM   caregiver_access
  WHERE  granted_by_patient_id = v_uid
    AND  is_active AND redeemed_at IS NULL AND code_expires_at > now();
  IF v_pending >= 5 THEN
    RAISE EXCEPTION 'You already have 5 codes waiting to be used. Stop one before making another.';
  END IF;

  LOOP
    v_bytes := uuid_send(gen_random_uuid());
    v_code := '';
    -- Bytes 6 and 8 carry the uuid's version/variant bits; skip them.
    FOREACH i IN ARRAY ARRAY[0, 1, 2, 3, 4, 5, 9, 10] LOOP
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 31) + 1, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM caregiver_access WHERE access_code = v_code);
  END LOOP;

  INSERT INTO caregiver_access
    (id, caregiver_user_id, dependent_patient_id, access_code, access_level, relationship,
     is_active, granted_by_patient_id, granted_at, code_expires_at)
  VALUES
    (v_id, NULL, v_uid, v_code, p_level, p_relationship, true, v_uid, now(), v_expires);

  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('caregiver_code_created', v_uid, v_uid,
          jsonb_build_object('access_id', v_id, 'access_level', p_level,
                             'relationship', p_relationship), now());

  RETURN jsonb_build_object('id', v_id, 'access_code', v_code, 'access_level', p_level,
                            'relationship', p_relationship, 'code_expires_at', v_expires);
END;
$$;

-- ── Patient: list my codes (adds relationship) ──────────────────────
CREATE OR REPLACE FUNCTION public.my_caregiver_grants()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id',              ca.id,
             'access_code',     ca.access_code,
             'access_level',    ca.access_level,
             'relationship',    ca.relationship,
             'is_active',       ca.is_active,
             'granted_at',      ca.granted_at,
             'code_expires_at', ca.code_expires_at,
             'redeemed_at',     ca.redeemed_at,
             'caregiver_name',  u.full_name,
             'last_viewed_at',  (SELECT max(act.created_at) FROM caregiver_activity act
                                 WHERE act.access_id = ca.id AND act.activity_type = 'viewed')
           ) ORDER BY ca.granted_at DESC)
    FROM   caregiver_access ca
    LEFT   JOIN users u ON u.id = ca.caregiver_user_id
    WHERE  ca.granted_by_patient_id = auth.uid()
  ), '[]'::jsonb);
END;
$$;

-- ── Caregiver: who has shared with me (adds relationship) ───────────
CREATE OR REPLACE FUNCTION public.people_i_care_for()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'access_id',    ca.id,
             'patient_name', u.full_name,
             'medilink_id',  u.medilink_id,
             'access_level', ca.access_level,
             'relationship', ca.relationship,
             'redeemed_at',  ca.redeemed_at
           ) ORDER BY u.full_name)
    FROM   caregiver_access ca
    JOIN   users u ON u.id = ca.granted_by_patient_id
    WHERE  ca.caregiver_user_id = auth.uid()
      AND  ca.is_active
      AND  ca.redeemed_at IS NOT NULL
      AND  ca.dependent_patient_id = ca.granted_by_patient_id
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.create_caregiver_code(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_caregiver_code(text, text) TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect one row: create_caregiver_code | p_level text, p_relationship text DEFAULT NULL::text
SELECT proname, pg_get_function_arguments(oid) AS arguments
FROM   pg_proc
WHERE  pronamespace = 'public'::regnamespace AND proname = 'create_caregiver_code';

-- Expect one row: relationship | text
SELECT column_name, data_type
FROM   information_schema.columns
WHERE  table_schema = 'public' AND table_name = 'caregiver_access' AND column_name = 'relationship';
