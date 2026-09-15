-- Minimal vitals capture — part of closing the facility-admin Patients
-- detail / Overview gap against the target mockup (see memory:
-- facility_admin_hms_pivot.md). The Patient detail's "Overview" sub-tab
-- shows a small vitals row (BP/weight/temp) sourced from the patient's
-- most recent visit -- this migration adds the 4 nullable columns that
-- back it. No CHECK ranges (no other numeric column in this schema has
-- one -- appointments.duration_minutes doesn't either). No separate
-- "update vitals" RPC -- vitals are only ever set at visit-registration
-- time in this pass, so a second write RPC would be unused scope.

BEGIN;

ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS bp_systolic INT;
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS bp_diastolic INT;
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS weight_kg NUMERIC;
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS temperature_c NUMERIC;

-- ------------------------------------------------------------------
-- facility_admin_register_visit — widened a third time (020 -> 021
-- added status/priority -> this adds vitals). DROP first since adding
-- params changes the signature, same as 021's own widening.
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.facility_admin_register_visit(UUID, TEXT, TEXT, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.facility_admin_register_visit(
  target_facility_patient_id UUID,
  visit_chief_complaint TEXT DEFAULT NULL,
  visit_notes TEXT DEFAULT NULL,
  visit_provider_id UUID DEFAULT NULL,
  visit_status TEXT DEFAULT NULL,
  visit_priority TEXT DEFAULT NULL,
  visit_bp_systolic INT DEFAULT NULL,
  visit_bp_diastolic INT DEFAULT NULL,
  visit_weight_kg NUMERIC DEFAULT NULL,
  visit_temperature_c NUMERIC DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
  v_id UUID;
BEGIN
  SELECT facility_id INTO v_facility_id
  FROM public.facility_patients WHERE id = target_facility_patient_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Patient not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can register a visit for this patient';
  END IF;

  IF visit_status IS NOT NULL AND visit_status NOT IN ('registered', 'waiting') THEN
    RAISE EXCEPTION 'A new visit can only start as registered or waiting, not %', visit_status;
  END IF;

  INSERT INTO public.visits (
    facility_id, facility_patient_id, chief_complaint, notes, provider_id,
    status, priority, bp_systolic, bp_diastolic, weight_kg, temperature_c, created_by
  ) VALUES (
    v_facility_id, target_facility_patient_id, visit_chief_complaint, visit_notes, visit_provider_id,
    COALESCE(visit_status, 'registered'), COALESCE(visit_priority, 'routine'),
    visit_bp_systolic, visit_bp_diastolic, visit_weight_kg, visit_temperature_c, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'visit_registered', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'facility_patient_id', target_facility_patient_id,
      'visit_id', v_id, 'status', COALESCE(visit_status, 'registered')
    ),
    now()
  );

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_register_visit(UUID, TEXT, TEXT, UUID, TEXT, TEXT, INT, INT, NUMERIC, NUMERIC) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Registering a visit with vitals stores them:
--   SELECT facility_admin_register_visit('<facility-patient-id>', 'Headache', NULL, NULL, NULL, NULL, 148, 92, 78.0, 36.8);
--   SELECT bp_systolic, bp_diastolic, weight_kg, temperature_c FROM visits WHERE id = '<returned-id>';
--
-- Registering a visit without vitals leaves them NULL (no regression on
-- the existing call shape):
--   SELECT facility_admin_register_visit('<facility-patient-id>', 'Follow-up');
--   SELECT bp_systolic, weight_kg FROM visits WHERE id = '<returned-id>'; -- both NULL
--
-- Existing gates unchanged: cross-facility registration still fails, a
-- non-'registered'/'waiting' initial status still fails (see 021's
-- VERIFY block for those cases -- not re-tested here).
-- ================================================================
