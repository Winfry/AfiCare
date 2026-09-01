import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/triage_model.dart';
import 'package:aficare_flutter/providers/triage_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> assessmentRow({
    String id = 'a1',
    String patientId = 'p1',
    String providerId = 'prov-1',
    String assessedAt = '2026-05-02T09:00:00.000Z',
    String chiefComplaint = 'Fever',
    String triageLevel = 'urgent',
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'consultation_id': null,
      'assessed_at': assessedAt,
      'chief_complaint': chiefComplaint,
      'symptoms': ['fever'],
      'triage_level': triageLevel,
      'temperature': 38.5,
      'systolic_bp': 120,
      'diastolic_bp': 80,
      'heart_rate': 90,
      'respiratory_rate': 20,
      'oxygen_saturation': 96,
      'weight': 70.0,
      'notes': null,
    };
  }

  group('TriageProvider.loadAssessments', () {
    test('populates assessments for a patient', () async {
      fake.routeJson('/rest/v1/triage_assessments', [
        assessmentRow(),
        assessmentRow(id: 'a2', chiefComplaint: 'Cough', triageLevel: 'non_urgent'),
      ]);

      final provider = TriageProvider();
      await provider.loadAssessments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.assessments, hasLength(2));
      expect(provider.assessments.first.patientId, 'p1');
      expect(provider.assessments.first.triageLevel, TriageLevel.urgent);
      expect(provider.assessments.last.chiefComplaint, 'Cough');
    });

    test('empty response leaves an empty list without error', () async {
      fake.routeJson('/rest/v1/triage_assessments', <Object?>[]);

      final provider = TriageProvider();
      await provider.loadAssessments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.assessments, isEmpty);
    });

    test('server error sets error and stops loading', () async {
      fake.routeRaw(
        '/rest/v1/triage_assessments',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = TriageProvider();
      await provider.loadAssessments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.assessments, isEmpty);
    });
  });

  group('TriageProvider.submitAssessment', () {
    test('inserts the exact schema columns and prepends locally', () async {
      fake.routeJson('/rest/v1/triage_assessments', <String, dynamic>{});

      final provider = TriageProvider();
      final assessment = TriageAssessment(
        id: 'new-1',
        patientId: 'p1',
        providerId: 'prov-1',
        assessedAt: DateTime.utc(2026, 5, 2, 9, 0),
        chiefComplaint: 'Abdominal pain',
        symptoms: const ['pain'],
        triageLevel: TriageLevel.nonUrgent,
        systolicBP: 110,
        diastolicBP: 70,
        notes: 'review in 48h',
      );

      final ok = await provider.submitAssessment(assessment);

      expect(ok, isTrue);
      expect(provider.error, isNull);
      expect(provider.assessments.first, same(assessment));

      final insert = fake.requestsTo('POST', 'triage_assessments').last;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;

      // The columns the A3 migration (008) must provide.
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('provider_id', 'prov-1'));
      expect(body, containsPair('assessed_at', isNotNull));
      expect(body, containsPair('chief_complaint', 'Abdominal pain'));
      expect(body, containsPair('triage_level', 'non_urgent'));
      expect(body, containsPair('symptoms', ['pain']));
      expect(body, containsPair('systolic_bp', 110));
      expect(body, containsPair('diastolic_bp', 70));
      expect(body, containsPair('notes', 'review in 48h'));
    });

    test('failure returns false and records an error', () async {
      fake.routeRaw(
        '/rest/v1/triage_assessments',
        http.Response('{"message":"constraint violation"}', 409),
      );

      final provider = TriageProvider();
      final assessment = TriageAssessment(
        id: 'new-1',
        patientId: 'p1',
        providerId: 'prov-1',
        assessedAt: DateTime.utc(2026, 5, 2),
        chiefComplaint: 'Fever',
        symptoms: const ['fever'],
        triageLevel: TriageLevel.urgent,
      );

      final ok = await provider.submitAssessment(assessment);

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.assessments, isEmpty);
    });
  });

  group('TriageProvider.getLatestAssessment', () {
    test('returns the most recent assessment for the patient', () async {
      fake.routeJson('/rest/v1/triage_assessments', [
        assessmentRow(id: 'old', assessedAt: '2026-01-01T09:00:00.000Z'),
        assessmentRow(id: 'mid', assessedAt: '2026-02-01T09:00:00.000Z'),
        assessmentRow(id: 'new', assessedAt: '2026-03-01T09:00:00.000Z'),
      ]);

      final provider = TriageProvider();
      await provider.loadAssessments('p1');

      expect(provider.getLatestAssessment('p1')?.id, 'new');
    });

    test('returns null when the patient has no assessments', () async {
      final provider = TriageProvider();
      expect(provider.getLatestAssessment('p1'), isNull);
    });
  });
}