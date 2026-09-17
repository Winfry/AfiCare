-- Pharmacy & Stock — step 5 of the facility-admin-as-HMS roadmap (see
-- memory: facility_admin_hms_pivot.md). Two new tables, following the
-- exact conventions from 020-024.
--
-- Not named `prescriptions` -- that name is already taken by a
-- completely separate, pre-existing patient-account/provider clinical
-- system (aficare_flutter/supabase/schema.sql) keyed by users.id via
-- auth.uid() RLS, with zero overlap with facility_patients/visits (same
-- situation as `appointments` and `lab_orders` before it). There is also
-- no drug-inventory/stock concept anywhere else in this schema -- both
-- tables here are entirely new.
--
-- facility_drug_stock is a facility-wide catalog, NOT visit-derived
-- (unlike every other board so far) -- one row per drug name per
-- facility, not per shipment/batch. "+ Receive Stock" increments an
-- existing row (case-insensitive name match) or creates one; the most
-- recently received batch_number/expiry_date simply overwrite the row's
-- values. True per-batch/FEFO tracking is NOT modeled -- out of scope,
-- matches the target mockup's own display (one row per drug, one
-- batch/expiry shown).
--
-- Stock level ("Reorder now" / "Low" / "In stock") is never stored --
-- it's a derived annotation over quantity_on_hand vs reorder_threshold,
-- computed client-side, exactly like Laboratory's "Overdue" is derived
-- from ordered_at rather than stored. reorder_threshold IS a per-row
-- column (unlike Lab's single global 2h constant) since different drugs
-- plausibly need very different reorder points.
--
-- visit_prescriptions is visit-derived like visit_lab_orders, but
-- medication is a required FK to facility_drug_stock (drug_stock_id),
-- NOT free text like Lab's test_name -- the whole point of this screen
-- per the target mockup is that dispensing decreases stock
-- automatically, which is only possible if the dispense action can
-- identify exactly which stock row to decrement. medication_label stays
-- a separate free-text snapshot (e.g. "Metformin 1000mg BD") so the
-- ledger can show dose/frequency without the stock catalog needing a row
-- per dose variant of the same drug.
--
-- "Stock take" (a button in the target mockup) is explicitly NOT built
-- here -- no reconciliation/audit-count feature exists in this
-- migration. The mockup gives no spec beyond a button label, and v1
-- already covers both directions of quantity change (Receive
-- increments, Dispense decrements).
--
-- Same RPC-gated write / RLS-SELECT-only pattern as 020-024.

BEGIN;

CREATE TABLE IF NOT EXISTS public.facility_drug_stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  drug_name TEXT NOT NULL,
  batch_number TEXT,
  expiry_date DATE,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  reorder_threshold INTEGER NOT NULL DEFAULT 20 CHECK (reorder_threshold >= 0),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facility_drug_stock_facility ON public.facility_drug_stock(facility_id);

ALTER TABLE public.facility_drug_stock ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_drug_stock_select_facility_admin" ON public.facility_drug_stock;
CREATE POLICY "facility_drug_stock_select_facility_admin"
ON public.facility_drug_stock FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.facility_drug_stock TO authenticated;

CREATE TABLE IF NOT EXISTS public.visit_prescriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  facility_patient_id UUID NOT NULL REFERENCES public.facility_patients(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES public.users(id),
  drug_stock_id UUID NOT NULL REFERENCES public.facility_drug_stock(id),
  medication_label TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'dispensed')),
  prescribed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visit_prescriptions_facility ON public.visit_prescriptions(facility_id);
CREATE INDEX IF NOT EXISTS idx_visit_prescriptions_visit ON public.visit_prescriptions(visit_id);
CREATE INDEX IF NOT EXISTS idx_visit_prescriptions_status ON public.visit_prescriptions(status);

ALTER TABLE public.visit_prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visit_prescriptions_select_facility_admin" ON public.visit_prescriptions;
CREATE POLICY "visit_prescriptions_select_facility_admin"
ON public.visit_prescriptions FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.visit_prescriptions TO authenticated;

-- ------------------------------------------------------------------
-- facility_admin_receive_stock -- increments an existing drug's stock
-- (case-insensitive name match within the facility) or creates a new
-- row. Params are named new_drug_name/new_batch_number/new_expiry_date
-- (not drug_name/batch_number/expiry_date) specifically to avoid
-- colliding with the table's own column names of the same name --
-- PL/pgSQL raises "column reference is ambiguous" by default whenever a
-- bare identifier matches both a table column and a parameter in the
-- same query scope, not just inside UPDATE...SET.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_receive_stock(
  target_facility_id UUID,
  new_drug_name TEXT,
  received_quantity INTEGER,
  new_batch_number TEXT DEFAULT NULL,
  new_expiry_date DATE DEFAULT NULL
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
    RAISE EXCEPTION 'Only an admin of this facility can receive stock here';
  END IF;

  IF new_drug_name IS NULL OR btrim(new_drug_name) = '' THEN
    RAISE EXCEPTION 'Drug name is required';
  END IF;

  IF received_quantity IS NULL OR received_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity received must be positive';
  END IF;

  SELECT id INTO v_id FROM public.facility_drug_stock
  WHERE facility_id = target_facility_id AND lower(drug_name) = lower(btrim(new_drug_name))
  FOR UPDATE;

  IF v_id IS NOT NULL THEN
    UPDATE public.facility_drug_stock SET
      quantity_on_hand = quantity_on_hand + received_quantity,
      batch_number = COALESCE(new_batch_number, batch_number),
      expiry_date = COALESCE(new_expiry_date, expiry_date),
      updated_at = now()
    WHERE id = v_id;
  ELSE
    INSERT INTO public.facility_drug_stock (
      facility_id, drug_name, batch_number, expiry_date, quantity_on_hand, created_by
    ) VALUES (
      target_facility_id, btrim(new_drug_name), new_batch_number, new_expiry_date, received_quantity, auth.uid()
    ) RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'drug_stock_received', auth.uid(),
    jsonb_build_object(
      'facility_id', target_facility_id, 'drug_stock_id', v_id,
      'drug_name', new_drug_name, 'quantity_received', received_quantity
    ),
    now()
  );

  RETURN v_id;
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_dispense_prescription -- atomically decrements stock
-- and marks the prescription dispensed. The FOR UPDATE row lock on
-- facility_drug_stock prevents a race between two concurrent dispenses
-- of the last unit. The explicit insufficient-stock check is the first
-- "reject based on a computed condition" RPC in this migration series --
-- the table's own CHECK (quantity_on_hand >= 0) is a defense-in-depth
-- backstop, not the primary guard (which needs a legible error message).
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_dispense_prescription(
  target_prescription_id UUID,
  dispensed_quantity INTEGER DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facility_id UUID;
  v_drug_stock_id UUID;
  v_status TEXT;
  v_quantity_on_hand INTEGER;
BEGIN
  SELECT facility_id, drug_stock_id, status INTO v_facility_id, v_drug_stock_id, v_status
  FROM public.visit_prescriptions WHERE id = target_prescription_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Prescription not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can dispense this prescription';
  END IF;

  IF v_status = 'dispensed' THEN
    RAISE EXCEPTION 'Prescription already dispensed';
  END IF;

  IF dispensed_quantity IS NULL OR dispensed_quantity <= 0 THEN
    RAISE EXCEPTION 'Dispensed quantity must be positive';
  END IF;

  SELECT quantity_on_hand INTO v_quantity_on_hand
  FROM public.facility_drug_stock WHERE id = v_drug_stock_id FOR UPDATE;

  IF v_quantity_on_hand IS NULL OR v_quantity_on_hand < dispensed_quantity THEN
    RAISE EXCEPTION 'Insufficient stock: only % unit(s) on hand', COALESCE(v_quantity_on_hand, 0);
  END IF;

  UPDATE public.facility_drug_stock
  SET quantity_on_hand = quantity_on_hand - dispensed_quantity, updated_at = now()
  WHERE id = v_drug_stock_id;

  UPDATE public.visit_prescriptions
  SET status = 'dispensed', status_changed_at = now()
  WHERE id = target_prescription_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'prescription_dispensed', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'prescription_id', target_prescription_id,
      'drug_stock_id', v_drug_stock_id, 'dispensed_quantity', dispensed_quantity
    ),
    now()
  );
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_place_prescription -- creates one prescription against
-- a visit, referencing a real facility_drug_stock row (not free text).
-- Mirrors facility_admin_place_lab_order's lookup-gate-validate-insert-
-- audit shape, plus a same-facility check on the selected stock item.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_place_prescription(
  target_visit_id UUID,
  target_drug_stock_id UUID,
  new_medication_label TEXT
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
  v_id UUID;
BEGIN
  SELECT facility_id, facility_patient_id, provider_id
  INTO v_facility_id, v_facility_patient_id, v_provider_id
  FROM public.visits WHERE id = target_visit_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Visit not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can prescribe for this visit';
  END IF;

  IF new_medication_label IS NULL OR btrim(new_medication_label) = '' THEN
    RAISE EXCEPTION 'Medication label is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.facility_drug_stock
    WHERE id = target_drug_stock_id AND facility_id = v_facility_id
  ) THEN
    RAISE EXCEPTION 'Selected drug is not in this facility''s stock';
  END IF;

  INSERT INTO public.visit_prescriptions (
    facility_id, visit_id, facility_patient_id, provider_id, drug_stock_id, medication_label, created_by
  ) VALUES (
    v_facility_id, target_visit_id, v_facility_patient_id, v_provider_id, target_drug_stock_id, btrim(new_medication_label), auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'prescription_placed', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'visit_id', target_visit_id,
      'prescription_id', v_id, 'drug_stock_id', target_drug_stock_id
    ),
    now()
  );

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_receive_stock(UUID, TEXT, INTEGER, TEXT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_dispense_prescription(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_place_prescription(UUID, UUID, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Receiving stock for a new drug creates a row:
--   SELECT facility_admin_receive_stock('<own-facility-id>', 'Amoxicillin 250mg', 50, 'B123', '2027-03-01');
--   SELECT drug_name, quantity_on_hand FROM facility_drug_stock WHERE facility_id = '<own-facility-id>';
--
-- Receiving stock for the SAME drug name increments rather than
-- duplicating:
--   SELECT facility_admin_receive_stock('<own-facility-id>', 'amoxicillin 250mg', 10);
--   SELECT count(*), sum(quantity_on_hand) FROM facility_drug_stock
--     WHERE facility_id = '<own-facility-id>' AND lower(drug_name) = 'amoxicillin 250mg'; -- count=1, sum=60
--
-- Placing a prescription against your own visit for a drug in your own
-- stock succeeds:
--   SELECT facility_admin_place_prescription('<own-visit-id>', '<own-drug-stock-id>', 'Amoxicillin 250mg TDS');
--
-- Placing a prescription referencing a drug from a DIFFERENT facility's
-- stock fails:
--   SELECT facility_admin_place_prescription('<own-visit-id>', '<other-facility-drug-stock-id>', 'X'); -- fails
--
-- Dispensing decrements stock and marks the prescription dispensed:
--   SELECT facility_admin_dispense_prescription('<prescription-id>');
--   SELECT status FROM visit_prescriptions WHERE id = '<prescription-id>'; -- 'dispensed'
--   SELECT quantity_on_hand FROM facility_drug_stock WHERE id = '<drug-stock-id>'; -- decremented by 1
--
-- Dispensing an already-dispensed prescription fails:
--   SELECT facility_admin_dispense_prescription('<prescription-id>'); -- fails, 'already dispensed'
--
-- Dispensing more than on-hand fails with the insufficient-stock message:
--   SELECT facility_admin_dispense_prescription('<new-prescription-id>', 999999); -- fails
--
-- Cross-facility receive/dispense/place all fail:
--   SELECT facility_admin_receive_stock('<other-facility-id>', 'X', 1); -- fails
--   SELECT facility_admin_dispense_prescription('<other-facility-prescription-id>'); -- fails
--   SELECT facility_admin_place_prescription('<other-facility-visit-id>', '<own-drug-stock-id>', 'X'); -- fails
--
-- Reading another facility's stock/prescriptions returns zero rows (RLS):
--   SELECT * FROM facility_drug_stock WHERE facility_id = '<other-facility-id>';
--   SELECT * FROM visit_prescriptions WHERE facility_id = '<other-facility-id>';
--
-- As the platform admin: all three RPCs succeed for any facility.
-- ================================================================
