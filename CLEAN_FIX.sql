CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT role
    FROM   users
    WHERE  id::text = (auth.uid())::text
  );
END;
$$;

DROP POLICY IF EXISTS "users_select_admin" ON users;
DROP POLICY IF EXISTS "users_select_consulted" ON users;
DROP POLICY IF EXISTS "users_update_admin" ON users;
DROP POLICY IF EXISTS "patients_select_consulted" ON patients;
DROP POLICY IF EXISTS "patients_select_admin" ON patients;
DROP POLICY IF EXISTS "consultations_select_admin" ON consultations;
DROP POLICY IF EXISTS "consultations_insert_provider" ON consultations;
DROP POLICY IF EXISTS "consultations_update_provider" ON consultations;
DROP POLICY IF EXISTS "facilities_insert_provider" ON facilities;
DROP POLICY IF EXISTS "facilities_update_admin" ON facilities;
DROP POLICY IF EXISTS "audit_log_select_admin" ON audit_log;

CREATE POLICY "users_select_admin"
ON users FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "users_select_consulted"
ON users FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND medilink_id::text IN (
    SELECT patient_id::text
    FROM   consultations
    WHERE  provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "users_update_admin"
ON users FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "patients_select_consulted"
ON patients FOR SELECT
USING (
  (SELECT get_my_role()) IN ('doctor', 'nurse')
  AND id::text IN (
    SELECT u.id::text
    FROM   users u
    JOIN   consultations c ON c.patient_id::text = u.medilink_id::text
    WHERE  c.provider_id::text = (auth.uid())::text
  )
);

CREATE POLICY "patients_select_admin"
ON patients FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "consultations_select_admin"
ON consultations FOR SELECT
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "consultations_insert_provider"
ON consultations FOR INSERT
WITH CHECK (
  provider_id::text = (auth.uid())::text
  AND (SELECT get_my_role()) IN ('doctor', 'nurse')
);

CREATE POLICY "consultations_update_provider"
ON consultations FOR UPDATE
USING (
  provider_id::text = (auth.uid())::text
  AND (SELECT get_my_role()) IN ('doctor', 'nurse')
);

CREATE POLICY "facilities_insert_provider"
ON facilities FOR INSERT
WITH CHECK ((SELECT get_my_role()) IN ('doctor', 'nurse', 'admin'));

CREATE POLICY "facilities_update_admin"
ON facilities FOR UPDATE
USING ((SELECT get_my_role()) = 'admin');

CREATE POLICY "audit_log_select_admin"
ON audit_log FOR SELECT
USING ((SELECT get_my_role()) = 'admin');
