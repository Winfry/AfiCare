-- Billing & Clearance — step 3 of the facility-admin-as-HMS roadmap (see
-- memory: facility_admin_hms_pivot.md). v1 scope only: link an encounter
-- to a payer (SHA/insurance/cash) and a manual eligibility-check status
-- (pending/verified/rejected). No real SHA API integration, no
-- invoicing/line-items, no discharge-blocking -- those are later steps.
--
-- Per 021_opd_queue.sql's own header comment ("Billing/Clearance ... must
-- add ITS OWN status column"), this adds columns directly to `visits`
-- rather than a new side table: eligibility_status defaults to 'pending'
-- so every visit has clearance state from creation, with no
-- lazy-create/upsert flow needed, no new RLS policy, no new grant -- the
-- existing visits_select_facility_admin SELECT policy already covers the
-- new columns, and writes stay RPC-only like every other visits mutation.

BEGIN;

ALTER TABLE public.visits
  ADD COLUMN IF NOT EXISTS payer_type TEXT
    CHECK (payer_type IN ('sha', 'insurance', 'cash'));

ALTER TABLE public.visits
  ADD COLUMN IF NOT EXISTS eligibility_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (eligibility_status IN ('pending', 'verified', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_visits_eligibility_status ON public.visits(eligibility_status);

-- ------------------------------------------------------------------
-- facility_admin_update_visit_clearance — sets payer/eligibility on a
-- visit. Same lookup-then-gate-then-COALESCE-update-then-audit shape as
-- facility_admin_update_visit_status (021). Bad enum values are rejected
-- by the CHECK constraints above, not re-validated here, same as that RPC.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.facility_admin_update_visit_clearance(
  target_visit_id UUID,
  new_payer_type TEXT DEFAULT NULL,
  new_eligibility_status TEXT DEFAULT NULL
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
    RAISE EXCEPTION 'Only an admin of this facility can update this visit''s clearance';
  END IF;

  UPDATE public.visits SET
    payer_type = COALESCE(new_payer_type, payer_type),
    eligibility_status = COALESCE(new_eligibility_status, eligibility_status)
  WHERE id = target_visit_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'visit_clearance_updated', auth.uid(),
    jsonb_build_object(
      'facility_id', v_facility_id, 'visit_id', target_visit_id,
      'new_payer_type', new_payer_type, 'new_eligibility_status', new_eligibility_status
    ),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_update_visit_clearance(UUID, TEXT, TEXT) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- New visits default to pending/unset, no separate creation step:
--   SELECT payer_type, eligibility_status FROM visits WHERE id = '<any-visit-id>';
--   -- eligibility_status = 'pending', payer_type = NULL until set
--
-- As a facility admin, updating clearance on your own facility's visit
-- must succeed:
--   SELECT facility_admin_update_visit_clearance('<own-visit-id>', 'sha', 'verified');
--   SELECT payer_type, eligibility_status FROM visits WHERE id = '<own-visit-id>';
--
-- A bad enum value fails the CHECK constraint:
--   SELECT facility_admin_update_visit_clearance('<own-visit-id>', 'bogus', NULL); -- fails
--   SELECT facility_admin_update_visit_clearance('<own-visit-id>', NULL, 'bogus'); -- fails
--
-- As a facility admin of a DIFFERENT facility, updating clearance on a
-- visit that isn't theirs must fail:
--   SELECT facility_admin_update_visit_clearance('<other-facility-visit-id>', 'cash', NULL); -- fails
--
-- Reading another facility's visits still returns zero rows (RLS,
-- unchanged from 020/021):
--   SELECT * FROM visits WHERE facility_id = '<other-facility-id>';
--
-- As the platform admin: the RPC succeeds for any facility's visit.
-- ================================================================
