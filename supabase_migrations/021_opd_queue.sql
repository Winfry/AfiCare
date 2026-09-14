-- OPD Queue — step 2 of the facility-admin-as-HMS roadmap. Builds
-- directly on `visits` (020) rather than a parallel queue-entry table: a
-- queue "row" IS a visit whose status is one of waiting/triage/
-- in_consultation, and "leaving the queue" is just status becoming
-- completed/cancelled.
--
-- New concepts on visits:
--   - 'triage' inserted as a stage between waiting and in_consultation.
--     in_consultation is NOT renamed in the DB (still "in_consultation"),
--     only labeled "With Doctor" in the UI, to avoid touching existing
--     rows and the Patients-tab call site that already reads/writes it.
--   - priority: routine/priority/urgent. Deliberately NOT
--     triage_assessments.triage_level (emergency/urgent/non_urgent) or
--     referrals.urgency (routine/urgent/emergency) -- both already exist,
--     already disagree with each other, and OPD Queue has no dependency
--     on either table. This is its own vocabulary, matching the mockup.
--   - status_changed_at: lets "waiting 34 min" be computed as
--     now() - status_changed_at. occurred_at is unrelated (visit-creation
--     time, set once, never touched again).
--
-- Same RPC-gated write / RLS-SELECT-only pattern as 020. Billing/
-- Clearance (a later roadmap step) must add ITS OWN status column when
-- it arrives -- visits.status is not to become a dumping ground for
-- billing state.

BEGIN;

ALTER TABLE public.visits DROP CONSTRAINT IF EXISTS visits_status_check;
ALTER TABLE public.visits ADD CONSTRAINT visits_status_check
  CHECK (status IN ('registered', 'waiting', 'triage', 'in_consultation', 'completed', 'cancelled'));

ALTER TABLE public.visits
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'routine'
    CHECK (priority IN ('routine', 'priority', 'urgent'));

ALTER TABLE public.visits
  ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_visits_status_changed_at ON public.visits(status_changed_at);

-- ------------------------------------------------------------------
-- facility_admin_register_visit — widened to accept an initial
-- status/priority so "add walk-in straight to the queue" is one RPC
-- call, not register-then-immediately-update. Replaces the 020 4-arg
-- version (DROP first: adding params changes the signature, CREATE OR
-- REPLACE alone would leave both overloads live).
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.facility_admin_register_visit(UUID, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.facility_admin_register_visit(
  target_facility_patient_id UUID,
  visit_chief_complaint TEXT DEFAULT NULL,
  visit_notes TEXT DEFAULT NULL,
  visit_provider_id UUID DEFAULT NULL,
  visit_status TEXT DEFAULT NULL,
  visit_priority TEXT DEFAULT NULL
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
    status, priority, created_by
  ) VALUES (
    v_facility_id, target_facility_patient_id, visit_chief_complaint, visit_notes, visit_provider_id,
    COALESCE(visit_status, 'registered'), COALESCE(visit_priority, 'routine'), auth.uid()
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

-- ------------------------------------------------------------------
-- facility_admin_update_visit_status — the OPD Queue stage-advance /
-- priority-change action. Looks up facility_id (and current status)
-- from the visit row itself, same defensive pattern as every RPC in
-- 020. status_changed_at only moves when status actually changes.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_update_visit_status(
  target_visit_id UUID,
  new_status TEXT,
  new_priority TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
BEGIN
  SELECT facility_id INTO v_facility_id
  FROM public.visits WHERE id = target_visit_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Visit not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can update this visit';
  END IF;

  UPDATE public.visits SET
    status = COALESCE(new_status, status),
    priority = COALESCE(new_priority, priority),
    status_changed_at = CASE
      WHEN new_status IS NOT NULL AND new_status IS DISTINCT FROM status THEN now()
      ELSE status_changed_at
    END
  WHERE id = target_visit_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'visit_status_updated', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'visit_id', target_visit_id,
      'new_status', new_status, 'new_priority', new_priority
    ),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_register_visit(UUID, TEXT, TEXT, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_update_visit_status(UUID, TEXT, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Widened status/priority CHECKs accept the new values, reject bad ones:
--   UPDATE visits SET status = 'triage' WHERE id = '<own-visit-id>'; -- ok
--   UPDATE visits SET status = 'bogus' WHERE id = '<own-visit-id>';  -- fails CHECK
--   UPDATE visits SET priority = 'urgent' WHERE id = '<own-visit-id>'; -- ok
--
-- Registering a walk-in straight into the queue, one call:
--   SELECT facility_admin_register_visit('<facility-patient-id>', 'Chest pain', NULL, NULL, 'waiting', 'urgent');
--   SELECT status, priority, status_changed_at FROM visits WHERE id = '<returned-id>';
--   -- status_changed_at should equal created_at (or be within the same instant)
--
-- Advancing a visit through the queue updates status_changed_at only when
-- status actually changes:
--   SELECT facility_admin_update_visit_status('<visit-id>', 'triage', NULL);
--   SELECT status, status_changed_at FROM visits WHERE id = '<visit-id>'; -- changed_at bumped
--   SELECT facility_admin_update_visit_status('<visit-id>', 'triage', 'urgent'); -- same status, priority only
--   SELECT status, priority, status_changed_at FROM visits WHERE id = '<visit-id>'; -- changed_at UNCHANGED, priority updated
--
-- As a facility admin of a DIFFERENT facility, both new RPCs on a
-- visit/patient that isn't theirs must fail:
--   SELECT facility_admin_update_visit_status('<other-facility-visit-id>', 'triage', NULL); -- fails
--
-- A new visit cannot be registered pre-completed:
--   SELECT facility_admin_register_visit('<facility-patient-id>', NULL, NULL, NULL, 'completed', NULL); -- fails
--
-- Reading another facility's visits still returns zero rows (RLS,
-- unchanged from 020):
--   SELECT * FROM visits WHERE facility_id = '<other-facility-id>';
--
-- As the platform admin: both RPCs succeed for any facility's visit/patient.
-- ================================================================
