# AfiCare MediLink

AfiCare MediLink is a patient-owned healthcare records and care-coordination
platform for Kenya. It's a Flutter app backed by Supabase, with role-based
portals for patients, healthcare providers (doctors, nurses, radiologists),
community health workers (CHWs), and administrators.

> **Note:** This repo also contains `aficare-agent/`, an earlier Python/
> Streamlit AI triage prototype. It is **legacy and no longer active** — see
> [aficare-agent/README.md](aficare-agent/README.md). The current app's AI
> consultation logic (`MedicalAIService`) runs fully offline/local-only
> inside the Flutter app and does not depend on it.

## 🌟 Features

- **Patient records patients own**: MediLink ID (QR-shareable), health
  summary, dependent profiles for family members without their own login
- **Appointments & care team**: booking, rescheduling, provider directory
- **Clinical tools**: prescriptions, lab results, radiology, triage,
  referrals, adherence monitoring
- **Preventive & maternal care**: vaccinations, antenatal care (ANC),
  mental health screening (PHQ-9/GAD-7), men's health
- **Medication support**: reminders, adherence tracking, drug-interaction
  checking, cost tracking
- **Financial**: expense tracking, receipt uploads, insurance claims
- **Community health**: CHW household registry, home visits, screening,
  education, referrals
- **Admin**: user & facility management, provider license verification,
  system settings, audit log, analytics
- **Accessibility**: text-to-speech, adjustable text scale, reduced motion,
  disability (PWD) profiles
- **Localization**: English and Swahili
- **Offline-capable**: Hive-backed local cache

## 🏗️ Architecture

- **Frontend**: Flutter (Android, iOS, Web) — `aficare_flutter/`
- **State management**: `provider` (`ChangeNotifier`)
- **Routing**: `go_router`, with role-gated redirects per portal
- **Backend**: Supabase (Postgres + Row-Level Security + Edge Functions) —
  no custom server. Schema and RLS policies live in `supabase_migrations/`.
- **Offline storage**: Hive

## 🚀 Quick Start

```bash
cd aficare_flutter
flutter pub get
flutter run
```

Copy `.env.example` to `.env` and fill in your Supabase project URL and
anon key (used by `aficare_flutter/lib/config/supabase_config.dart`).

### Local dev via Docker

```bash
docker compose up --build   # serves the Flutter web build on :8080
```

### Database

Apply the migrations in `supabase_migrations/` in order (008 onward is the
current, actively maintained schema) via the Supabase SQL editor or CLI.

## 📖 Documentation

Notes on past RLS/schema fixes and troubleshooting live in [`docs/`](docs/).

## ⚠️ Medical Disclaimer

AfiCare MediLink is designed to support patients and healthcare providers and should not replace professional medical judgment. Always consult with qualified healthcare professionals for medical decisions.
