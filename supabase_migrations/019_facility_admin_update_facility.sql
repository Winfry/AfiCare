-- facility_admin_update_facility — lets a facility's own admin (or the
-- platform admin) edit that facility's profile details. Mirrors the
-- checked-RPC pattern already used for departments and provider-linking
-- in 013_facility_admins.sql (is_facility_admin_of() gate, audit log),
-- rather than a raw RLS UPDATE policy, so edits stay centrally guarded
-- and audited the same way the rest of this feature already is.
--
-- Deliberately excludes `status` -- verification stays platform-admin
-- only, via the existing facilities_update_platform_admin RLS policy.
CREATE OR REPLACE FUNCTION public.facility_admin_update_facility(
  target_facility_id UUID,
  facility_name TEXT,
  facility_type TEXT,
  facility_county TEXT DEFAULT NULL,
  facility_sub_county TEXT DEFAULT NULL,
  facility_address TEXT DEFAULT NULL,
  facility_phone TEXT DEFAULT NULL,
  facility_email TEXT DEFAULT NULL,
  facility_license_no TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF get_my_role() IS DISTINCT FROM 'admin' AND NOT is_facility_admin_of(target_facility_id) THEN
    RAISE EXCEPTION 'Only an admin of this facility can update its profile';
  END IF;

  IF facility_name IS NULL OR btrim(facility_name) = '' THEN
    RAISE EXCEPTION 'Facility name is required';
  END IF;

  UPDATE public.facilities
  SET
    name = facility_name,
    type = facility_type,
    county = facility_county,
    sub_county = facility_sub_county,
    address = facility_address,
    phone = facility_phone,
    email = facility_email,
    license_no = facility_license_no
  WHERE id = target_facility_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Facility not found';
  END IF;

  INSERT INTO public.audit_log (action, user_id, details, timestamp)
  VALUES (
    'facility_profile_updated',
    auth.uid(),
    jsonb_build_object('facility_id', target_facility_id, 'name', facility_name),
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.facility_admin_update_facility(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- VERIFY (run manually, not part of the migration):
--   As the facility's own admin: call with that facility's id -> succeeds,
--     facilities row updated, audit_log gets a 'facility_profile_updated' row.
--   As a facility admin of a DIFFERENT facility: call with a facility_id
--     that isn't theirs -> raises "Only an admin of this facility...".
--   As the platform admin: call with any facility_id -> succeeds.
--   With facility_name = '' or NULL -> raises "Facility name is required".
