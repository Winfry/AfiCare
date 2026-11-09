-- ================================================================
-- 056: Step 4d — privacy, children's medicines, honest reschedule
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run after 041 (provider_can_see_patient), 042 (is_self_or_my_dependant,
-- check_record_patient) and 052. Safe to run more than once.
--
-- Checked against checks/055_step4d_check.sql (run live 2026-11-09):
--   * users: users_select_staff lets EVERY doctor, nurse, radiologist,
--     CHW and facility admin read EVERY account, patients' phones and
--     emails included. users_select_consulted compares medilink_id with
--     consultations.patient_id (a uuid), so it never matches
--   * 0 staff accounts have a facility_id; facility admins are linked
--     through is_facility_admin_of(); CHWs find patients via care_team
--   * prescriptions / adherence_log: patient_id → users(id), and the
--     patient may only read / log her own, so a parent can't add or tick
--     off her child's medicines. Any signed-in person may insert a
--     prescription for ANY patient (only provider_id = auth.uid() checked)
--   * reschedule_appointment keeps "confirmed" when a patient moves it
--   * facilities_insert_anyone: WITH CHECK (true), so anyone, even signed
--     out, can add a facility already marked "verified"
--   * deleting costs / claims / receipts / their pictures / vaccination
--     records / disability profile: already allowed for the owner
--   * insurance_claims has facility_name and a 'paid' status; vaccine
--     names have no CHECK rule: nothing to change for those
--
-- WHY
--   A  Privacy     User's decision (2026-11-06): staff see a patient only
--                  when she is in their care (care team, appointment,
--                  consultation), registered at a facility they run, or
--                  opened by her exact MediLink ID. An exact-ID lookup is
--                  logged and opens her record to that clinician for 7
--                  days (find_patient_by_medilink). Staff accounts stay
--                  readable as now (patients need their doctors' names).
--   B  Children's  A parent can add, see and tick off her child's
--      medicines   medicines: prescriptions and adherence_log accept an
--                  account OR a dependant (042's check, like care_team),
--                  and the guardian may read and log them. Only clinicians
--                  may write a prescription for someone else.
--   C  Reschedule  A time moved by the patient goes back to "pending":
--                  the clinic hasn't agreed to it.
--   D  Facilities  The public "register your facility" form still works,
--                  but a new facility always starts "pending".
-- ================================================================

BEGIN;

-- ── A. Privacy: who may read a patient's account ────────────────

-- Exact-ID lookups by staff. Written only by find_patient_by_medilink().
CREATE TABLE IF NOT EXISTS public.staff_patient_lookups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  opened_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_patient_lookups
  ON public.staff_patient_lookups (staff_id, patient_id, opened_at DESC);
ALTER TABLE public.staff_patient_lookups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "staff_patient_lookups_own" ON public.staff_patient_lookups;
CREATE POLICY "staff_patient_lookups_own" ON public.staff_patient_lookups
  FOR SELECT TO authenticated USING (staff_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.staff_patient_lookups FROM anon, authenticated;

-- How long an exact-ID lookup keeps her record open to that person.
CREATE OR REPLACE FUNCTION public.staff_recently_opened(p_patient_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.staff_patient_lookups l
                 WHERE l.staff_id = auth.uid() AND l.patient_id = p_patient_id
                   AND l.opened_at > now() - interval '7 days');
$$;

-- 041's rule, plus a recent exact-ID lookup.
CREATE OR REPLACE FUNCTION public.provider_can_see_patient(p_patient_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT get_my_role() IN ('doctor', 'nurse') AND (
    EXISTS (SELECT 1 FROM public.care_team ct
            WHERE ct.provider_id = auth.uid() AND ct.patient_id = p_patient_id)
    OR EXISTS (SELECT 1 FROM public.appointments a
               WHERE a.provider_id = auth.uid() AND a.patient_id = p_patient_id
                 AND a.status <> 'cancelled')
    -- consultations.patient_id holds the MediLink ID on the live database
    -- (older rows may hold the account id), so both are accepted.
    OR EXISTS (SELECT 1 FROM public.consultations c
               JOIN public.users u ON u.id = p_patient_id
               WHERE c.provider_id::text = auth.uid()::text
                 AND c.patient_id::text IN (u.id::text, u.medilink_id))
    OR staff_recently_opened(p_patient_id)
  );
$$;

-- Find one patient by her exact MediLink ID. Staff only; logged in the
-- audit log and in staff_patient_lookups. Returns no phone or email.
CREATE OR REPLACE FUNCTION public.find_patient_by_medilink(p_medilink TEXT)
RETURNS TABLE (id UUID, full_name TEXT, medilink_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF get_my_role() NOT IN ('doctor', 'nurse', 'chw', 'radiologist', 'facility_admin') THEN
    RAISE EXCEPTION 'Only health workers can look up a patient';
  END IF;
  IF p_medilink IS NULL OR length(trim(p_medilink)) < 6 THEN
    RETURN;
  END IF;

  SELECT u.id INTO v_id
  FROM public.users u
  WHERE u.role = 'patient' AND upper(u.medilink_id) = upper(trim(p_medilink))
  LIMIT 1;
  IF v_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.staff_patient_lookups (staff_id, patient_id) VALUES (auth.uid(), v_id);
  INSERT INTO public.audit_log (action, user_id, patient_id, details, timestamp)
  VALUES ('patient_record_accessed', auth.uid(), v_id,
          jsonb_build_object('method', 'medilink_id'), now());

  RETURN QUERY SELECT u.id, u.full_name, u.medilink_id FROM public.users u WHERE u.id = v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.find_patient_by_medilink(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_patient_by_medilink(TEXT) TO authenticated;

DROP POLICY IF EXISTS "users_select_staff"     ON public.users;
DROP POLICY IF EXISTS "users_select_consulted" ON public.users;
DROP POLICY IF EXISTS "users_select_my_patients" ON public.users;
CREATE POLICY "users_select_my_patients" ON public.users
FOR SELECT TO authenticated
USING (
  role = 'patient'
  AND (
    provider_can_see_patient(id)
    -- CHWs and other staff: patients on their care team, or opened by ID
    OR (get_my_role() IN ('chw', 'radiologist', 'facility_admin') AND (
          EXISTS (SELECT 1 FROM public.care_team ct
                  WHERE ct.provider_id = auth.uid() AND ct.patient_id = users.id)
          OR staff_recently_opened(id)))
    -- facility admins: patients whose home facility they run
    OR (facility_id IS NOT NULL AND get_my_role() = 'facility_admin'
        AND is_facility_admin_of(facility_id))
  )
);

-- ── B. Children's medicines ─────────────────────────────────────
ALTER TABLE public.prescriptions DROP CONSTRAINT IF EXISTS prescriptions_patient_id_fkey;
ALTER TABLE public.adherence_log DROP CONSTRAINT IF EXISTS adherence_log_patient_id_fkey;

DROP TRIGGER IF EXISTS trg_check_prescriptions_patient ON public.prescriptions;
CREATE TRIGGER trg_check_prescriptions_patient
  BEFORE INSERT OR UPDATE OF patient_id ON public.prescriptions
  FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();

DROP TRIGGER IF EXISTS trg_check_adherence_log_patient ON public.adherence_log;
CREATE TRIGGER trg_check_adherence_log_patient
  BEFORE INSERT OR UPDATE OF patient_id ON public.adherence_log
  FOR EACH ROW EXECUTE FUNCTION public.check_record_patient();

-- The links that used to remove these with the account are gone, so the
-- clean-up trigger does it (for an account or a dependant). A dose goes
-- with its prescription (adherence_log.prescription_id cascades).
CREATE OR REPLACE FUNCTION public.delete_records_of_removed_patient()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.emergency_profiles   WHERE patient_id = OLD.id;
  DELETE FROM public.vaccination_records  WHERE patient_id = OLD.id;
  DELETE FROM public.care_team            WHERE patient_id = OLD.id;
  DELETE FROM public.medication_reminders WHERE patient_id = OLD.id;
  DELETE FROM public.disability_profiles  WHERE patient_id = OLD.id;
  DELETE FROM public.adherence_log        WHERE patient_id = OLD.id;
  DELETE FROM public.prescriptions        WHERE patient_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP POLICY IF EXISTS "Patients can view own prescriptions" ON public.prescriptions;
DROP POLICY IF EXISTS "prescriptions_select_self_or_dependant" ON public.prescriptions;
CREATE POLICY "prescriptions_select_self_or_dependant" ON public.prescriptions
  FOR SELECT TO authenticated USING (is_self_or_my_dependant(patient_id));

-- Writing a prescription: for yourself or your dependant (a medicine
-- you add yourself), or as a clinician.
DROP POLICY IF EXISTS "Providers can create prescriptions" ON public.prescriptions;
DROP POLICY IF EXISTS "prescriptions_insert" ON public.prescriptions;
CREATE POLICY "prescriptions_insert" ON public.prescriptions
  FOR INSERT TO authenticated
  WITH CHECK (
    provider_id = auth.uid()
    AND (is_self_or_my_dependant(patient_id) OR get_my_role() IN ('doctor', 'nurse'))
  );

DROP POLICY IF EXISTS "Patients can manage own adherence" ON public.adherence_log;
DROP POLICY IF EXISTS "adherence_log_self_or_dependant" ON public.adherence_log;
CREATE POLICY "adherence_log_self_or_dependant" ON public.adherence_log
  FOR ALL TO authenticated
  USING (is_self_or_my_dependant(patient_id))
  WITH CHECK (is_self_or_my_dependant(patient_id));

-- ── C. A time moved by the patient goes back to "pending" ───────
CREATE OR REPLACE FUNCTION public.reschedule_appointment(
  target_appointment_id UUID,
  new_scheduled_at TIMESTAMPTZ,
  new_provider_id UUID DEFAULT NULL,
  new_duration_minutes INT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_patient_id UUID;
  v_provider_id UUID;
  v_facility_id UUID;
  v_status TEXT;
  v_old_scheduled_at TIMESTAMPTZ;
  v_clinic_side BOOLEAN;
BEGIN
  SELECT patient_id, provider_id, facility_id, status, scheduled_at
    INTO v_patient_id, v_provider_id, v_facility_id, v_status, v_old_scheduled_at
  FROM public.appointments
  WHERE id = target_appointment_id;

  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  IF v_status IN ('cancelled', 'completed') THEN
    RAISE EXCEPTION 'Cannot reschedule a % appointment', v_status;
  END IF;

  v_clinic_side := get_my_role() = 'admin'
    OR (v_facility_id IS NOT NULL AND is_facility_admin_of(v_facility_id))
    OR v_provider_id = auth.uid();

  IF NOT (
    v_clinic_side
    OR (v_status IN ('pending', 'confirmed') AND (
          v_patient_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.dependent_profiles d
                     WHERE d.id = v_patient_id AND d.guardian_id = auth.uid())))
  ) THEN
    RAISE EXCEPTION 'Not authorized to reschedule this appointment';
  END IF;

  UPDATE public.appointments
  SET scheduled_at = new_scheduled_at,
      provider_id = COALESCE(new_provider_id, provider_id),
      duration_minutes = COALESCE(new_duration_minutes, duration_minutes),
      -- The clinic hasn't agreed to a time the patient picked.
      status = CASE WHEN v_clinic_side THEN status ELSE 'pending' END
  WHERE id = target_appointment_id;

  INSERT INTO public.audit_log (action, user_id, patient_id, details, timestamp)
  VALUES (
    'appointment_rescheduled',
    auth.uid(),
    v_patient_id,
    jsonb_build_object(
      'appointment_id', target_appointment_id,
      'facility_id', v_facility_id,
      'old_scheduled_at', v_old_scheduled_at,
      'new_scheduled_at', new_scheduled_at,
      'old_provider_id', v_provider_id,
      'new_provider_id', COALESCE(new_provider_id, v_provider_id),
      'old_status', v_status,
      'by_patient', NOT v_clinic_side
    ),
    now()
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.reschedule_appointment(UUID, TIMESTAMPTZ, UUID, INT) TO authenticated;

-- ── D. A new facility always starts "pending" ───────────────────
DROP POLICY IF EXISTS "facilities_insert_anyone"   ON public.facilities;
DROP POLICY IF EXISTS "facilities_insert_provider" ON public.facilities;
DROP POLICY IF EXISTS "facilities_insert_pending"  ON public.facilities;
CREATE POLICY "facilities_insert_pending" ON public.facilities
  FOR INSERT
  WITH CHECK (status = 'pending' OR get_my_role() = 'admin');

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'staff can no longer read every account' AS check_name,
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users'
                       AND policyname IN ('users_select_staff', 'users_select_consulted')) AS passed
  UNION ALL
  SELECT 2, 'patients readable only by their own staff (one rule)',
         EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users'
                   AND policyname = 'users_select_my_patients')
  UNION ALL
  SELECT 3, 'exact-ID lookup exists, for signed-in staff only',
         has_function_privilege('authenticated', 'public.find_patient_by_medilink(text)', 'EXECUTE')
         AND NOT has_function_privilege('anon', 'public.find_patient_by_medilink(text)', 'EXECUTE')
  UNION ALL
  SELECT 4, 'prescriptions and doses accept a dependant',
         NOT EXISTS (SELECT 1 FROM pg_constraint
                     WHERE conname IN ('prescriptions_patient_id_fkey', 'adherence_log_patient_id_fkey'))
         AND (SELECT COUNT(*) FROM information_schema.triggers
              WHERE trigger_name IN ('trg_check_prescriptions_patient', 'trg_check_adherence_log_patient')) >= 2
  UNION ALL
  SELECT 5, 'guardian may read prescriptions and log doses',
         (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public'
            AND policyname IN ('prescriptions_select_self_or_dependant', 'adherence_log_self_or_dependant',
                               'prescriptions_insert')) = 3
  UNION ALL
  SELECT 6, 'a patient-moved appointment goes back to pending',
         pg_get_functiondef('public.reschedule_appointment(uuid, timestamptz, uuid, int)'::regprocedure)
           LIKE '%ELSE ''pending''%'
  UNION ALL
  SELECT 7, 'new facilities start pending',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'facilities'
                       AND policyname IN ('facilities_insert_anyone', 'facilities_insert_provider'))
         AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'facilities'
                       AND policyname = 'facilities_insert_pending')
) t ORDER BY n;
