-- Provisional/Intern Provider Verification -- recognizes graduated
-- medical/dental interns (real, KMPDC-registered, but not yet FULLY
-- licensed) as a legitimate category, rather than requiring every
-- provider to have a full license number before they can be onboarded.
--
-- Modeled as an ORTHOGONAL FLAG (is_provisional), not a new UserRole
-- value -- confirmed via full audit of every UserRole.doctor/.nurse
-- usage in the app that only 2 files gate real permissions on role
-- (router.dart, login_screen.dart); a provisional doctor still needs to
-- do everything a UserRole.doctor can do (chart, prescribe under
-- supervision) -- what differs is trust tier, not capability. A new
-- enum value would also risk silently demoting anyone to 'patient' via
-- UserModel's role-parsing orElse fallback if not updated in lockstep
-- everywhere at once.
--
-- license_number is relaxed because KMPDC genuinely publishes NO
-- registration number for interns (confirmed by fetching
-- registers.kmpdc.go.ke's actual intern register pages directly --
-- they list only Full Name, Postal Address, Cadre and Course, nothing
-- resembling an ID). Verifying a provisional applicant against KMPDC
-- can only ever be a name match, not an ID pattern match like the
-- fully-licensed doctor/dentist flow -- this is a real, honest
-- limitation, not something to paper over.
--
-- Also fixes an adjacent, pre-existing bug directly relevant to this
-- population: provider_credentials.provider_id is UNIQUE with no
-- UPDATE policy at all, so a rejected applicant's resubmission (which
-- provider_verification_request_screen.dart's UI already assumes is
-- possible) would silently fail against a raw .insert(). The new
-- policy below allows a user to move their OWN row from rejected back
-- to pending -- never lets anyone touch an already-pending/verified
-- row, and never lets anyone set verification_status = 'verified'
-- themselves (that stays exclusively admin_verify_provider_license's
-- job).

BEGIN;

ALTER TABLE public.provider_credentials ADD COLUMN IF NOT EXISTS is_provisional BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.provider_credentials ALTER COLUMN license_number DROP NOT NULL;
ALTER TABLE public.provider_credentials ADD CONSTRAINT license_number_required_unless_provisional
  CHECK (license_number IS NOT NULL OR is_provisional = true);

CREATE POLICY "provider_credentials_resubmit_own" ON public.provider_credentials
FOR UPDATE
USING (provider_id = auth.uid() AND verification_status = 'rejected')
WITH CHECK (provider_id = auth.uid() AND verification_status = 'pending');

ALTER TABLE public.kmpdc_practitioners DROP CONSTRAINT IF EXISTS kmpdc_practitioners_cadre_check;
ALTER TABLE public.kmpdc_practitioners ADD CONSTRAINT kmpdc_practitioners_cadre_check
  CHECK (cadre IN ('medical_doctor', 'dentist', 'medical_intern', 'dental_intern'));
ALTER TABLE public.kmpdc_practitioners ALTER COLUMN masked_registration_no DROP NOT NULL;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- A provisional submission with no license number succeeds:
--   INSERT INTO provider_credentials (provider_id, requested_role, is_provisional)
--   VALUES (auth.uid(), 'doctor', true); -- succeeds, license_number NULL
--
-- A non-provisional submission with no license number still fails:
--   INSERT INTO provider_credentials (provider_id, requested_role, is_provisional)
--   VALUES ('<other-user-id>', 'doctor', false); -- fails the CHECK
--
-- A rejected applicant can resubmit their own row to pending:
--   -- (as that same user, after an admin has set their row to 'rejected')
--   UPDATE provider_credentials SET verification_status = 'pending', license_number = 'NEW-INFO'
--   WHERE provider_id = auth.uid(); -- succeeds
--
-- ...but cannot self-verify via that same path:
--   UPDATE provider_credentials SET verification_status = 'verified'
--   WHERE provider_id = auth.uid(); -- fails (WITH CHECK requires 'pending')
--
-- kmpdc_practitioners accepts the two new cadres:
--   INSERT INTO kmpdc_practitioners (cadre, full_name) VALUES ('medical_intern', 'Test Intern');
--   -- succeeds, masked_registration_no NULL
-- ================================================================
