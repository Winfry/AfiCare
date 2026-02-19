-- ============================================================
-- Migration 001: Facilities table + PWD & facility_id columns
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Health facilities table
CREATE TABLE IF NOT EXISTS facilities (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    type        TEXT NOT NULL DEFAULT 'clinic'
                    CHECK (type IN ('hospital', 'clinic', 'health_centre', 'dispensary', 'nursing_home', 'other')),
    county      TEXT,
    sub_county  TEXT,
    address     TEXT,
    phone       TEXT,
    email       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast name lookups
CREATE INDEX IF NOT EXISTS idx_facilities_name ON facilities (name);
CREATE INDEX IF NOT EXISTS idx_facilities_county ON facilities (county);

-- 2. Link users (providers) to a facility
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS facility_id UUID REFERENCES facilities (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_facility_id ON users (facility_id);

-- 3. PWD (Persons With Disabilities) field on patients
ALTER TABLE patients
    ADD COLUMN IF NOT EXISTS disability_type TEXT
        CHECK (disability_type IN (
            'visual', 'hearing', 'physical', 'intellectual',
            'psychosocial', 'multiple', 'other'
        ));

-- ============================================================
-- Verification queries (run after migration)
-- ============================================================
-- SELECT * FROM facilities LIMIT 1;
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'facility_id';
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'patients' AND column_name = 'disability_type';
