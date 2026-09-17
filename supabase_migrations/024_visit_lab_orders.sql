-- Laboratory — step 4 of the facility-admin-as-HMS roadmap (see memory:
-- facility_admin_hms_pivot.md). New table `visit_lab_orders`, hung off
-- `visits` the same way OPD Queue (021) and Billing & Clearance (022) are.
--
-- Not named `lab_orders` -- that name is already taken by a completely
-- separate, pre-existing patient-account/provider clinical system
-- (aficare_flutter/supabase/schema.sql) keyed by users.id via auth.uid()
-- RLS, with zero overlap with facility_patients/visits. This is a new,
-- unrelated table for the facility-admin walk-in world.
--
-- A visit can have MULTIPLE concurrent lab orders (1:many), unlike
-- Billing/OPD which are 1:1 per visit -- a `visits` column literally
-- cannot express this, so a new table (not a new visits column) is
-- required here, unlike 022/023's column-only additions.
--
-- facility_id, facility_patient_id AND provider_id are all denormalized
-- snapshots copied from the parent visit at order-placement time (not
-- just facility_id like `visits` itself does) -- this lets reads use the
-- same "no embedded joins, N-query client-side" convention every other
-- board in this schema uses (visit_lab_orders -> facility_patients for
-- names, -> users for the ordering provider's name) instead of joining
-- through `visits`.
--
-- Status is deliberately just pending/processing/completed -- no stored
-- "overdue". Exactly like OPD Queue never stores "late", overdue here is
-- computed client-side from now() - ordered_at against a fixed 2-hour
-- target (matching the mockup's single "Turnaround target: 2 hrs" note).
-- Overdue is a lateness annotation over pending/processing, not a
-- workflow step you advance into -- so it's not a CHECK value. No stored
-- turnaround-target column either (a single global constant is all v1
-- needs; additive later if per-test SLAs are ever needed) and no
-- completed_at column (status_changed_at already captures that instant
-- when status = 'completed').
--
-- Same RPC-gated write / RLS-SELECT-only pattern as 020-023.

BEGIN;

CREATE TABLE IF NOT EXISTS public.visit_lab_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  facility_patient_id UUID NOT NULL REFERENCES public.facility_patients(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES public.users(id),
  test_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed')),
  ordered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visit_lab_orders_facility ON public.visit_lab_orders(facility_id);
CREATE INDEX IF NOT EXISTS idx_visit_lab_orders_visit ON public.visit_lab_orders(visit_id);
CREATE INDEX IF NOT EXISTS idx_visit_lab_orders_status ON public.visit_lab_orders(status);

ALTER TABLE public.visit_lab_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visit_lab_orders_select_facility_admin" ON public.visit_lab_orders;
CREATE POLICY "visit_lab_orders_select_facility_admin"
ON public.visit_lab_orders FOR SELECT
USING (is_facility_admin_of(facility_id) OR get_my_role() = 'admin');

GRANT SELECT ON public.visit_lab_orders TO authenticated;

-- ------------------------------------------------------------------
-- facility_admin_place_lab_order -- creates one order against a visit.
-- "Ordered by" is snapshotted from the visit's own provider_id (not a
-- new param) -- the "Register Visit" dialog doesn't collect a provider
-- today, so a provider-picker here would be new, unrequested scope.
-- Visits with no provider set just show "Unassigned" client-side.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_place_lab_order(
  target_visit_id UUID,
  order_test_name TEXT
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
    RAISE EXCEPTION 'Only an admin of this facility can order a lab test for this visit';
  END IF;

  IF order_test_name IS NULL OR btrim(order_test_name) = '' THEN
    RAISE EXCEPTION 'Test name is required';
  END IF;

  INSERT INTO public.visit_lab_orders (
    facility_id, visit_id, facility_patient_id, provider_id, test_name, created_by
  ) VALUES (
    v_facility_id, target_visit_id, v_facility_patient_id, v_provider_id, btrim(order_test_name), auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'lab_order_placed', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'visit_id', target_visit_id,
      'lab_order_id', v_id, 'test_name', order_test_name
    ),
    now()
  );

  RETURN v_id;
END;
$$;

-- ------------------------------------------------------------------
-- facility_admin_update_lab_order_status -- advances pending -> processing
-- -> completed. Same lookup-then-gate-then-COALESCE-update-then-audit
-- shape as facility_admin_update_visit_status (021).
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_update_lab_order_status(
  target_lab_order_id UUID,
  new_status TEXT
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
  FROM public.visit_lab_orders WHERE id = target_lab_order_id;

  IF v_facility_id IS NULL THEN
    RAISE EXCEPTION 'Lab order not found';
  END IF;

  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(v_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can update this lab order';
  END IF;

  UPDATE public.visit_lab_orders SET
    status = COALESCE(new_status, status),
    status_changed_at = CASE
      WHEN new_status IS NOT NULL AND new_status IS DISTINCT FROM status THEN now()
      ELSE status_changed_at
    END
  WHERE id = target_lab_order_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'lab_order_status_updated', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'lab_order_id', target_lab_order_id, 'new_status', new_status
    ),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_place_lab_order(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facility_admin_update_lab_order_status(UUID, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Placing an order on your own facility's visit succeeds and defaults
-- to pending:
--   SELECT facility_admin_place_lab_order('<own-visit-id>', 'Full haemogram');
--   SELECT status, ordered_at, status_changed_at FROM visit_lab_orders WHERE id = '<returned-id>';
--
-- Placing on a DIFFERENT facility's visit must fail:
--   SELECT facility_admin_place_lab_order('<other-facility-visit-id>', 'X'); -- fails
--
-- A blank test name fails:
--   SELECT facility_admin_place_lab_order('<own-visit-id>', ''); -- fails
--
-- Advancing bumps status_changed_at only when status actually changes:
--   SELECT facility_admin_update_lab_order_status('<lab-order-id>', 'processing');
--   SELECT status, status_changed_at FROM visit_lab_orders WHERE id = '<lab-order-id>'; -- changed_at bumped
--   SELECT facility_admin_update_lab_order_status('<lab-order-id>', 'processing'); -- same status
--   SELECT status_changed_at FROM visit_lab_orders WHERE id = '<lab-order-id>'; -- UNCHANGED
--
-- A bad status value fails the CHECK:
--   SELECT facility_admin_update_lab_order_status('<lab-order-id>', 'bogus'); -- fails
--
-- Cross-facility status update fails:
--   SELECT facility_admin_update_lab_order_status('<other-facility-lab-order-id>', 'completed'); -- fails
--
-- Reading another facility's lab orders returns zero rows (RLS):
--   SELECT * FROM visit_lab_orders WHERE facility_id = '<other-facility-id>';
--
-- As the platform admin: both RPCs succeed for any facility's visit/order.
-- ================================================================
