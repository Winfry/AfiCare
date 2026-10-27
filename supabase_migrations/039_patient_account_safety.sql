-- ================================================================
-- 039: Patient account safety: phone changes, and cancelling or moving
--      a dependant's appointment
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
-- ================================================================
--
-- WHY
-- 1. A PIN patient's Supabase password is derived from phone + PIN, and
--    login finds them by phone (patient-auth Edge Function). Editing
--    users.phone straight from the app therefore locked the patient out
--    for good: the new phone found the account, but the password no
--    longer matched. Phone changes for PIN accounts now go only through
--    the Edge Function's change_phone action, which re-derives the
--    password in the same step. This trigger refuses any other change,
--    so an old app build can't lock someone out either.
-- 2. reschedule_appointment / cancel_appointment (015) only let the
--    patient themselves act. A parent cancelling their child's
--    appointment (a dependant has no account) was refused, and the app
--    still said "Appointment cancelled". The guardian may now do what
--    the patient could: cancel or move a pending or confirmed visit.
-- ================================================================

BEGIN;

-- ── 1. Phone of a PIN account changes only through patient-auth ──
CREATE OR REPLACE FUNCTION public.protect_pin_login_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone
     AND coalesce(auth.role(), '') IN ('authenticated', 'anon')
     AND EXISTS (SELECT 1 FROM public.patient_credentials WHERE user_id = OLD.id) THEN
    RAISE EXCEPTION 'Change your phone number from your profile, with your PIN'
      USING HINT = 'patient-auth change_phone';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_pin_login_phone ON public.users;
CREATE TRIGGER trg_protect_pin_login_phone
BEFORE UPDATE OF phone ON public.users
FOR EACH ROW EXECUTE FUNCTION public.protect_pin_login_phone();

-- ── 2. Guardians may cancel or move a dependant's appointment ───
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

  IF NOT (
    get_my_role() = 'admin'
    OR (v_facility_id IS NOT NULL AND is_facility_admin_of(v_facility_id))
    OR v_provider_id = auth.uid()
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
      duration_minutes = COALESCE(new_duration_minutes, duration_minutes)
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
      'new_provider_id', COALESCE(new_provider_id, v_provider_id)
    ),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_appointment(
  target_appointment_id UUID,
  reason TEXT DEFAULT NULL
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
BEGIN
  SELECT patient_id, provider_id, facility_id, status
    INTO v_patient_id, v_provider_id, v_facility_id, v_status
  FROM public.appointments
  WHERE id = target_appointment_id;

  IF v_patient_id IS NULL THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'Appointment is already cancelled';
  END IF;

  IF v_status = 'completed' THEN
    RAISE EXCEPTION 'Cannot cancel a completed appointment';
  END IF;

  IF NOT (
    get_my_role() = 'admin'
    OR (v_facility_id IS NOT NULL AND is_facility_admin_of(v_facility_id))
    OR v_provider_id = auth.uid()
    OR (v_status IN ('pending', 'confirmed') AND (
          v_patient_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.dependent_profiles d
                     WHERE d.id = v_patient_id AND d.guardian_id = auth.uid())))
  ) THEN
    RAISE EXCEPTION 'Not authorized to cancel this appointment';
  END IF;

  UPDATE public.appointments
  SET status = 'cancelled', cancelled_reason = reason
  WHERE id = target_appointment_id;

  INSERT INTO public.audit_log (action, user_id, patient_id, details, timestamp)
  VALUES (
    'appointment_cancelled',
    auth.uid(),
    v_patient_id,
    jsonb_build_object(
      'appointment_id', target_appointment_id,
      'facility_id', v_facility_id,
      'old_status', v_status,
      'reason', reason
    ),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reschedule_appointment(UUID, TIMESTAMPTZ, UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_appointment(UUID, TEXT) TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect: one 'trigger' row (trg_protect_pin_login_phone), two 'guardian
-- check' rows (cancel_appointment, reschedule_appointment), then the
-- 'fact' rows, which show how appointments and audit_log link to other
-- tables. Those last ones are for the next fixes; paste them back.
SELECT 'trigger' AS kind, trigger_name AS name, action_timing || ' ' || event_manipulation AS detail
FROM   information_schema.triggers
WHERE  event_object_table = 'users' AND trigger_name = 'trg_protect_pin_login_phone'
UNION ALL
SELECT 'guardian check', p.proname, 'ok'
FROM   pg_proc p
WHERE  p.proname IN ('cancel_appointment', 'reschedule_appointment')
  AND  pg_get_functiondef(p.oid) LIKE '%dependent_profiles%'
UNION ALL
SELECT 'fact', 'appointments.' || column_name || ' nullable', is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'public' AND table_name = 'appointments'
  AND  column_name IN ('patient_id', 'provider_id')
UNION ALL
SELECT 'fact', conrelid::regclass::text || ' ' || conname, pg_get_constraintdef(oid)
FROM   pg_constraint
WHERE  contype = 'f'
  AND  conrelid IN ('public.appointments'::regclass, 'public.audit_log'::regclass);
