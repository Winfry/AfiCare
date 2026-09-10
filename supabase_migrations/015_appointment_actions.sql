-- ================================================================
-- 015_appointment_actions.sql
--
-- Gives appointments real state-changing actions: confirm, reschedule,
-- cancel. Migration 014 was read-only by design ("confirming, cancelling,
-- or rescheduling stays out of scope for now") -- this closes that gap,
-- but deliberately stays small: no new role, no operations-center UI.
-- Facility admins get exactly the same three actions a patient or the
-- assigned provider already conceptually has, just scoped to their own
-- facility's appointments (same is_facility_admin_of() pattern as 013/014).
--
-- Also fixes "reschedule" for good: today the Flutter app fakes a
-- reschedule by inserting a brand-new appointment row and cancelling the
-- old one -- two disconnected rows. reschedule_appointment() below does a
-- true in-place UPDATE instead.
-- ================================================================

BEGIN;

ALTER TABLE appointments ADD COLUMN IF NOT EXISTS cancelled_reason TEXT;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
UPDATE appointments SET updated_at = created_at WHERE updated_at IS NULL;
ALTER TABLE appointments ALTER COLUMN updated_at SET DEFAULT now();

-- Reuses the update_updated_at() trigger function already defined in
-- schema.sql (same one used by users_updated_at / expenses_updated_at).
DROP TRIGGER IF EXISTS appointments_updated_at ON appointments;
CREATE TRIGGER appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION public.confirm_appointment(target_appointment_id UUID)
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

  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'Only a pending appointment can be confirmed (current status: %)', v_status;
  END IF;

  IF NOT (
    get_my_role() = 'admin'
    OR (v_facility_id IS NOT NULL AND is_facility_admin_of(v_facility_id))
    OR v_provider_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized to confirm this appointment';
  END IF;

  UPDATE public.appointments SET status = 'confirmed' WHERE id = target_appointment_id;

  INSERT INTO public.audit_log (action, user_id, patient_id, details, timestamp)
  VALUES (
    'appointment_confirmed',
    auth.uid(),
    v_patient_id,
    jsonb_build_object(
      'appointment_id', target_appointment_id,
      'facility_id', v_facility_id,
      'provider_id', v_provider_id,
      'old_status', v_status,
      'new_status', 'confirmed'
    ),
    now()
  );
END;
$$;

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
    OR (v_patient_id = auth.uid() AND v_status IN ('pending', 'confirmed'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to reschedule this appointment';
  END IF;

  -- new_provider_id/new_duration_minutes accepted for forward compatibility
  -- (a future reassignment feature) but the current app UI never passes them.
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
    OR (v_patient_id = auth.uid() AND v_status IN ('pending', 'confirmed'))
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

GRANT EXECUTE ON FUNCTION public.confirm_appointment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_appointment(UUID, TIMESTAMPTZ, UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_appointment(UUID, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As the patient who owns a pending appointment, these must succeed:
--   SELECT cancel_appointment('<appt-uuid>', 'Change of plans');
--   SELECT reschedule_appointment('<appt-uuid-2>', now() + interval '2 days');
--
-- As that same patient, this must fail (patients cannot confirm):
--   SELECT confirm_appointment('<appt-uuid-3>');
--
-- As a different, unrelated patient, all three must fail with
-- "Not authorized...":
--   SELECT cancel_appointment('<someone-elses-appt-uuid>');
--
-- As the assigned provider, all three must succeed on their own
-- appointments regardless of facility.
--
-- As the facility_admin of the appointment's facility_id, all three
-- must succeed; as the facility_admin of a DIFFERENT facility, all
-- three must fail.
--
-- Re-cancelling an already-cancelled appointment, or confirming a
-- non-pending one, must raise the specific state-guard exception.
--
-- SELECT * FROM audit_log WHERE action LIKE 'appointment_%' ORDER BY timestamp DESC LIMIT 5;
-- ================================================================
