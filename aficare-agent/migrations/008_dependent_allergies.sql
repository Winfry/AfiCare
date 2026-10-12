-- ── Migration 008: Allergies on dependent profiles ──────────────────────────
-- Run after 007_fix_users_rls_recursion.sql
--
-- WHY
-- `patients` has carried an allergies array since the beginning, but
-- `dependent_profiles` never did. The patient app therefore had nowhere
-- to record that a child is allergic to penicillin, and Health Records
-- fell back to showing the *guardian's* allergy list beside the child's
-- chart — a record that blends two people, which is more dangerous than
-- one that is simply missing.
--
-- This adds the column so a dependant's allergies can be recorded
-- against the dependant. Purely additive: no existing column, row,
-- policy or index is altered, and existing rows default to an empty
-- array (meaning "none recorded yet", which the app distinguishes from
-- "unknown").
--
-- Mirrors patients.allergies, which is TEXT[].

ALTER TABLE dependent_profiles
  ADD COLUMN IF NOT EXISTS allergies TEXT[] NOT NULL DEFAULT '{}'::TEXT[];

COMMENT ON COLUMN dependent_profiles.allergies IS
  'Known allergies for this dependant. Empty array means none recorded; '
  'never treat it as a clinical confirmation of no allergies.';

-- RLS: nothing to add. `guardian_all_dependents` and `admin_all_dependents`
-- are FOR ALL on the whole row, so the new column is already covered by
-- the existing policies.
