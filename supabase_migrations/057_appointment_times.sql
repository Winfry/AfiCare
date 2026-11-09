-- ================================================================
-- 057: Step 4d-4 — appointment times stored 3 hours late
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Run once the 4d-4 app update is live. Safe to run more than once:
-- the shift is recorded and never applied twice.
--
-- WHY
--   appointments.scheduled_at is TIMESTAMPTZ (an exact moment), but the
--   app sent the clock time with no timezone ("2026-11-10T10:00:00").
--   The database reads that as UTC, so a 10:00 visit in Nairobi was
--   stored as 13:00 Nairobi time. The app read it back the same wrong
--   way, so it looked right on screen, but anything else — the coming
--   SMS reminders, "is this visit over yet?" checks — was 3 hours off.
--
--   The app now sends UTC and shows local time, so existing rows are
--   moved back 3 hours (Kenya is UTC+3 all year, no summer time).
--   Only the app writes appointment times (the reschedule function
--   passes the app's time straight through), so every row is affected
--   the same way.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.data_fixes_applied (
  name        TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  rows_changed INTEGER
);
ALTER TABLE public.data_fixes_applied ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.data_fixes_applied FROM anon, authenticated;

DO $$
DECLARE
  v_rows INTEGER;
BEGIN
  IF EXISTS (SELECT 1 FROM public.data_fixes_applied WHERE name = '057_appointment_times') THEN
    RAISE NOTICE '057 already applied; nothing changed';
    RETURN;
  END IF;

  UPDATE public.appointments
  SET scheduled_at = scheduled_at - INTERVAL '3 hours';
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  INSERT INTO public.data_fixes_applied (name, rows_changed)
  VALUES ('057_appointment_times', v_rows);
END $$;

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT 'appointment times moved back 3 hours (once)' AS check_name,
       CASE WHEN count(*) = 1 THEN 'ok — ' || max(rows_changed) || ' appointments'
            ELSE 'MISSING' END AS result
FROM public.data_fixes_applied
WHERE name = '057_appointment_times';
