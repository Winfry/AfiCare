import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/patient_provider.dart';

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
    String patientId = 'p1',
    String timestamp = '2026-06-01T09:00:00.000Z',
    String? followUp,
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': 'prov-1',
      'timestamp': timestamp,
      'chief_complaint': 'Fever',
      'symptoms': ['fever'],
      'vital_signs': {'temperature': 38.2, 'systolic_bp': 120},
      'triage_level': 'less_urgent',
      'diagnoses': <Object?>[],
      'recommendations': ['Rest'],
      'notes': null,
      'follow_up_required': followUp != null,
      'follow_up_date': followUp,
    };
  }

  group('PatientProvider.loadConsultations', () {
    test('maps rows for the patient', () async {
      fake.routeJson('/rest/v1/consultations', [
        consultationRow(),
        consultationRow(
          id: 'c2',
          timestamp: '2026-06-01T11:00:00.000Z',
          followUp: '2026-06-08T09:00:00.000Z',
        ),
      ]);

      final provider = PatientProvider();
      await provider.loadConsultations('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.consultations, hasLength(2));
      expect(provider.consultations.first.chiefComplaint, 'Fever');

      final req = fake.requestsTo('GET', 'consultations').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('empty response leaves empty list', () async {
      fake.routeJson('/rest/v1/consultations', <Object?>[]);

      final provider = PatientProvider();
      await provider.loadConsultations('p1');

      expect(provider.consultations, isEmpty);
      expect(provider.error, isNull);
    });

    test('server error sets error and stops loading', () async {
      fake.routeRaw(
        '/rest/v1/consultations',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = PatientProvider();
      await provider.loadConsultations('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('PatientProvider.getHealthStats', () {
    test('computes totals and follow-ups from consultations', () async {
      fake.routeJson('/rest/v1/consultations', [
        consultationRow(followUp: '2026-06-08T09:00:00.000Z'),
      ]);

      final provider = PatientProvider();
      await provider.loadConsultations('p1');

      final stats = provider.getHealthStats();
      expect(stats['totalVisits'], 1);
      expect(stats['lastVisit'], DateTime.parse('2026-06-01T09:00:00.000Z'));
      expect(stats['followUpsNeeded'], 1);
    });
  });
}
