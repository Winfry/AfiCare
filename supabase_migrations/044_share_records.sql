-- ================================================================
-- 044: "Share my records" that really works, and really stays private
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run 042 first (it creates is_self_or_my_dependant and
-- check_record_patient). Safe to run more than once.
-- ================================================================
--
-- WHAT A SHARE IS
-- A patient (or a guardian, for their dependant) makes a short-lived
-- code and chooses what it opens: basic info, allergies, medicines,
-- medical history, vital signs, lab results. They show the code or its
-- QR to a doctor or nurse, who enters it in Patient access.
--   * Only doctors and nurses can open a code.
--   * The first doctor or nurse to open it keeps it until it expires;
--     to anyone else it is useless.
--   * They see ONLY the sections chosen. The database builds the view,
--     so the app cannot show more even if it tried.
--   * It stops at the time chosen (1 hour to 7 days) or the moment the
--     patient revokes it.
--   * The patient sees who opened it and when. Every opening is logged.
--   * Mental health is never part of a share.
--
-- WHY THIS MIGRATION (from the 044 pre-check, 2026-10-28)
-- 1. "Anyone can verify access codes" let ANY signed-in person, and the
--    signed-out key too, read every patient's codes, then open them.
-- 2. The app made 8-character codes; the doctor's screen only took 6,
--    so no code could ever be entered.
-- 3. The chosen sections were stored but never enforced: a code opened
--    the whole record.
-- 4. Codes were tied to accounts (foreign key to users), so a guardian
--    sharing a child's record shared their own instead.
-- 5. "Providers can view patient profiles with access" on users gave a
--    code holder the patient's whole account row (phone, email).
-- The table is empty on the live database, so nothing is lost.
--
-- WHAT IT DOES
-- * access_codes: patient may be an account or a dependant; adds
--   created_by, revoked_at, last_viewed_at, view_count; checks the code
--   format, the sections and the length of time.
-- * Read-only to the app (own and dependants' shares only). Every write
--   goes through the functions below:
--     create_record_share(patient, sections, hours)  patient makes a code
--     my_record_shares(patient)                      patient lists them
--     revoke_record_share(share)                     patient stops one
--     open_record_share(code)                        doctor/nurse opens it
-- ================================================================

BEGIN;

-- ── 1. The table ────────────────────────────────────────────────
-- Rows from the old app never opened anything and break the new checks.
DELETE FROM public.access_codes
WHERE  permissions IS NULL
   OR  NOT (permissions <@ ARRAY['basic_info', 'allergies', 'medications',
                                 'medical_history', 'vital_signs', 'lab_results']::text[])
   OR  code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$';

ALTER TABLE public.access_codes ADD COLUMN IF NOT EXISTS created_by     uuid;
ALTER TABLE public.access_codes ADD COLUMN IF NOT EXISTS revoked_at     timestamptz;
ALTER TABLE public.access_codes ADD COLUMN IF NOT EXISTS last_viewed_at timestamptz;
ALTER TABLE public.access_codes ADD COLUMN IF NOT EXISTS view_count     integer NOT NULL DEFAULT 0;

ALTER TABLE public.access_codes ALTER COLUMN permissions DROP DEFAULT;
ALTER TABLE public.access_codes ALTER COLUMN permissions SET NOT NULL;
ALTER TABLE public.access_codes ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE public.access_codes DROP CONSTRAINT IF EXISTS access_codes_sections_check;
ALTER TABLE public.access_codes ADD CONSTRAINT access_codes_sections_check CHECK (
  cardinality(permissions) > 0
  AND permissions <@ ARRAY['basic_info', 'allergies', 'medications',
                           'medical_history', 'vital_signs', 'lab_results']::text[]);

ALTER TABLE public.access_codes DROP CONSTRAINT IF EXISTS access_codes_code_format_check;
ALTER TABLE public.access_codes ADD CONSTRAINT access_codes_code_format_check
  CHECK (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$');

ALTER TABLE public.access_codes DROP CONSTRAINT IF EXISTS access_codes_length_check;
ALTER TABLE public.access_codes ADD CONSTRAINT access_codes_length_check
  CHECK (expires_at > created_at AND expires_at <= created_at + interval '7 days 5 minutes');

-- The patient may be an account or a dependant profile (as in 042).
ALTER TABLE public.access_codes DROP CONSTRAINT IF EXISTS access_codes_patient_id_fkey;
DROP TRIGGER IF EXISTS trg_check_access_codes_patient ON public.access_codes;
CREATE TRIGGER trg_check_access_codes_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.access_codes
FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();

-- Deleting a person deletes their shares, as the old foreign key did.
CREATE OR REPLACE FUNCTION public.delete_shares_of_removed_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.access_codes WHERE patient_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_delete_shares_of_removed_user ON public.users;
CREATE TRIGGER trg_delete_shares_of_removed_user
AFTER DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.delete_shares_of_removed_patient();

DROP TRIGGER IF EXISTS trg_delete_shares_of_removed_dependant ON public.dependent_profiles;
CREATE TRIGGER trg_delete_shares_of_removed_dependant
AFTER DELETE ON public.dependent_profiles
FOR EACH ROW EXECUTE FUNCTION public.delete_shares_of_removed_patient();

CREATE INDEX IF NOT EXISTS idx_access_codes_patient ON public.access_codes (patient_id, created_at DESC);

-- ── 2. Who may read it ──────────────────────────────────────────
-- Every old rule goes, whatever it was called.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies
           WHERE schemaname = 'public' AND tablename = 'access_codes' LOOP
    EXECUTE format('DROP POLICY %I ON public.access_codes', r.policyname);
  END LOOP;
END;
$$;

ALTER TABLE public.access_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "access_codes_select_own_or_dependant" ON public.access_codes
FOR SELECT TO authenticated
USING (is_self_or_my_dependant(patient_id));

REVOKE ALL ON public.access_codes FROM anon, authenticated;
GRANT SELECT ON public.access_codes TO authenticated;

-- A code no longer opens the patient's account row.
DROP POLICY IF EXISTS "Providers can view patient profiles with access" ON public.users;

-- ── 3. Patient: make a share ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_record_share(p_patient_id uuid, p_sections text[], p_hours integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_sections text[];
  v_bytes    bytea;
  v_code     text;
  v_expires  timestamptz;
  v_id       uuid;
  v_live     int;
  i          int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;
  IF p_patient_id IS NULL OR NOT is_self_or_my_dependant(p_patient_id) THEN
    RAISE EXCEPTION 'You can only share your own records or your dependant''s.';
  END IF;

  SELECT array_agg(DISTINCT s ORDER BY s) INTO v_sections
  FROM   unnest(coalesce(p_sections, '{}')) s;
  IF v_sections IS NULL THEN
    RAISE EXCEPTION 'Pick at least one thing to share.';
  END IF;
  IF NOT (v_sections <@ ARRAY['basic_info', 'allergies', 'medications',
                              'medical_history', 'vital_signs', 'lab_results']::text[]) THEN
    RAISE EXCEPTION 'One of the things picked can''t be shared.';
  END IF;
  IF p_hours IS NULL OR p_hours NOT IN (1, 4, 24, 72, 168) THEN
    RAISE EXCEPTION 'Choose how long the share should last.';
  END IF;

  SELECT count(*) INTO v_live
  FROM   access_codes
  WHERE  patient_id = p_patient_id AND revoked_at IS NULL AND expires_at > now();
  IF v_live >= 10 THEN
    RAISE EXCEPTION 'There are already 10 active shares. Revoke one before making another.';
  END IF;

  LOOP
    v_bytes := uuid_send(gen_random_uuid());
    v_code := '';
    -- Bytes 6 and 8 carry the uuid's version/variant bits; skip them.
    FOREACH i IN ARRAY ARRAY[0, 1, 2, 3, 4, 5, 9, 10] LOOP
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 31) + 1, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM access_codes WHERE code = v_code);
  END LOOP;

  v_expires := now() + make_interval(hours => p_hours);

  INSERT INTO access_codes (patient_id, code, expires_at, permissions, is_used, created_by, created_at)
  VALUES (p_patient_id, v_code, v_expires, v_sections, false, v_uid, now())
  RETURNING id INTO v_id;

  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('record_share_created', v_uid, p_patient_id,
          jsonb_build_object('share_id', v_id, 'sections', v_sections, 'hours', p_hours), now());

  RETURN jsonb_build_object('id', v_id, 'code', v_code, 'sections', v_sections,
                            'created_at', now(), 'expires_at', v_expires);
END;
$$;

-- ── 4. Patient: list shares, with who opened them ───────────────
-- A function because a patient may not read a doctor's users row, and
-- the name is the point.
CREATE OR REPLACE FUNCTION public.my_record_shares(p_patient_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_patient_id IS NULL OR NOT is_self_or_my_dependant(p_patient_id) THEN
    RETURN '[]'::jsonb;
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'id',             a.id,
             'code',           a.code,
             'sections',       to_jsonb(a.permissions),
             'created_at',     a.created_at,
             'expires_at',     a.expires_at,
             'revoked_at',     a.revoked_at,
             'opened_at',      a.used_at,
             'opened_by_name', u.full_name,
             'opened_by_role', u.role,
             'last_viewed_at', a.last_viewed_at,
             'view_count',     a.view_count
           ) ORDER BY a.created_at DESC)
    FROM   (SELECT * FROM access_codes
            WHERE  patient_id = p_patient_id
            ORDER  BY created_at DESC
            LIMIT  50) a
    LEFT   JOIN users u ON u.id = a.used_by
  ), '[]'::jsonb);
END;
$$;

-- ── 5. Patient: revoke a share ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.revoke_record_share(p_share_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_pid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  UPDATE access_codes
  SET    revoked_at = now()
  WHERE  id = p_share_id
    AND  revoked_at IS NULL
    AND  expires_at > now()
    AND  is_self_or_my_dependant(patient_id)
  RETURNING patient_id INTO v_pid;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('record_share_revoked', v_uid, v_pid, jsonb_build_object('share_id', p_share_id), now());
  RETURN true;
END;
$$;

-- ── 6. Doctor or nurse: open a share ────────────────────────────
CREATE OR REPLACE FUNCTION public.open_record_share(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_code      text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_row       access_codes%ROWTYPE;
  v_dep       dependent_profiles%ROWTYPE;
  v_is_dep    boolean;
  v_user      users%ROWTYPE;
  v_ep        jsonb;
  v_pt        jsonb;
  v_name      text;
  v_mlid      text;
  v_guardian  text;
  v_basic     jsonb;
  v_allergies jsonb;
  v_meds      jsonb;
  v_history   jsonb;
  v_vitals    jsonb;
  v_labs      jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first.';
  END IF;
  IF (SELECT get_my_role()) NOT IN ('doctor', 'nurse') THEN
    RAISE EXCEPTION 'Only doctors and nurses can open a shared record.';
  END IF;
  IF length(v_code) <> 8 THEN
    RAISE EXCEPTION 'A share code has 8 letters and numbers.';
  END IF;

  SELECT * INTO v_row FROM access_codes WHERE code = v_code FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No share has that code. Check it with the patient.';
  END IF;
  IF v_row.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'The patient has stopped this share.';
  END IF;
  IF v_row.expires_at <= now() THEN
    RAISE EXCEPTION 'This share has expired. Ask the patient for a new code.';
  END IF;
  IF v_row.used_by IS NOT NULL AND v_row.used_by <> v_uid THEN
    RAISE EXCEPTION 'Another health worker has already opened this share. Ask the patient for a new code.';
  END IF;

  -- The first doctor or nurse to open it keeps it.
  UPDATE access_codes
  SET    used_by        = v_uid,
         used_at        = coalesce(used_at, now()),
         is_used        = true,
         last_viewed_at = now(),
         view_count     = view_count + 1
  WHERE  id = v_row.id;

  INSERT INTO audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('record_share_opened', v_uid, v_row.patient_id,
          jsonb_build_object('share_id', v_row.id, 'sections', v_row.permissions), now());

  -- Whose record is it?
  SELECT * INTO v_dep FROM dependent_profiles WHERE id = v_row.patient_id;
  v_is_dep := FOUND;
  IF v_is_dep THEN
    v_name := v_dep.full_name;
    v_mlid := v_dep.medilink_id;
    SELECT full_name INTO v_guardian FROM users WHERE id = v_dep.guardian_id;
  ELSE
    SELECT * INTO v_user FROM users WHERE id = v_row.patient_id;
    v_name := v_user.full_name;
    v_mlid := v_user.medilink_id;
  END IF;

  SELECT to_jsonb(e) INTO v_ep FROM emergency_profiles e WHERE e.patient_id = v_row.patient_id LIMIT 1;
  IF v_is_dep THEN
    v_pt := to_jsonb(v_dep);
  ELSE
    SELECT to_jsonb(p) INTO v_pt FROM patients p WHERE p.id = v_row.patient_id;
  END IF;
  v_ep := coalesce(v_ep, '{}'::jsonb);
  v_pt := coalesce(v_pt, '{}'::jsonb);

  IF 'basic_info' = ANY (v_row.permissions) THEN
    v_basic := jsonb_build_object(
      'date_of_birth', v_pt->>'date_of_birth',
      'gender',        coalesce(nullif(v_pt->>'gender', ''), v_user.gender),
      'blood_type',    coalesce(nullif(v_ep->>'blood_type', ''), nullif(v_pt->>'blood_type', '')));
  END IF;

  IF 'allergies' = ANY (v_row.permissions) THEN
    v_allergies := CASE
      WHEN jsonb_typeof(v_ep->'allergies') = 'array' AND jsonb_array_length(v_ep->'allergies') > 0
        THEN v_ep->'allergies'
      WHEN jsonb_typeof(v_pt->'allergies') = 'array' THEN v_pt->'allergies'
      ELSE '[]'::jsonb END;
  END IF;

  IF 'medications' = ANY (v_row.permissions) THEN
    BEGIN
      SELECT jsonb_build_object(
               'prescribed', coalesce(jsonb_agg(x ORDER BY x->>'issued_at' DESC), '[]'::jsonb),
               'self_reported', CASE WHEN jsonb_typeof(v_ep->'current_medications') = 'array'
                                     THEN v_ep->'current_medications' ELSE '[]'::jsonb END)
      INTO v_meds
      FROM (
        SELECT jsonb_build_object(
                 'medication_name', pr.medication_name,
                 'dosage',          pr.dosage,
                 'frequency',       pr.frequency,
                 'duration',        pr.duration,
                 'instructions',    pr.instructions,
                 'issued_at',       pr.issued_at,
                 'provider_name',   u.full_name) AS x
        FROM   prescriptions pr
        LEFT   JOIN users u ON u.id = pr.provider_id
        WHERE  pr.patient_id = v_row.patient_id AND pr.status = 'active'
        ORDER  BY pr.issued_at DESC
        LIMIT  50
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'open_record_share: medications skipped: %', SQLERRM;
      v_meds := jsonb_build_object('prescribed', '[]'::jsonb, 'self_reported', '[]'::jsonb);
    END;
  END IF;

  IF 'medical_history' = ANY (v_row.permissions) THEN
    BEGIN
      v_history := jsonb_build_object(
        'conditions', CASE
          WHEN jsonb_typeof(v_ep->'chronic_conditions') = 'array' AND jsonb_array_length(v_ep->'chronic_conditions') > 0
            THEN v_ep->'chronic_conditions'
          WHEN jsonb_typeof(v_pt->'chronic_conditions') = 'array' THEN v_pt->'chronic_conditions'
          ELSE '[]'::jsonb END,
        'visits', (
          SELECT coalesce(jsonb_agg(x ORDER BY x->>'date' DESC), '[]'::jsonb) FROM (
            SELECT jsonb_build_object(
                     'date',            c.timestamp,
                     'chief_complaint', c.chief_complaint,
                     'diagnoses',       (SELECT coalesce(jsonb_agg(d->>'condition'), '[]'::jsonb)
                                         FROM jsonb_array_elements(
                                           CASE WHEN jsonb_typeof(c.diagnoses) = 'array'
                                                THEN c.diagnoses ELSE '[]'::jsonb END) d
                                         WHERE coalesce(d->>'condition', '') <> ''),
                     'provider_name',   u.full_name) AS x
            FROM   consultations c
            LEFT   JOIN users u ON u.id = c.provider_id
            WHERE  c.patient_id = v_row.patient_id
            ORDER  BY c.timestamp DESC
            LIMIT  10
          ) s),
        'vaccinations', (
          SELECT coalesce(jsonb_agg(x ORDER BY x->>'date_given' DESC), '[]'::jsonb) FROM (
            SELECT jsonb_build_object(
                     'vaccine_name', v.vaccine_name,
                     'date_given',   v.date_given,
                     'status',       v.status) AS x
            FROM   vaccination_records v
            WHERE  v.patient_id = v_row.patient_id
            ORDER  BY v.date_given DESC
            LIMIT  30
          ) s));
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'open_record_share: medical history skipped: %', SQLERRM;
      v_history := jsonb_build_object('conditions', '[]'::jsonb, 'visits', '[]'::jsonb, 'vaccinations', '[]'::jsonb);
    END;
  END IF;

  IF 'vital_signs' = ANY (v_row.permissions) THEN
    BEGIN
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'date' DESC), '[]'::jsonb) INTO v_vitals
      FROM (
        SELECT jsonb_build_object('date', c.timestamp, 'vital_signs', c.vital_signs) AS x
        FROM   consultations c
        WHERE  c.patient_id = v_row.patient_id
          AND  jsonb_typeof(c.vital_signs) = 'object'
          AND  c.vital_signs <> '{}'::jsonb
        ORDER  BY c.timestamp DESC
        LIMIT  5
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'open_record_share: vital signs skipped: %', SQLERRM;
      v_vitals := '[]'::jsonb;
    END;
  END IF;

  IF 'lab_results' = ANY (v_row.permissions) THEN
    BEGIN
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'ordered_at' DESC), '[]'::jsonb) INTO v_labs
      FROM (
        SELECT jsonb_build_object(
                 'test_name',  o.test_name,
                 'status',     o.status,
                 'ordered_at', o.ordered_at,
                 'result', (SELECT jsonb_build_object(
                                     'result_value',         r.result_value,
                                     'result_unit',          r.result_unit,
                                     'reference_range_low',  r.reference_range_low,
                                     'reference_range_high', r.reference_range_high,
                                     'result_flag',          r.result_flag,
                                     'resulted_at',          r.resulted_at)
                            FROM   lab_results r
                            WHERE  r.lab_order_id = o.id
                            ORDER  BY r.resulted_at DESC
                            LIMIT  1)) AS x
        FROM   lab_orders o
        WHERE  o.patient_id = v_row.patient_id
        ORDER  BY o.ordered_at DESC
        LIMIT  20
      ) s;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'open_record_share: lab results skipped: %', SQLERRM;
      v_labs := '[]'::jsonb;
    END;
  END IF;

  -- A section that was not shared comes back as null, never as empty,
  -- so the app can say "not shared" rather than "none".
  RETURN jsonb_build_object(
    'share_id',      v_row.id,
    'patient_id',    v_row.patient_id,
    'patient_name',  v_name,
    'medilink_id',   v_mlid,
    'is_dependant',  v_is_dep,
    'guardian_name', v_guardian,
    'relationship',  CASE WHEN v_is_dep THEN v_dep.relationship END,
    'sections',      to_jsonb(v_row.permissions),
    'shared_at',     v_row.created_at,
    'expires_at',    v_row.expires_at,
    'basic_info',    v_basic,
    'allergies',     v_allergies,
    'medications',   v_meds,
    'medical_history', v_history,
    'vital_signs',   v_vitals,
    'lab_results',   v_labs);
END;
$$;

REVOKE ALL ON FUNCTION public.create_record_share(uuid, text[], integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_record_shares(uuid)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revoke_record_share(uuid)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.open_record_share(text)                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_shares_of_removed_patient()         FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_record_share(uuid, text[], integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_record_shares(uuid)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_record_share(uuid)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_record_share(text)                    TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'nobody can read other people''s codes any more' AS check_name,
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'access_codes'
                     AND policyname = 'Anyone can verify access codes') AS passed
  UNION ALL
  SELECT 2, 'patients read only their own and their dependants'' shares',
         (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'access_codes') = 1
         AND EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'access_codes'
                     AND policyname = 'access_codes_select_own_or_dependant')
  UNION ALL
  SELECT 3, 'the app cannot write shares directly',
         NOT has_table_privilege('authenticated', 'public.access_codes', 'INSERT')
         AND NOT has_table_privilege('authenticated', 'public.access_codes', 'UPDATE')
         AND NOT has_table_privilege('authenticated', 'public.access_codes', 'DELETE')
         AND NOT has_table_privilege('anon', 'public.access_codes', 'SELECT')
  UNION ALL
  SELECT 4, 'a code no longer opens the patient''s account row',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users'
                     AND policyname = 'Providers can view patient profiles with access')
  UNION ALL
  SELECT 5, 'shares work for dependants',
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'access_codes_patient_id_fkey')
         AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_check_access_codes_patient')
  UNION ALL
  SELECT 6, 'only the six sections are allowed',
         EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'access_codes_sections_check')
  UNION ALL
  SELECT 7, 'the four share functions exist',
         (SELECT count(*) FROM pg_proc WHERE proname IN
            ('create_record_share', 'my_record_shares', 'revoke_record_share', 'open_record_share')) = 4
) checks
ORDER BY n;
