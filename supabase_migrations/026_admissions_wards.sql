-- Admissions & Wards — final subsystem of the facility-admin-as-HMS
-- roadmap (see memory: facility_admin_hms_pivot.md). Genuinely
-- greenfield: unlike appointments/lab_orders/prescriptions, a full-repo
-- search found ZERO pre-existing wards/beds/admissions concept anywhere.
--
-- wards is a facility-wide catalog (like departments) -- a stable
-- {name, total_beds} list, not visit-derived. No type/category column:
-- the target mockup folds type into name ("Ward A -- Maternity").
--
-- visit_admissions is visit-derived (like visit_lab_orders/
-- visit_prescriptions): facility_id/facility_patient_id/provider_id are
-- denormalized snapshots from the parent visit at admission time, same
-- "no embedded joins" reasoning as Lab/Pharmacy. discharged_at is
-- nullable with NO separate status column -- a plain two-state domain
-- fact (NULL = currently admitted), same reasoning as everywhere else in
-- this schema a timestamp's presence already determines state.
-- bed_number is free text, no bed-inventory table -- capacity is
-- enforced by counting active admissions per ward against
-- wards.total_beds, matching Pharmacy's "one row per drug, not per
-- unit" minimalism. eligibility_status is deliberately NOT copied onto
-- this table -- unlike name snapshots, clearance must stay LIVE (Billing
-- can update it after admission), so it's read from visits at load time.
--
-- visits.status gains 'admitted'. This does NOT violate 021/022's "not a
-- dumping ground" principle -- that principle targets PARALLEL,
-- non-exclusive concerns (billing/lab/pharmacy can all be simultaneously
-- pending on one visit, correctly living in their own tables/columns).
-- Admission is different in kind: a visit occupies exactly one lifecycle
-- stage at a time, and 'admitted' is mutually exclusive with
-- waiting/triage/in_consultation/completed -- that's precisely what
-- status is for. Free correct side effect: loadActiveVisits's existing
-- query (waiting/triage/in_consultation + today's completed) already
-- excludes 'admitted' visits with zero code change -- an admitted
-- patient silently and correctly disappears from the OPD Queue board.
--
-- Discharge is HARD-BLOCKED until eligibility_status = 'verified' --
-- confirmed explicitly with the user, not merely inferred from the
-- mockup: "blocks discharge until cleared" was a named goal in the
-- original project-scoping conversation. An admin can always run
-- facility_admin_update_visit_clearance (022) to verify first.
--
-- Same RPC-gated write / RLS-SELECT-only pattern as 013/020-025.

BEGIN;

CREATE TABLE IF NOT EXISTS public.wards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  total_beds INTEGER NOT NULL CHECK (total_beds > 0),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wards_facility ON public.wards(facility_id);

ALTER TABLE public.wards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wards_select_facility_admin" ON public.wards;
CREATE POLICY "wards_select_facility_admin"
ON public.wards FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.wards TO authenticated;

CREATE TABLE IF NOT EXISTS public.visit_admissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  facility_patient_id UUID NOT NULL REFERENCES public.facility_patients(id) ON DELETE CASCADE,
  ward_id UUID NOT NULL REFERENCES public.wards(id),
  provider_id UUID REFERENCES public.users(id),
  bed_number TEXT NOT NULL,
  admitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  discharged_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visit_admissions_facility ON public.visit_admissions(facility_id);
CREATE INDEX IF NOT EXISTS idx_visit_admissions_visit ON public.visit_admissions(visit_id);
CREATE INDEX IF NOT EXISTS idx_visit_admissions_ward_active ON public.visit_admissions(ward_id) WHERE discharged_at IS NULL;

-- DB-level backstop mirroring facility_drug_stock's quantity_on_hand >= 0
-- CHECK -- defense in depth behind the RPC's own "already admitted" check.
CREATE UNIQUE INDEX IF NOT EXISTS idx_visit_admissions_one_active_per_visit
  ON public.visit_admissions(visit_id) WHERE discharged_at IS NULL;

ALTER TABLE public.visit_admissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visit_admissions_select_facility_admin" ON public.visit_admissions;
CREATE POLICY "visit_admissions_select_facility_admin"
ON public.visit_admissions FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.visit_admissions TO authenticated;

-- visits.status widened to include 'admitted' -- see header comment for
-- why this is a legitimate lifecycle stage, not a "dumping ground" value.
ALTER TABLE public.visits DROP CONSTRAINT IF EXISTS visits_status_check;
ALTER TABLE public.visits ADD CONSTRAINT visits_status_check
  CHECK (status IN ('registered', 'waiting', 'triage', 'in_consultation', 'admitted', 'completed', 'cancelled'));

-- ------------------------------------------------------------------
-- facility_admin_add_ward / facility_admin_update_ward -- ward
-- management, mirroring facility_admin_add_department/
-- update_department's exact shape (013_facility_admins.sql).
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_add_ward(
  target_facility_id UUID,
  ward_name TEXT,
  ward_total_beds INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(target_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can add a ward';
  END IF;

  IF ward_name IS NULL OR btrim(ward_name) = '' THEN
    RAISE EXCEPTION 'Ward name is required';
  END IF;

  IF ward_total_beds IS NULL OR ward_total_beds <= 0 THEN
    RAISE EXCEPTION 'Total beds must be positive';
  END IF;

  INSERT INTO public.wards (facility_id, name, total_beds, created_by)
  VALUES (target_facility_id, btrim(ward_name), ward_total_beds, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'ward_added', auth.uid(),
    jsonb_build_object('facility_id', target_facility_id, 'ward_id', v_id, 'name', ward_name),
    now()
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.facility_admin_update_ward(
  target_ward_id UUID,
  ward_name TEXT,
  ward_total_beds INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
  v_occupied INTEGER;
BEGIN
  SELECT facility_id INTO v_facility_id FROM public.wards WHERE id = target_ward_id;
  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Ward not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can update this ward';
  END IF;

  IF ward_name IS NULL OR btrim(ward_name) = '' THEN
    RAISE EXCEPTION 'Ward name is required';
  END IF;

  IF ward_total_beds IS NULL OR ward_total_beds <= 0 THEN
    RAISE EXCEPTION 'Total beds must be positive';
  END IF;

  SELECT count(*) INTO v_occupied FROM public.visit_admissions
  WHERE ward_id = target_ward_id AND discharged_at IS NULL;

  IF ward_total_beds < v_occupied THEN
    RAISE EXCEPTION 'Cannot reduce capacity below currently occupied beds (% occupied)', v_occupied;
  END IF;

  UPDATE public.wards SET
    name = btrim(ward_name),
    total_beds = ward_total_beds,
    updated_at = now()
  WHERE id = target_ward_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'ward_updated', auth.uid(),
    jsonb_build_object('ward_id', target_ward_id, 'facility_id', v_facility_id, 'name', ward_name),
    now()
  );
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_admit_patient -- admits a visit into a ward/bed,
-- rejecting if the ward is already at capacity. Locks the ward row
-- itself as the serialization point (no single "capacity" row exists to
-- lock, unlike Pharmacy's quantity_on_hand) -- this blocks a concurrent
-- admit to the SAME ward until this transaction commits, so the COUNT
-- below always sees the true state.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_admit_patient(
  target_visit_id UUID,
  target_ward_id UUID,
  admission_bed_number TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
  v_facility_patient_id UUID;
  v_provider_id UUID;
  v_total_beds INTEGER;
  v_occupied INTEGER;
  v_id UUID;
BEGIN
  SELECT facility_id, facility_patient_id, provider_id
  INTO v_facility_id, v_facility_patient_id, v_provider_id
  FROM public.visits WHERE id = target_visit_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Visit not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can admit this visit';
  END IF;

  IF admission_bed_number IS NULL OR btrim(admission_bed_number) = '' THEN
    RAISE EXCEPTION 'Bed number is required';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.visit_admissions
    WHERE visit_id = target_visit_id AND discharged_at IS NULL
  ) THEN
    RAISE EXCEPTION 'This visit is already admitted';
  END IF;

  SELECT total_beds INTO v_total_beds FROM public.wards
  WHERE id = target_ward_id AND facility_id = v_facility_id
  FOR UPDATE;

  IF v_total_beds IS NULL THEN
    RAISE EXCEPTION 'Ward not found in this facility';
  END IF;

  SELECT count(*) INTO v_occupied FROM public.visit_admissions
  WHERE ward_id = target_ward_id AND discharged_at IS NULL;

  IF v_occupied >= v_total_beds THEN
    RAISE EXCEPTION 'Ward is at full capacity (%/% beds occupied)', v_occupied, v_total_beds;
  END IF;

  INSERT INTO public.visit_admissions (
    facility_id, visit_id, facility_patient_id, ward_id, provider_id, bed_number, created_by
  ) VALUES (
    v_facility_id, target_visit_id, v_facility_patient_id, target_ward_id, v_provider_id, btrim(admission_bed_number), auth.uid()
  ) RETURNING id INTO v_id;

  UPDATE public.visits SET status = 'admitted', status_changed_at = now() WHERE id = target_visit_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'patient_admitted', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'visit_id', target_visit_id,
      'admission_id', v_id, 'ward_id', target_ward_id
    ),
    now()
  );

  RETURN v_id;
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_discharge_patient -- HARD-BLOCKED unless the visit's
-- eligibility_status is 'verified' (confirmed explicitly with the user).
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_discharge_patient(
  target_admission_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
  v_visit_id UUID;
  v_discharged_at TIMESTAMPTZ;
  v_eligibility TEXT;
BEGIN
  SELECT a.facility_id, a.visit_id, a.discharged_at, v.eligibility_status
  INTO v_facility_id, v_visit_id, v_discharged_at, v_eligibility
  FROM public.visit_admissions a
  JOIN public.visits v ON v.id = a.visit_id
  WHERE a.id = target_admission_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Admission not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can discharge this patient';
  END IF;

  IF v_discharged_at IS NOT NULL THEN
    RAISE EXCEPTION 'Already discharged';
  END IF;

  IF v_eligibility IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'Cannot discharge until billing clearance is verified (currently %)', v_eligibility;
  END IF;

  UPDATE public.visit_admissions SET discharged_at = now() WHERE id = target_admission_id;
  UPDATE public.visits SET status = 'completed', status_changed_at = now() WHERE id = v_visit_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'patient_discharged', auth.uid(),
    jsonb_build_object('facility_id', v_facility_id, 'admission_id', target_admission_id, 'visit_id', v_visit_id),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_add_ward(UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_update_ward(UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_admit_patient(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_discharge_patient(UUID) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Adding a ward for your own facility succeeds:
--   SELECT facility_admin_add_ward('<own-facility-id>', 'Ward A -- Maternity', 20);
--
-- Admitting a visit into that ward succeeds and moves the visit out of
-- the OPD Queue board:
--   SELECT facility_admin_admit_patient('<own-visit-id>', '<ward-id>', 'Bed 4');
--   SELECT status FROM visits WHERE id = '<own-visit-id>'; -- 'admitted'
--   -- loadActiveVisits-equivalent query no longer returns this visit
--
-- Admitting the same visit again fails (already admitted):
--   SELECT facility_admin_admit_patient('<own-visit-id>', '<ward-id>', 'Bed 5'); -- fails
--
-- Admitting into a full ward fails once occupied = total_beds:
--   -- (repeat admits with different visits until the ward is full, then:)
--   SELECT facility_admin_admit_patient('<another-visit-id>', '<full-ward-id>', 'Bed X'); -- fails
--
-- Shrinking a ward below its current occupancy fails:
--   SELECT facility_admin_update_ward('<ward-id>', 'Ward A', 1); -- fails if occupied > 1
--
-- Discharging before clearance is verified fails:
--   SELECT facility_admin_discharge_patient('<admission-id>'); -- fails, 'currently pending'
--
-- Verifying clearance, then discharging, succeeds:
--   SELECT facility_admin_update_visit_clearance('<own-visit-id>', NULL, 'verified');
--   SELECT facility_admin_discharge_patient('<admission-id>');
--   SELECT status FROM visits WHERE id = '<own-visit-id>'; -- 'completed'
--
-- Discharging an already-discharged admission fails:
--   SELECT facility_admin_discharge_patient('<admission-id>'); -- fails, 'Already discharged'
--
-- Cross-facility add/update/admit/discharge all fail:
--   SELECT facility_admin_add_ward('<other-facility-id>', 'X', 10); -- fails
--   SELECT facility_admin_admit_patient('<other-facility-visit-id>', '<own-ward-id>', 'X'); -- fails
--   SELECT facility_admin_discharge_patient('<other-facility-admission-id>'); -- fails
--
-- Reading another facility's wards/admissions returns zero rows (RLS):
--   SELECT * FROM wards WHERE facility_id = '<other-facility-id>';
--   SELECT * FROM visit_admissions WHERE facility_id = '<other-facility-id>';
--
-- As the platform admin: all four RPCs succeed for any facility.
-- ================================================================
