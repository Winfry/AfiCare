import 'dart:convert';

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

  group('PatientProvider.generateAccessCode', () {
    test('inserts an access code and returns it', () async {
      fake.routeJson('/rest/v1/access_codes', <String, dynamic>{});

      final provider = PatientProvider();
      final code = await provider.generateAccessCode(
        patientId: 'p1',
        hoursValid: 4,
        permissions: const ['view'],
      );

      expect(code, isNotNull);
      expect(code!.length, 8);

      final insert = fake.requestsTo('POST', 'access_codes').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('permissions', ['view']));
      expect(body, containsPair('is_used', false));
    });

    test('failure returns null and records error', () async {
      fake.routeRaw(
        '/rest/v1/access_codes',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = PatientProvider();
      final code = await provider.generateAccessCode(
        patientId: 'p1',
        hoursValid: 4,
        permissions: const [],
      );

      expect(code, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('PatientProvider.verifyAccessCode', () {
    test('returns the joined patient detail on match', () async {
      fake.routeJson('/rest/v1/access_codes', {
        'id': 'ac1',
        'code': 'ABC12345',
        'patients': {'id': 'p1'},
      });

      final provider = PatientProvider();
      final result = await provider.verifyAccessCode('ABC12345');

      expect(result, isNotNull);
      expect((result!['patients'] as Map)['id'], 'p1');

      final req = fake.requestsTo('GET', 'access_codes').single;
      expect(req.url.queryParameters['code'], 'eq.ABC12345');
    });

    test('returns null on server error', () async {
      fake.routeRaw(
        '/rest/v1/access_codes',
        http.Response('{"message":"not found"}', 404),
      );

      final provider = PatientProvider();
      expect(await provider.verifyAccessCode('NOPE'), isNull);
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
