-- ================================================================
-- 012_provider_facility_unlink.sql
--
-- Small follow-up to 011_provider_verification.sql: adds the missing
-- other half of facility staffing — removing a provider from a
-- facility's roster (e.g. they've left). provider_facilities has no
-- client DELETE policy at all (by design, same as its INSERT), so this
-- needs its own admin-only, audited RPC rather than a raw DELETE.
-- ================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_unlink_provider_from_facility(
  target_user_id UUID,
  target_facility_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Only admins can unlink a provider from a facility';
  END IF;

  DELETE FROM public.provider_facilities
  WHERE provider_id = target_user_id AND facility_id = target_facility_id;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_unlink',
    auth.uid(),
    jsonb_build_object('target_user_id', target_user_id, 'facility_id', target_facility_id),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_unlink_provider_from_facility(UUID, UUID) TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY after running:
--
-- As a non-admin, this must fail (no RLS policy permits a raw DELETE):
--   DELETE FROM provider_facilities WHERE provider_id = auth.uid() AND facility_id = '<any-uuid>';
--
-- As an admin, this must succeed and log to audit_log:
--   SELECT admin_unlink_provider_from_facility('<provider-uuid>', '<facility-uuid>');
--   SELECT * FROM audit_log WHERE action = 'facility_unlink' ORDER BY timestamp DESC LIMIT 1;
-- ================================================================
