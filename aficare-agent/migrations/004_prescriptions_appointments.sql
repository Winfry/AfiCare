-- ============================================================
-- 004: Prescriptions & Appointments
-- ============================================================

-- ── prescriptions ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS prescriptions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id     UUID        NOT NULL REFERENCES users(id),
  consultation_id UUID        REFERENCES consultations(id),
  medication_name TEXT        NOT NULL,
  dosage          TEXT        NOT NULL,
  frequency       TEXT        NOT NULL,
  duration        TEXT        NOT NULL,
  instructions    TEXT,
  status          TEXT        NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'completed', 'cancelled')),
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;

-- Patient reads their own prescriptions
CREATE POLICY "patient_read_own_prescriptions"
  ON prescriptions FOR SELECT
  USING (
    patient_id IN (
      SELECT id FROM patients WHERE id = auth.uid()
    )
  );

-- Provider reads prescriptions for their patients
CREATE POLICY "provider_read_prescriptions"
  ON prescriptions FOR SELECT
  USING (get_my_role() IN ('doctor', 'nurse', 'admin'));

-- Provider inserts prescriptions
CREATE POLICY "provider_insert_prescriptions"
  ON prescriptions FOR INSERT
  WITH CHECK (
    provider_id = auth.uid()
    AND get_my_role() IN ('doctor', 'nurse')
  );

-- Provider updates their own prescriptions
CREATE POLICY "provider_update_prescriptions"
  ON prescriptions FOR UPDATE
  USING (
    provider_id = auth.uid()
    AND get_my_role() IN ('doctor', 'nurse')
  );

-- Admin full access
CREATE POLICY "admin_all_prescriptions"
  ON prescriptions FOR ALL
  USING (get_my_role() = 'admin');

-- ── appointments ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS appointments (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id       UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id      UUID        NOT NULL REFERENCES users(id),
  facility_id      UUID        REFERENCES facilities(id),
  scheduled_at     TIMESTAMPTZ NOT NULL,
  duration_minutes INT         NOT NULL DEFAULT 30,
  type             TEXT        NOT NULL DEFAULT 'in-person'
                               CHECK (type IN ('in-person', 'telehealth')),
  status           TEXT        NOT NULL DEFAULT 'pending'
                               CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  chief_complaint  TEXT,
  notes            TEXT,
  is_follow_up     BOOLEAN     NOT NULL DEFAULT FALSE,
  consultation_id  UUID        REFERENCES consultations(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Patient reads their own appointments
CREATE POLICY "patient_read_own_appointments"
  ON appointments FOR SELECT
  USING (
    patient_id IN (
      SELECT id FROM patients WHERE id = auth.uid()
    )
  );

-- Patient inserts appointments (booking)
CREATE POLICY "patient_insert_appointments"
  ON appointments FOR INSERT
  WITH CHECK (
    patient_id IN (
      SELECT id FROM patients WHERE id = auth.uid()
    )
  );

-- Patient cancels their own pending/confirmed appointments
CREATE POLICY "patient_cancel_appointments"
  ON appointments FOR UPDATE
  USING (
    patient_id IN (
      SELECT id FROM patients WHERE id = auth.uid()
    )
    AND status IN ('pending', 'confirmed')
  );

-- Provider reads appointments assigned to them
CREATE POLICY "provider_read_appointments"
  ON appointments FOR SELECT
  USING (
    provider_id = auth.uid()
    AND get_my_role() IN ('doctor', 'nurse')
  );

-- Provider inserts follow-up appointments
CREATE POLICY "provider_insert_appointments"
  ON appointments FOR INSERT
  WITH CHECK (
    provider_id = auth.uid()
    AND get_my_role() IN ('doctor', 'nurse')
  );

-- Provider updates status of their appointments
CREATE POLICY "provider_update_appointments"
  ON appointments FOR UPDATE
  USING (
    provider_id = auth.uid()
    AND get_my_role() IN ('doctor', 'nurse')
  );

-- Admin full access
CREATE POLICY "admin_all_appointments"
  ON appointments FOR ALL
  USING (get_my_role() = 'admin');

-- ── indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_id   ON prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_provider_id  ON prescriptions(provider_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_issued_at    ON prescriptions(issued_at DESC);

CREATE INDEX IF NOT EXISTS idx_appointments_patient_id    ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_provider_id   ON appointments(provider_id);
CREATE INDEX IF NOT EXISTS idx_appointments_scheduled_at  ON appointments(scheduled_at DESC);
