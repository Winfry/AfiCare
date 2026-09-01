import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/triage_model.dart';
import 'package:aficare_flutter/models/referral_model.dart';

/// Guards the A3 migration (008_canonical_schema.sql) stay aligned with the
/// columns the app models actually write to Supabase. If a model is changed to
/// use different DB column names than the migration provides, these tests:
///   1. verify the model round-trips its own toJson/fromJson, and
///   2. pin down the exact DB column names the migration must define.
void main() {
  group('TriageAssessment DB schema alignment (008)', () {
    test('toJson emits flat columns the 008 migration now defines', () {
      final assessment = TriageAssessment(
        id: 't1',
        patientId: 'p1',
        providerId: 'prov-1',
        consultationId: 'c1',
        assessedAt: DateTime.utc(2026, 5, 2, 9, 0),
        chiefComplaint: 'Fever',
        symptoms: const ['fever', 'cough'],
        triageLevel: TriageLevel.urgent,
        temperature: 38.5,
        systolicBP: 120,
        diastolicBP: 80,
        heartRate: 90,
        respiratoryRate: 20,
        oxygenSaturation: 96,
        weight: 70.0,
        notes: 'review in 24h',
      );

      final json = assessment.toJson();

      // Columns written by the app that the A3 migration must provide.
      expect(json, containsPair('patient_id', 'p1'));
      expect(json, containsPair('provider_id', 'prov-1'));
      expect(json, containsPair('consultation_id', 'c1'));
      expect(json, containsPair('assessed_at', isA<String>()));
      expect(json, containsPair('chief_complaint', 'Fever'));
      expect(json, containsPair('symptoms', ['fever', 'cough']));
      expect(json, containsPair('triage_level', 'urgent'));
      expect(json, containsPair('systolic_bp', 120));
      expect(json, containsPair('diastolic_bp', 80));
      expect(json, containsPair('heart_rate', 90));
      expect(json, containsPair('respiratory_rate', 20));
      expect(json, containsPair('oxygen_saturation', 96.0));
      expect(json, containsPair('temperature', 38.5));
      expect(json, containsPair('weight', 70.0));

      // The app's triage level vocabulary (NOT green/yellow/red).
      expect(assessment.triageLevel, TriageLevel.urgent);

      final restored = TriageAssessment.fromJson(json);
      expect(restored.chiefComplaint, 'Fever');
      expect(restored.systolicBP, 120);
      expect(restored.triageLevel, TriageLevel.urgent);
      expect(restored.symptoms, ['fever', 'cough']);
    });

    test('maps all triage levels the migration CHECK must allow', () {
      final roundTrip = TriageAssessment(
        id: 't2',
        patientId: 'p1',
        providerId: 'prov-1',
        assessedAt: DateTime.utc(2026, 1, 1),
        chiefComplaint: 'c',
        symptoms: const [],
        triageLevel: TriageLevel.nonUrgent,
      );
      expect(roundTrip.toJson()['triage_level'], 'non_urgent');
      expect(TriageAssessment.fromJson(roundTrip.toJson()).triageLevel,
          TriageLevel.nonUrgent);
    });
  });

  group('ReferralModel DB schema alignment (008)', () {
    test('toJson emits columns the 008 migration now defines', () {
      final referral = ReferralModel(
        id: 'r1',
        patientId: 'p1',
        fromProviderId: 'prov-1',
        fromFacility: 'Clinic A',
        toFacility: 'Hospital B',
        toDepartment: 'Cardiology',
        toSpecialist: 'Dr. X',
        reason: 'Chest pain',
        clinicalNotes: 'referred for echo',
        urgency: ReferralUrgency.urgent,
        status: ReferralStatus.pending,
        createdAt: DateTime.utc(2026, 4, 1),
        respondedAt: DateTime.utc(2026, 4, 2),
        responseNotes: 'accepted',
      );

      final json = referral.toJson();

      // Columns written by the app that the A3 migration must provide.
      expect(json, containsPair('urgency', 'urgent'));
      expect(json, containsPair('from_facility', 'Clinic A'));
      expect(json, containsPair('to_department', 'Cardiology'));
      expect(json, containsPair('to_specialist', 'Dr. X'));
      expect(json, containsPair('clinical_notes', 'referred for echo'));
      expect(json, containsPair('responded_at', isA<String>()));
      expect(json, containsPair('response_notes', 'accepted'));
      expect(json, containsPair('status', 'pending'));

      final restored = ReferralModel.fromJson(json);
      expect(restored.urgency, ReferralUrgency.urgent);
      expect(restored.toSpecialist, 'Dr. X');
      expect(restored.responseNotes, 'accepted');
    });

    test('status vocabulary is compatible with the migration CHECK', () {
      // All statuses the app can write must be allowed by the 008 CHECK.
      for (final s in ReferralStatus.values) {
        final referral = ReferralModel(
          id: 'r',
          patientId: 'p',
          fromProviderId: 'prov',
          toFacility: 'f',
          reason: 'r',
          status: s,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final written = referral.toJson()['status'] as String;
        // The migration CHECK allows: pending, accepted, completed,
        // declined, closed, rejected.
        expect(
          ['pending', 'accepted', 'completed', 'declined', 'closed', 'rejected'],
          contains(written),
          reason: 'status value $written must be allowed by the 008 CHECK',
        );
      }
    });

    test('urgency vocabulary is compatible with the migration CHECK', () {
      for (final u in ReferralUrgency.values) {
        final referral = ReferralModel(
          id: 'r',
          patientId: 'p',
          fromProviderId: 'prov',
          toFacility: 'f',
          reason: 'r',
          urgency: u,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        expect(
          ['routine', 'urgent', 'emergency'],
          contains(referral.toJson()['urgency'] as String),
          reason: 'urgency value must be allowed by the 008 CHECK',
        );
      }
    });
  });
}
