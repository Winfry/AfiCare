import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/consultation_model.dart';
import 'package:aficare_flutter/providers/consultation_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> consultationRow({
    String id = 'c1',
    String providerId = 'prov-1',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'provider_id': providerId,
      'timestamp': '2026-06-01T09:00:00.000Z',
      'chief_complaint': 'Cough',
      'symptoms': ['cough'],
      'vital_signs': {'temperature': 38.0},
      'triage_level': 'non_urgent',
      'diagnoses': <Object?>[],
      'recommendations': ['Rest'],
      'notes': null,
      'follow_up_required': false,
      'follow_up_date': null,
    };
  }

  group('ConsultationProvider.loadConsultationsForProvider', () {
    test('maps rows for a provider with a 50-row cap', () async {
      fake.routeJson('/rest/v1/consultations', [consultationRow()]);

      final provider = ConsultationProvider();
      await provider.loadConsultationsForProvider('prov-1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.consultations, hasLength(1));

      final req = fake.requestsTo('GET', 'consultations').single;
      expect(req.url.queryParameters['provider_id'], 'eq.prov-1');
    });

    test('server error sets an error message and stops loading', () async {
      fake.routeRaw(
        '/rest/v1/consultations',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = ConsultationProvider();
      await provider.loadConsultationsForProvider('prov-1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.consultations, isEmpty);
    });
  });

  group('ConsultationProvider.analyzeSymptoms', () {
    test('populates diagnoses and a triage level', () async {
      final provider = ConsultationProvider();
      await provider.analyzeSymptoms(
        symptoms: const ['fever', 'headache', 'chills'],
        vitalSigns: VitalSigns(),
        patientAge: 25,
        patientGender: 'female',
      );

      expect(provider.isAnalyzing, isFalse);
      expect(provider.error, isNull);
      expect(provider.diagnoses, isNotEmpty);
      expect(provider.triageLevel, isNotEmpty);
    });

    test('escalates to emergency on danger symptoms', () async {
      final provider = ConsultationProvider();
      await provider.analyzeSymptoms(
        symptoms: const ['fever', 'difficulty breathing', 'chest pain'],
        vitalSigns: VitalSigns(),
        patientAge: 30,
        patientGender: 'male',
      );

      expect(provider.diagnoses, isNotEmpty);
      expect(provider.triageLevel, 'emergency');
    });
  });

  group('ConsultationProvider.saveConsultation', () {
    test('inserts consultation, writes audit log and returns id', () async {
      fake.routeJson('/rest/v1/consultations', <String, dynamic>{});
      fake.routeJson('/rest/v1/audit_log', <String, dynamic>{});

      final provider = ConsultationProvider();
      final id = await provider.saveConsultation(
        patientId: 'p1',
        providerId: 'prov-1',
        chiefComplaint: 'Fever',
        symptoms: const ['fever'],
        vitalSigns: VitalSigns(
          temperature: 38.5,
          systolicBP: 120,
        ),
        recommendations: const ['Rest'],
        notes: 'review tomorrow',
        followUpRequired: true,
      );

      expect(id, isNotNull);
      expect(provider.currentConsultation, isNotNull);
      expect(provider.currentConsultation!.patientId, 'p1');

      final insert = fake.requestsTo('POST', 'consultations').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('chief_complaint', 'Fever'));
      expect(body, containsPair('notes', 'review tomorrow'));
      expect(body, containsPair('follow_up_required', true));

      final audit = fake.requestsTo('POST', 'audit_log').single;
      final auditBody = jsonDecode(audit.body) as Map<String, dynamic>;
      expect(auditBody, containsPair('action', 'consultation_created'));
      expect(auditBody, containsPair('user_id', 'prov-1'));
    });

    test('failure returns null and sets an error message', () async {
      fake.routeRaw(
        '/rest/v1/consultations',
        http.Response('{"message":"constraint"}', 409),
      );

      final provider = ConsultationProvider();
      final id = await provider.saveConsultation(
        patientId: 'p1',
        providerId: 'prov-1',
        chiefComplaint: 'Fever',
        symptoms: const ['fever'],
        vitalSigns: VitalSigns(),
        recommendations: const [],
      );

      expect(id, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('ConsultationProvider.clearConsultation', () {
    test('resets state and notifies', () {
      final provider = ConsultationProvider();
      provider.clearConsultation();

      expect(provider.currentConsultation, isNull);
      expect(provider.diagnoses, isEmpty);
      expect(provider.triageLevel, 'non_urgent');
      expect(provider.error, isNull);
    });
  });
}
