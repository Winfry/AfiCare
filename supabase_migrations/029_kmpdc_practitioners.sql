-- KMPDC Doctor Verification -- final item from the original facility-admin
-- mockup roadmap. A local mirror of KMPDC's own PUBLIC practitioner
-- register (registers.kmpdc.go.ke), refreshed by the sync-kmpdc-register
-- Edge Function. This is NOT an official KMPDC API relationship -- KMPDC's
-- public register masks registration numbers (e.g. "E0****2") and offers
-- no documented API; a real API requires a separate organizational
-- application directly with KMPDC. This table exists purely so an
-- on-demand facility-admin lookup doesn't have to re-fetch KMPDC's large
-- public HTML page on every single search.
--
-- Deliberately global (not facility-scoped) -- this is shared public
-- reference data, identical for every facility, like a shared dictionary.
-- Deliberately separate from provider_credentials.verification_status
-- (011_provider_verification.sql) -- that field remains the sole,
-- unchanged, platform-admin-only source of truth for whether a provider
-- is trusted on this platform. This table only ever answers "what does
-- KMPDC's public data currently say," nothing about AfiCare's own
-- internal trust state.
--
-- Scoped to medical_doctor + dentist cadres only -- the two clinically
-- relevant to provider_credentials.requested_role.

BEGIN;

CREATE TABLE IF NOT EXISTS public.kmpdc_practitioners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cadre TEXT NOT NULL CHECK (cadre IN ('medical_doctor', 'dentist')),
  full_name TEXT NOT NULL,
  masked_registration_no TEXT NOT NULL,
  qualifications TEXT,
  discipline TEXT,
  license_type TEXT,
  status TEXT,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kmpdc_practitioners_full_name ON public.kmpdc_practitioners (full_name);
CREATE INDEX IF NOT EXISTS idx_kmpdc_practitioners_cadre ON public.kmpdc_practitioners (cadre);

ALTER TABLE public.kmpdc_practitioners ENABLE ROW LEVEL SECURITY;

-- Public reference data -- readable by any signed-in AfiCare user,
-- regardless of role or facility. Writes are RPC/service-role only: no
-- INSERT/UPDATE/DELETE policy exists for anyone -- only the
-- sync-kmpdc-register Edge Function (using the service-role key, which
-- bypasses RLS entirely) can write to this table.
CREATE POLICY "kmpdc_practitioners_select_authenticated"
ON public.kmpdc_practitioners FOR SELECT
USING (true);

GRANT SELECT ON public.kmpdc_practitioners TO authenticated;

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- Any authenticated user can read (before any sync has ever run, this is
-- legitimately empty -- that's expected, not a bug):
--   SELECT count(*) FROM kmpdc_practitioners;
--
-- No client can write directly (only the Edge Function's service-role
-- key can, bypassing RLS):
--   INSERT INTO kmpdc_practitioners (cadre, full_name, masked_registration_no)
--   VALUES ('medical_doctor', 'Test Doctor', 'E0****9'); -- fails for any authenticated client
-- ================================================================
