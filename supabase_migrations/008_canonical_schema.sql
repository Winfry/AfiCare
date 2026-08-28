-- ============================================================
-- 008_canonical_schema.sql
-- A3: Canonical schema migration
--
-- Drops and recreates the feature tables so the live database
-- matches EXACTLY what the Flutter app ACTUALLY writes to.
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
  head_name text,
  location text,
  member_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

DROP TABLE IF EXISTS public.chv_visits CASCADE;
CREATE TABLE IF NOT EXISTS public.chv_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  household_id uuid REFERENCES public.households (id) ON DELETE SET NULL,
  patient_id text,
  visit_date date DEFAULT CURRENT_DATE,
  vitals jsonb,
  systolic_bp integer,
  diastolic_bp integer,
  weight numeric,
  temperature numeric,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Community screenings: `outcome` includes referral_needed
DROP TABLE IF EXISTS public.community_screenings CASCADE;
CREATE TABLE IF NOT EXISTS public.community_screenings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chv_id uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  patient_id text,
  screening_date date DEFAULT CURRENT_DATE,
  screening_type text,
  result text,
  outcome text CHECK (outcome IN ('normal', 'referral_needed', 'follow_up')) DEFAULT 'normal',
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
  to_provider_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  to_facility text,
  reason text,
  status text CHECK (status IN ('pending', 'accepted', 'completed', 'declined')) DEFAULT 'pending',
  priority text CHECK (priority IN ('routine', 'urgent', 'emergency')) DEFAULT 'routine',
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Triage assessments
-- ------------------------------------------------------------------
DROP TABLE IF EXISTS public.triage_assessments CASCADE;
CREATE TABLE IF NOT EXISTS public.triage_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text,
  assessed_by uuid REFERENCES auth.users (id) ON DELETE CASCADE,
  triage_level text CHECK (triage_level IN ('green', 'yellow', 'orange', 'red', 'urgent')),
  symptoms jsonb,
  vitals jsonb,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- ------------------------------------------------------------------
-- Patient modules (use TEXT primary key = medilink_id style)
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
