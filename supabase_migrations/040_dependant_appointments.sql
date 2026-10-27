-- ================================================================
-- 040: Appointments for dependants (children and others with no
--      account of their own)
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
-- ================================================================
--
-- WHY
-- A parent could not book for their child. Four things stood in the way
-- (found by the 040 pre-check against the live database):
-- 1. appointments.patient_id had to be a users row. A dependant lives in
--    dependent_profiles and has no users row, so every booking failed.
-- 2. The booking policy only allowed patient_id = auth.uid().
-- 3. The viewing policy did the same, so the parent couldn't see it.
-- 4. audit_log.patient_id also had to be a users row, so confirming,
--    cancelling or moving a dependant's appointment failed at the log.
--
-- WHAT THIS DOES
-- • appointments.patient_id may be an account OR a dependant profile,
--   and nothing else (a trigger checks it; the same idea as care_team,
--   whose patient_id has no foreign key on purpose).
-- • The account holder may book and see appointments for themselves and
--   for dependants they are guardian of, and for no one else.
-- • audit_log.patient_id no longer has to be an account: it is a record
--   of what happened and must never block care.
-- • Deleting an account or a dependant profile still deletes their
--   appointments, as the old foreign key's ON DELETE CASCADE did.
-- • appointment_patient_names() tells the doctor of an appointment, the
--   facility's admin, an admin, or the patient/guardian who the patient
--   is: the name, and for a dependant, the guardian's name. Providers
--   cannot read dependent_profiles directly and still can't.
-- ================================================================

BEGIN;

-- ── 1. Who an appointment's patient may be ──────────────────────
CREATE OR REPLACE FUNCTION public.check_appointment_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.patient_id)
     AND NOT EXISTS (SELECT 1 FROM public.dependent_profiles WHERE id = NEW.patient_id) THEN
    RAISE EXCEPTION 'An appointment must be for an AfiCare account or a dependant profile';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_appointment_patient ON public.appointments;
CREATE TRIGGER trg_check_appointment_patient
BEFORE INSERT OR UPDATE OF patient_id ON public.appointments
FOR EACH ROW EXECUTE FUNCTION public.check_appointment_patient();

ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_patient_id_fkey;

-- ── 2. Deleting a person still deletes their appointments ──────
CREATE OR REPLACE FUNCTION public.delete_appointments_of_removed_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.appointments WHERE patient_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_delete_appointments_of_removed_user ON public.users;
CREATE TRIGGER trg_delete_appointments_of_removed_user
AFTER DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.delete_appointments_of_removed_patient();

DROP TRIGGER IF EXISTS trg_delete_appointments_of_removed_dependant ON public.dependent_profiles;
CREATE TRIGGER trg_delete_appointments_of_removed_dependant
AFTER DELETE ON public.dependent_profiles
FOR EACH ROW EXECUTE FUNCTION public.delete_appointments_of_removed_patient();

-- ── 3. Booking and viewing: yourself and your dependants ───────
DROP POLICY IF EXISTS "Patients can book appointments" ON public.appointments;
DROP POLICY IF EXISTS "Patients can view own appointments" ON public.appointments;
DROP POLICY IF EXISTS "appointments_insert_own_or_dependant" ON public.appointments;
DROP POLICY IF EXISTS "appointments_select_own_or_dependant" ON public.appointments;

CREATE POLICY "appointments_insert_own_or_dependant" ON public.appointments
FOR INSERT TO authenticated
WITH CHECK (
  patient_id = auth.uid()
  OR EXISTS (SELECT 1 FROM public.dependent_profiles d
             WHERE d.id = appointments.patient_id AND d.guardian_id = auth.uid())
);

CREATE POLICY "appointments_select_own_or_dependant" ON public.appointments
FOR SELECT TO authenticated
USING (
  patient_id = auth.uid()
  OR EXISTS (SELECT 1 FROM public.dependent_profiles d
             WHERE d.id = appointments.patient_id AND d.guardian_id = auth.uid())
);

-- ── 4. The audit log may name a dependant ───────────────────────
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_patient_id_fkey;

-- ── 5. Who is this appointment for? ─────────────────────────────
-- One row per appointment the caller may see; others are left out.
-- relationship is the dependant's to their guardian (child, grandchild,
-- sibling, other), so the label can read "Mary Wanjiru's child".
DROP FUNCTION IF EXISTS public.appointment_patient_names(UUID[]);
CREATE FUNCTION public.appointment_patient_names(p_appointment_ids UUID[])
RETURNS TABLE (
  appointment_id UUID,
  patient_name TEXT,
  is_dependant BOOLEAN,
  guardian_name TEXT,
  relationship TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.id,
         coalesce(u.full_name, d.full_name),
         d.id IS NOT NULL,
         g.full_name,
         d.relationship
  FROM public.appointments a
  LEFT JOIN public.users u ON u.id = a.patient_id
  LEFT JOIN public.dependent_profiles d ON d.id = a.patient_id
  LEFT JOIN public.users g ON g.id = d.guardian_id
  WHERE a.id = ANY (p_appointment_ids)
    AND (
      a.provider_id = auth.uid()
      OR a.patient_id = auth.uid()
      OR d.guardian_id = auth.uid()
      OR get_my_role() = 'admin'
      OR (a.facility_id IS NOT NULL AND is_facility_admin_of(a.facility_id))
    );
$$;

REVOKE ALL ON FUNCTION public.appointment_patient_names(UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.appointment_patient_names(UUID[]) TO authenticated;

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect exactly these rows, each ending in 'ok':
--   appointments.patient_id foreign key gone      ok
--   audit_log.patient_id foreign key gone         ok
--   trigger trg_check_appointment_patient         ok
--   trigger trg_delete_appointments_of_removed_dependant  ok
--   trigger trg_delete_appointments_of_removed_user       ok
--   policy appointments_insert_own_or_dependant   ok
--   policy appointments_select_own_or_dependant   ok
--   old policies removed                          ok
--   function appointment_patient_names            ok
--   existing appointments all valid               ok
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'appointments.patient_id foreign key gone' AS check_name,
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'appointments_patient_id_fkey') AS passed
  UNION ALL
  SELECT 2, 'audit_log.patient_id foreign key gone',
         NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'audit_log_patient_id_fkey')
  UNION ALL
  SELECT 3, 'trigger trg_check_appointment_patient',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_check_appointment_patient')
  UNION ALL
  SELECT 4, 'trigger trg_delete_appointments_of_removed_dependant',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_delete_appointments_of_removed_dependant')
  UNION ALL
  SELECT 5, 'trigger trg_delete_appointments_of_removed_user',
         EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_delete_appointments_of_removed_user')
  UNION ALL
  SELECT 6, 'policy appointments_insert_own_or_dependant',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'appointments'
                 AND policyname = 'appointments_insert_own_or_dependant')
  UNION ALL
  SELECT 7, 'policy appointments_select_own_or_dependant',
         EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'appointments'
                 AND policyname = 'appointments_select_own_or_dependant')
  UNION ALL
  SELECT 8, 'old policies removed',
         NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'appointments'
                     AND policyname IN ('Patients can book appointments', 'Patients can view own appointments'))
  UNION ALL
  SELECT 9, 'function appointment_patient_names',
         EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'appointment_patient_names')
  UNION ALL
  SELECT 10, 'existing appointments all valid',
         NOT EXISTS (SELECT 1 FROM public.appointments a
                     WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = a.patient_id)
                       AND NOT EXISTS (SELECT 1 FROM public.dependent_profiles d WHERE d.id = a.patient_id))
) checks
ORDER BY n;
