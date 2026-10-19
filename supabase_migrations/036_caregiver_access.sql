-- ================================================================
-- 036: Make caregiver access work end to end
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Needs: users, patients, appointments, prescriptions, lab_orders,
--        lab_results, facilities, emergency_profiles, audit_log
-- ================================================================
--
-- WHAT A CAREGIVER IS
-- Someone with their own AfiCare account whom a patient trusts to follow
-- part of their care: an adult child helping a parent, a partner during
-- treatment. The patient owns the record and stays in control:
--   * the patient creates a one-time code and chooses what it opens;
--   * the caregiver enters the code in their own app within 48 hours;
--   * from then on the caregiver can LOOK (never change) at the chosen
--     sections until the patient stops it;
--   * mental health is never shared, whatever level is chosen.
-- This is different from a dependant (dependent_profiles), where the
-- guardian owns a profile for someone with no account of their own.
--
-- WHY THIS MIGRATION
-- 1. Every code the app tried to create failed: it inserted the text
--    'pending' into caregiver_user_id, a uuid column.
-- 2. The code was the clock in milliseconds mod 1,000,000, so anyone
--    could guess a code made at a known time.
-- 3. Nothing let a caregiver enter a code, and the only policy on the
--    table let a patient write any row they liked, including pointing a
--    grant at another person's record (dependent_patient_id was never
--    checked).
--
-- WHAT IT DOES
-- * caregiver_user_id becomes NULL until a code is redeemed; adds
--   redeemed_at and code_expires_at.
-- * Replaces every policy on caregiver_access / caregiver_activity with
--   read-only ones. All writes go through the functions below, which
--   check who is calling and what they are allowed to do.
-- * Functions (all SECURITY DEFINER, callable by signed-in users only):
--     create_caregiver_code(level)       patient makes a code
--     my_caregiver_grants()              patient lists their codes
--     revoke_caregiver_access(id)        patient stops one
--     redeem_caregiver_code(code)        caregiver enters a code
--     people_i_care_for()                caregiver lists who shared
--     caregiver_view(access_id)          caregiver reads the record
-- ================================================================

BEGIN;

-- ── 1. Tables (created here if remaining_tables.sql never ran) ──────
CREATE TABLE IF NOT EXISTS public.caregiver_access (
  id                    TEXT PRIMARY KEY,
  caregiver_user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  dependent_patient_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  access_code           TEXT NOT NULL UNIQUE,
  access_level          TEXT NOT NULL DEFAULT 'full'
                        CHECK (access_level IN ('full', 'medical_only', 'appointments_only', 'emergency_only')),
  is_active             BOOLEAN NOT NULL DEFAULT true,
  granted_by_patient_id UUID NOT NULL REFERENCES auth.users(id),
  granted_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at            TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.caregiver_activity (
  id            TEXT PRIMARY KEY,
  access_id     TEXT NOT NULL REFERENCES public.caregiver_access(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unredeemed codes used to hold the all-zeros uuid as a placeholder.
ALTER TABLE public.caregiver_access ALTER COLUMN caregiver_user_id DROP DEFAULT;
ALTER TABLE public.caregiver_access ALTER COLUMN caregiver_user_id DROP NOT NULL;
UPDATE public.caregiver_access
SET    caregiver_user_id = NULL
WHERE  caregiver_user_id = '00000000-0000-0000-0000-000000000000';

-- When the caregiver entered the code; NULL while it is still waiting.
ALTER TABLE public.caregiver_access ADD COLUMN IF NOT EXISTS redeemed_at TIMESTAMPTZ;
-- Last moment the code can be entered. Once entered, access lasts until
-- the patient stops it (is_active = false).
ALTER TABLE public.caregiver_access ADD COLUMN IF NOT EXISTS code_expires_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_caregiver_access_patient   ON public.caregiver_access (granted_by_patient_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_access_caregiver ON public.caregiver_access (caregiver_user_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_activity_access  ON public.caregiver_activity (access_id, created_at DESC);

ALTER TABLE public.caregiver_access   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caregiver_activity ENABLE ROW LEVEL SECURITY;

-- ── 2. Policies: read-only; writes only through the functions ───────
-- Every existing policy is dropped by looking them up, because the live
-- names may not match any migration.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname, tablename FROM pg_policies
    WHERE  schemaname = 'public' AND tablename IN ('caregiver_access', 'caregiver_activity')
  LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

CREATE POLICY "caregiver_access_select_own"
ON public.caregiver_access FOR SELECT
TO authenticated
USING (granted_by_patient_id = (SELECT auth.uid())
       OR caregiver_user_id = (SELECT auth.uid()));

CREATE POLICY "caregiver_activity_select_patient"
ON public.caregiver_activity FOR SELECT
TO authenticated
USING (access_id IN (SELECT id FROM public.caregiver_access
                     WHERE granted_by_patient_id = (SELECT auth.uid())));

-- ── 3. Patient: create a code ───────────────────────────────────────
-- Eight characters from an alphabet with no look-alikes (no 0/O, 1/I/L),
-- drawn from gen_random_uuid(), which is cryptographically random.
-- 31^8 ≈ 850 trillion possibilities, live for 48 hours at most.
CREATE OR REPLACE FUNCTION public.create_caregiver_code(p_level text)
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
    (id, caregiver_user_id, dependent_patient_id, access_code, access_level,
     is_active, granted_by_patient_id, granted_at, code_expires_at)
  VALUES
    (v_id, NULL, v_uid, v_code, p_level, true, v_uid, now(), v_expires);

  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('caregiver_code_created', v_uid, v_uid,
          jsonb_build_object('access_id', v_id, 'access_level', p_level), now());

  RETURN jsonb_build_object('id', v_id, 'access_code', v_code,
                            'access_level', p_level, 'code_expires_at', v_expires);
END;
$$;

-- ── 4. Patient: list my codes, with the caregiver's name ────────────
-- A function rather than a plain select because a patient may not read
-- another patient's users row (034), and the name is the point.
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

-- ── 5. Patient: stop a code or an active caregiver ──────────────────
CREATE OR REPLACE FUNCTION public.revoke_caregiver_access(p_access_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  UPDATE caregiver_access
  SET    is_active = false
  WHERE  id = p_access_id AND granted_by_patient_id = v_uid AND is_active;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  INSERT INTO caregiver_activity (id, access_id, activity_type, description, created_at)
  VALUES (gen_random_uuid()::text, p_access_id, 'revoked', 'Stopped by the patient', now());
  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('caregiver_access_revoked', v_uid, v_uid,
          jsonb_build_object('access_id', p_access_id), now());
  RETURN true;
END;
$$;

-- ── 6. Caregiver: enter a code ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.redeem_caregiver_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_row  caregiver_access%ROWTYPE;
  v_name text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;
  IF length(v_code) <> 8 THEN
    RAISE EXCEPTION 'Codes are 8 letters and numbers. Check it and try again.';
  END IF;

  SELECT * INTO v_row FROM caregiver_access WHERE access_code = v_code FOR UPDATE;

  -- Unknown and stopped codes get the same answer, so a guess learns
  -- nothing about which codes exist.
  IF NOT FOUND OR NOT v_row.is_active THEN
    RAISE EXCEPTION 'That code isn''t valid. Check it with the person who gave it to you.';
  END IF;
  IF v_row.redeemed_at IS NOT NULL THEN
    RAISE EXCEPTION 'That code has already been used. Ask for a new one.';
  END IF;
  IF v_row.code_expires_at IS NULL OR v_row.code_expires_at <= now() THEN
    RAISE EXCEPTION 'That code has expired. Codes last 48 hours, so ask for a new one.';
  END IF;
  IF v_row.granted_by_patient_id = v_uid THEN
    RAISE EXCEPTION 'This is your own code. Give it to the person you want to share with.';
  END IF;
  IF EXISTS (SELECT 1 FROM caregiver_access
             WHERE  caregiver_user_id = v_uid
               AND  granted_by_patient_id = v_row.granted_by_patient_id
               AND  is_active) THEN
    RAISE EXCEPTION 'You can already see this person''s record. They can stop the old access and give you a new code if they want to change it.';
  END IF;

  UPDATE caregiver_access
  SET    caregiver_user_id = v_uid, redeemed_at = now()
  WHERE  id = v_row.id;

  INSERT INTO caregiver_activity (id, access_id, activity_type, description, created_at)
  VALUES (gen_random_uuid()::text, v_row.id, 'redeemed', 'Code entered', now());
  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('caregiver_code_redeemed', v_uid, v_row.granted_by_patient_id,
          jsonb_build_object('access_id', v_row.id, 'access_level', v_row.access_level), now());

  SELECT full_name INTO v_name FROM users WHERE id = v_row.granted_by_patient_id;
  RETURN jsonb_build_object('access_id', v_row.id, 'patient_name', v_name,
                            'access_level', v_row.access_level);
END;
$$;

-- ── 7. Caregiver: who has shared with me ────────────────────────────
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

-- ── 8. Caregiver: read the shared record ────────────────────────────
-- Returns only the sections the access level allows:
--   full               emergency, appointments, medicines, lab results
--   medical_only       emergency, medicines, lab results
--   appointments_only  appointments
--   emergency_only     emergency
-- Mental health is never read here, at any level. Appointments leave out
-- the reason for the visit and notes, which can reveal more than a
-- caregiver was given. A section whose table is missing or different in
-- this database comes back null (with a warning in the logs) rather than
-- failing the whole page.
CREATE OR REPLACE FUNCTION public.caregiver_view(p_access_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_row       caregiver_access%ROWTYPE;
  v_pid       uuid;
  v_ep        jsonb;
  v_pt        jsonb;
  v_emergency jsonb;
  v_appts     jsonb;
  v_meds      jsonb;
  v_labs      jsonb;
  v_name      text;
  v_mlid      text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;

  SELECT * INTO v_row FROM caregiver_access
  WHERE  id = p_access_id
    AND  caregiver_user_id = v_uid
    AND  is_active
    AND  redeemed_at IS NOT NULL
    AND  dependent_patient_id = granted_by_patient_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'You no longer have access to this record.';
  END IF;
  v_pid := v_row.granted_by_patient_id;

  SELECT full_name, medilink_id INTO v_name, v_mlid FROM users WHERE id = v_pid;

  -- Emergency details: the patient's emergency profile first, their main
  -- profile where that is blank.
  IF v_row.access_level IN ('full', 'medical_only', 'emergency_only') THEN
    BEGIN
      SELECT to_jsonb(e) INTO v_ep FROM emergency_profiles e WHERE e.patient_id = v_pid LIMIT 1;
    EXCEPTION WHEN OTHERS THEN v_ep := NULL;
    END;
    BEGIN
      SELECT to_jsonb(p) INTO v_pt FROM patients p WHERE p.id = v_pid;
    EXCEPTION WHEN OTHERS THEN v_pt := NULL;
    END;
    v_ep := coalesce(v_ep, '{}'::jsonb);
    v_pt := coalesce(v_pt, '{}'::jsonb);

    v_emergency := jsonb_build_object(
      'blood_type', coalesce(nullif(v_ep->>'blood_type', ''), nullif(v_pt->>'blood_type', '')),
      'allergies',
        CASE WHEN jsonb_typeof(v_ep->'allergies') = 'array' AND jsonb_array_length(v_ep->'allergies') > 0
               THEN v_ep->'allergies'
             WHEN jsonb_typeof(v_pt->'allergies') = 'array' THEN v_pt->'allergies'
             ELSE '[]'::jsonb END,
      'conditions',
        CASE WHEN jsonb_typeof(v_ep->'chronic_conditions') = 'array' AND jsonb_array_length(v_ep->'chronic_conditions') > 0
               THEN v_ep->'chronic_conditions'
             WHEN jsonb_typeof(v_ep->'medical_conditions') = 'array' AND jsonb_array_length(v_ep->'medical_conditions') > 0
               THEN v_ep->'medical_conditions'
             WHEN jsonb_typeof(v_pt->'chronic_conditions') = 'array' THEN v_pt->'chronic_conditions'
             ELSE '[]'::jsonb END,
      'contacts', (
        SELECT coalesce(jsonb_agg(c), '[]'::jsonb) FROM (
          SELECT jsonb_build_object('name', v_ep->>'emergency_contact_name',
                                    'phone', v_ep->>'emergency_contact_phone',
                                    'relationship', v_ep->>'emergency_contact_relationship') AS c
          WHERE  coalesce(v_ep->>'emergency_contact_phone', '') <> ''
          UNION ALL
          SELECT jsonb_build_object('name', v_ep->>'emergency_contact2_name',
                                    'phone', v_ep->>'emergency_contact2_phone',
                                    'relationship', v_ep->>'emergency_contact2_relationship')
          WHERE  coalesce(v_ep->>'emergency_contact2_phone', '') <> ''
          UNION ALL
          SELECT jsonb_build_object('name', v_pt->>'emergency_contact_name',
                                    'phone', v_pt->>'emergency_contact_phone',
                                    'relationship', NULL)
          WHERE  coalesce(v_ep->>'emergency_contact_phone', '') = ''
            AND  coalesce(v_pt->>'emergency_contact_phone', '') <> ''
        ) s
      ),
      'notes', nullif(v_ep->>'notes', '')
    );
  END IF;

  -- Appointments from a week ago onwards, soonest first.
  IF v_row.access_level IN ('full', 'appointments_only') THEN
    BEGIN
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'scheduled_at'), '[]'::jsonb) INTO v_appts
      FROM (
        SELECT jsonb_build_object(
                 'id',            a.id,
                 'scheduled_at',  a.scheduled_at,
                 'status',        a.status,
                 'type',          a.type,
                 'provider_name', u.full_name,
                 'facility_name', f.name) AS x
        FROM   appointments a
        LEFT   JOIN users u      ON u.id = a.provider_id
        LEFT   JOIN facilities f ON f.id = a.facility_id
        WHERE  a.patient_id = v_pid
          AND  a.scheduled_at >= now() - interval '7 days'
        ORDER  BY a.scheduled_at
        LIMIT  30
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'caregiver_view: % section skipped: %', 'v_appts', SQLERRM;
      v_appts := NULL;
    END;
  END IF;

  IF v_row.access_level IN ('full', 'medical_only') THEN
    -- Medicines currently prescribed.
    BEGIN
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'issued_at' DESC), '[]'::jsonb) INTO v_meds
      FROM (
        SELECT jsonb_build_object(
                 'id',              pr.id,
                 'medication_name', pr.medication_name,
                 'dosage',          pr.dosage,
                 'frequency',       pr.frequency,
                 'duration',        pr.duration,
                 'instructions',    pr.instructions,
                 'issued_at',       pr.issued_at,
                 'provider_name',   u.full_name) AS x
        FROM   prescriptions pr
        LEFT   JOIN users u ON u.id = pr.provider_id
        WHERE  pr.patient_id = v_pid AND pr.status = 'active'
        ORDER  BY pr.issued_at DESC
        LIMIT  50
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'caregiver_view: % section skipped: %', 'v_meds', SQLERRM;
      v_meds := NULL;
    END;

    -- The 20 most recent lab tests, each with its result if there is one.
    BEGIN
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'ordered_at' DESC), '[]'::jsonb) INTO v_labs
      FROM (
        SELECT jsonb_build_object(
                 'id',          o.id,
                 'test_name',   o.test_name,
                 'status',      o.status,
                 'ordered_at',  o.ordered_at,
                 'result', (SELECT jsonb_build_object(
                                     'result_value',        r.result_value,
                                     'result_unit',         r.result_unit,
                                     'reference_range_low', r.reference_range_low,
                                     'reference_range_high', r.reference_range_high,
                                     'result_flag',         r.result_flag,
                                     'resulted_at',         r.resulted_at)
                            FROM   lab_results r
                            WHERE  r.lab_order_id = o.id
                            ORDER  BY r.resulted_at DESC
                            LIMIT  1)) AS x
        FROM   lab_orders o
        WHERE  o.patient_id = v_pid
        ORDER  BY o.ordered_at DESC
        LIMIT  20
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'caregiver_view: % section skipped: %', 'v_labs', SQLERRM;
      v_labs := NULL;
    END;
  END IF;

  -- Record the look, at most once an hour, so the patient can see when
  -- their record was last opened without the log filling up.
  IF NOT EXISTS (SELECT 1 FROM caregiver_activity
                 WHERE  access_id = v_row.id AND activity_type = 'viewed'
                   AND  created_at > now() - interval '1 hour') THEN
    INSERT INTO caregiver_activity (id, access_id, activity_type, description, created_at)
    VALUES (gen_random_uuid()::text, v_row.id, 'viewed', 'Opened the shared record', now());
  END IF;

  RETURN jsonb_build_object(
    'access_id',    v_row.id,
    'access_level', v_row.access_level,
    'patient_name', v_name,
    'medilink_id',  v_mlid,
    'since',        v_row.redeemed_at,
    'emergency',    v_emergency,
    'appointments', v_appts,
    'medicines',    v_meds,
    'lab_orders',   v_labs
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_caregiver_code(text)   FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_caregiver_grants()         FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_caregiver_access(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.redeem_caregiver_code(text)   FROM PUBLIC;
REVOKE ALL ON FUNCTION public.people_i_care_for()           FROM PUBLIC;
REVOKE ALL ON FUNCTION public.caregiver_view(text)          FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_caregiver_code(text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_caregiver_grants()         TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_caregiver_access(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_caregiver_code(text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.people_i_care_for()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.caregiver_view(text)          TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect two policies: caregiver_access_select_own (SELECT) and
-- caregiver_activity_select_patient (SELECT).
SELECT tablename, policyname, cmd
FROM   pg_policies
WHERE  schemaname = 'public' AND tablename IN ('caregiver_access', 'caregiver_activity')
ORDER  BY tablename, policyname;

-- Expect six functions.
SELECT proname
FROM   pg_proc
WHERE  pronamespace = 'public'::regnamespace
  AND  proname IN ('create_caregiver_code', 'my_caregiver_grants', 'revoke_caregiver_access',
                   'redeem_caregiver_code', 'people_i_care_for', 'caregiver_view')
ORDER  BY proname;
