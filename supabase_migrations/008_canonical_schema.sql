-- ============================================================
-- 008_canonical_schema.sql
-- A3: Canonical schema migration
--
-- Drops and recreates the feature tables so the live database
-- matches EXACTLY what the Flutter app ACTUALLY reads and writes.
-- Column names/types/CHECK value-sets below were derived directly
-- from the app's models, providers and screen insert/select/order
-- calls (see audit). Applying this migration aligns the live DB
-- with the current app code so Triage, Referrals, CHW households,
-- visits and screenings all continue to work.
--
-- WARNING: This is DESTRUCTIVE. Back up existing rows before
-- applying. Run this in the Supabase SQL Editor.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------------
-- CHW / community worker tables (match active app code paths)
-- ------------------------------------------------------------------

-- References: active code uses `chv_id`, not `chw_id`
DROP TABLE IF EXISTS public.chv_households CASCADE;
DROP TABLE IF EXISTS public.households CASCADE;

CREATE TABLE IF NOT EXISTS public.households (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  household_name text,
  location text,
  village text,
  sub_county text,
  county text,
  total_members integer DEFAULT 0,
  children_under_5 integer DEFAULT 0,
  pregnant_women integer DEFAULT 0,
  elderly_members integer DEFAULT 0,
  chronically_ill integer DEFAULT 0,
  gps_coordinates text,
  water_source text,
  sanitation_type text,
  has_mosquito_nets boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

DROP TABLE IF EXISTS public.chv_visits CASCADE;
CREATE TABLE IF NOT EXISTS public.chv_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  household_id uuid REFERENCES public.households (id) ON DELETE SET NULL,
  patient_id text,
  visit_type text,
  visit_date timestamptz DEFAULT now(),
  vitals jsonb,
  systolic_bp integer,
  diastolic_bp integer,
  weight numeric,
  temperature numeric,
  flags jsonb,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Community screenings: `results` is a jsonb detail map; `outcome`
-- includes referred / referral_needed values used by the app
DROP TABLE IF EXISTS public.community_screenings CASCADE;
CREATE TABLE IF NOT EXISTS public.community_screenings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  household_id uuid,
  patient_id text,
  screening_date timestamptz DEFAULT now(),
  screening_type text,
  results jsonb,
  outcome text CHECK (outcome IN ('normal', 'referral_needed', 'referred', 'follow_up')) DEFAULT 'normal',
  referred_to text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Referrals
-- ------------------------------------------------------------------
DROP TABLE IF EXISTS public.referrals CASCADE;
CREATE TABLE IF NOT EXISTS public.referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text,
  from_provider_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  from_facility text,
  to_provider_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  to_facility text,
  to_department text,
  to_specialist text,
  to_specialty text,
  reason text,
  clinical_notes text,
  urgency text CHECK (urgency IN ('routine', 'urgent', 'emergency')) DEFAULT 'routine',
  status text CHECK (status IN ('pending', 'accepted', 'completed', 'declined', 'closed', 'rejected')) DEFAULT 'pending',
  notes text,
  responded_at timestamptz,
  response_notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Triage assessments
-- Flat vital columns match the app model and insert calls.
-- ------------------------------------------------------------------
DROP TABLE IF EXISTS public.triage_assessments CASCADE;
CREATE TABLE IF NOT EXISTS public.triage_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text,
  provider_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  assessed_by uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  consultation_id text,
  assessed_at timestamptz DEFAULT now(),
  chief_complaint text,
  symptoms jsonb,
  triage_level text CHECK (triage_level IN ('emergency', 'urgent', 'non_urgent')),
  temperature numeric,
  systolic_bp integer,
  diastolic_bp integer,
  heart_rate integer,
  respiratory_rate integer,
  oxygen_saturation numeric,
  weight numeric,
  vitals jsonb,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Patient modules (TEXT primary key = medilink_id style)
-- NOTE: Not currently referenced by the Flutter app. Kept as-is.
-- ------------------------------------------------------------------
DROP TABLE IF EXISTS public.patient_modules CASCADE;
CREATE TABLE IF NOT EXISTS public.patient_modules (
  module_id text PRIMARY KEY,
  patient_id text,
  module_name text NOT NULL,
  status text DEFAULT 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Users role check (extended to permit `chw`)
-- ------------------------------------------------------------------
DROP TRIGGER IF EXISTS handle_users_role_check ON public.users;
CREATE OR REPLACE FUNCTION public.users_role_check()
RETURNS trigger AS $$
BEGIN
  IF NEW.role NOT IN ('patient', 'doctor', 'nurse', 'admin', 'chw') THEN
    RAISE EXCEPTION 'invalid role: %', NEW.role;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_role_check
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.users_role_check();

COMMIT;
