-- 045: a choice of alarm on each medicine reminder.
--
-- "gentle" — the phone's normal notification sound, once (what every
--            reminder did before this).
-- "loud"   — the alarm sound, repeating until the person taps or swipes
--            the reminder away.
--
-- Saved with the reminder (not on the phone) so the choice follows the
-- account to a new phone, and a parent's choice for Brian is kept.
-- Safe to run more than once.

BEGIN;

ALTER TABLE public.medication_reminders
  ADD COLUMN IF NOT EXISTS alarm_style TEXT NOT NULL DEFAULT 'gentle';

ALTER TABLE public.medication_reminders
  DROP CONSTRAINT IF EXISTS medication_reminders_alarm_style_check;
ALTER TABLE public.medication_reminders
  ADD CONSTRAINT medication_reminders_alarm_style_check
  CHECK (alarm_style IN ('gentle', 'loud'));

COMMIT;

-- ── VERIFY ──────────────────────────────────────────────────────
-- Expect every row to end in 'ok'.
SELECT check_name, CASE WHEN passed THEN 'ok' ELSE 'PROBLEM' END AS result FROM (
  SELECT 1 AS n, 'reminders have an alarm style, gentle unless chosen' AS check_name,
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public' AND table_name = 'medication_reminders'
                   AND column_name = 'alarm_style' AND is_nullable = 'NO'
                   AND column_default LIKE '''gentle''%') AS passed
  UNION ALL
  SELECT 2, 'only gentle or loud can be saved',
         EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conname = 'medication_reminders_alarm_style_check'
                   AND conrelid = 'public.medication_reminders'::regclass)
  UNION ALL
  SELECT 3, 'existing reminders kept their gentle sound',
         NOT EXISTS (SELECT 1 FROM public.medication_reminders
                     WHERE alarm_style IS DISTINCT FROM 'gentle'
                       AND alarm_style IS DISTINCT FROM 'loud')
) checks
ORDER BY n;
