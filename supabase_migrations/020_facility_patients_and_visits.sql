-- Facility admin "Patients" feature, step 1 of the facility-admin-as-HMS
-- roadmap (see memory: facility_admin_hms_pivot.md). Two new tables:
--
-- facility_patients — a facility's own patient register. Independent of
-- `users`/`patients` (that pair is the app's own account-holder clinical
-- profile, read/written by patient_profile_provider.dart). A walk-in here
-- needs no AfiCare account. Optionally, if the walk-in happens to already
-- be an AfiCare user or a guardian's dependent, linked_user_id /
-- linked_dependent_id may point at that record -- both nullable, at most
-- one set, neither required nor looked up by this migration or its RPCs
-- (dependent_profiles has no facility-facing SELECT policy today; wiring
-- an actual link-lookup UI is a separate follow-up).
--
-- visits — the single unified encounter table. OPD Queue (the next
-- roadmap step) will drive its board off `status`/`provider_id` on THIS
-- table, not a separate queue-entry table to keep in sync. Billing/
-- Clearance (the step after) should add its own status column rather
-- than overload this one.
--
-- Same facility-scoped pattern as everywhere else in this feature:
-- is_facility_admin_of()/get_my_role() gate, writes go through audited
-- SECURITY DEFINER RPCs, reads go through a plain RLS SELECT policy (no
-- direct write policy) -- mirrors facility_admins itself (013).

BEGIN;

CREATE TABLE IF NOT EXISTS public.facility_patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  phone TEXT,
  file_number TEXT,
  sha_status TEXT NOT NULL DEFAULT 'unknown'
    CHECK (sha_status IN ('unknown', 'not_registered', 'registered')),
  sha_number TEXT,
  allergies TEXT[] NOT NULL DEFAULT '{}',
  linked_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  linked_dependent_id UUID REFERENCES public.dependent_profiles(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT facility_patients_one_link
    CHECK (linked_user_id IS NULL OR linked_dependent_id IS NULL)
);

-- file_number is a facility-local OP/file number, unique per facility
-- when present, but blank is allowed (pure walk-in with no file yet).
CREATE UNIQUE INDEX IF NOT EXISTS facility_patients_facility_file_number_key
  ON public.facility_patients(facility_id, file_number)
  WHERE file_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_facility_patients_facility
  ON public.facility_patients(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_patients_linked_user
  ON public.facility_patients(linked_user_id);

ALTER TABLE public.facility_patients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_patients_select_facility_admin" ON public.facility_patients;
CREATE POLICY "facility_patients_select_facility_admin"
ON public.facility_patients FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

-- No INSERT/UPDATE/DELETE policy -- RPC-only, below, same as
-- facility_admins in 013.

GRANT SELECT ON public.facility_patients TO authenticated;

CREATE TABLE IF NOT EXISTS public.visits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  facility_patient_id UUID NOT NULL REFERENCES public.facility_patients(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'registered'
    CHECK (status IN ('registered', 'waiting', 'in_consultation', 'completed', 'cancelled')),
  provider_id UUID REFERENCES public.users(id),
  chief_complaint TEXT,
  notes TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visits_facility ON public.visits(facility_id);
CREATE INDEX IF NOT EXISTS idx_visits_patient ON public.visits(facility_patient_id);
CREATE INDEX IF NOT EXISTS idx_visits_status ON public.visits(status);

ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visits_select_facility_admin" ON public.visits;
CREATE POLICY "visits_select_facility_admin"
ON public.visits FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.visits TO authenticated;

-- ------------------------------------------------------------------
-- facility_admin_register_patient — the only way a facility_patients
-- row is created. Mirrors facility_admin_add_department's gate/audit
-- shape exactly.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_register_patient(
  target_facility_id UUID,
  patient_full_name TEXT,
  patient_date_of_birth DATE DEFAULT NULL,
  patient_gender TEXT DEFAULT NULL,
  patient_phone TEXT DEFAULT NULL,
  patient_file_number TEXT DEFAULT NULL,
  patient_sha_status TEXT DEFAULT 'unknown',
  patient_sha_number TEXT DEFAULT NULL,
  patient_allergies TEXT[] DEFAULT '{}'
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
    RAISE EXCEPTION 'Only an admin of this facility can register a patient here';
  END IF;

  IF patient_full_name IS NULL OR btrim(patient_full_name) = '' THEN
    RAISE EXCEPTION 'Patient name is required';
  END IF;

  INSERT INTO public.facility_patients (
    facility_id, full_name, date_of_birth, gender, phone,
    file_number, sha_status, sha_number, allergies, created_by
  ) VALUES (
    target_facility_id, patient_full_name, patient_date_of_birth, patient_gender, patient_phone,
    patient_file_number, COALESCE(patient_sha_status, 'unknown'), patient_sha_number, patient_allergies, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_patient_registered',
    auth.uid(),
    jsonb_build_object('facility_id', target_facility_id, 'facility_patient_id', v_id, 'name', patient_full_name),
    now()
  );

  RETURN v_id;
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_register_visit — the bare "register a visit" action
-- for this step. Looks up facility_id from the patient row itself so
-- callers can't spoof a mismatched facility_id.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_register_visit(
  target_facility_patient_id UUID,
  visit_chief_complaint TEXT DEFAULT NULL,
  visit_notes TEXT DEFAULT NULL,
  visit_provider_id UUID DEFAULT NULL
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

  INSERT INTO public.visits (
    facility_id, facility_patient_id, chief_complaint, notes, provider_id, created_by
  ) VALUES (
    v_facility_id, target_facility_patient_id, visit_chief_complaint, visit_notes, visit_provider_id, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'visit_registered',
    auth.uid(),
    jsonb_build_object('facility_id', v_facility_id, 'facility_patient_id', target_facility_patient_id, 'visit_id', v_id),
    now()
  );

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_register_patient(UUID, TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_register_visit(UUID, TEXT, TEXT, UUID) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- As a facility admin, registering a patient at THEIR facility must
-- succeed and return a uuid:
--   SELECT facility_admin_register_patient('<own-facility-id>', 'Jane Walkin', '1990-01-01', 'female', '0700000000', 'OP-001', 'unknown', NULL, ARRAY['penicillin']);
--
-- As that same admin, registering at a DIFFERENT facility must fail:
--   SELECT facility_admin_register_patient('<other-facility-id>', 'X', NULL, NULL, NULL, NULL, 'unknown', NULL, '{}');
--
-- Reading another facility's patients must return zero rows (RLS):
--   SELECT * FROM facility_patients WHERE facility_id = '<other-facility-id>';
--
-- Registering a visit for a patient at your own facility must succeed
-- and appear with status = 'registered':
--   SELECT facility_admin_register_visit('<facility-patient-id>', 'Fever, 3 days', NULL, NULL);
--   SELECT status FROM visits WHERE facility_patient_id = '<facility-patient-id>';
--
-- As the platform admin: both RPCs succeed for any facility_id.
-- ================================================================
