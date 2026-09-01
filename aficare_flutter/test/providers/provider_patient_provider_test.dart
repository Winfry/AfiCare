import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/provider_patient_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> userRow({String id = 'p1'}) {
    return {
      'id': id,
      'email': 'patient@example.com',
      'full_name': 'John Doe',
      'role': 'patient',
      'medilink_id': 'ML-000001',
      'phone': '0712345678',
      'status': 'active',
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  Map<String, dynamic> consultationRow() {
    return {
      'id': 'c1',
      'patient_id': 'p1',
      'provider_id': 'prov-1',
      'timestamp': '2026-06-01T09:00:00.000Z',
      'chief_complaint': 'Fever',
      'symptoms': ['fever'],
      'vital_signs': {'temperature': 38.0},
      'triage_level': 'non_urgent',
      'diagnoses': <Object?>[],
      'recommendations': ['Rest'],
      'notes': null,
      'follow_up_required': false,
      'follow_up_date': null,
    };
  }

  group('ProviderPatientProvider.searchPatients', () {
    test('returns matching patients', () async {
      fake.routeJson('/rest/v1/users', [
        userRow(),
        userRow(id: 'p2'),
      ]);

      final provider = ProviderPatientProvider();
      await provider.searchPatients('doe');

      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, hasLength(2));
      expect(provider.searchResults.first['full_name'], 'John Doe');

      final req = fake.requestsTo('GET', 'users').single;
      expect(req.url.queryParameters['role'], 'eq.patient');
      expect(req.url.queryParameters['or'], isNotNull);
    });

    test('clears results for an empty query without calling the API', () async {
      final provider = ProviderPatientProvider();
      await provider.searchPatients('');

      expect(provider.searchResults, isEmpty);
      expect(fake.requestsTo('GET', 'users'), isEmpty);
    });

    test('records an error on failure', () async {
      fake.routeRaw(
        '/rest/v1/users',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = ProviderPatientProvider();
      await provider.searchPatients('doe');

      expect(provider.isSearching, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('ProviderPatientProvider.loadPatientDetail', () {
    test('loads profile plus sub-resources', () async {
      final patientRow = userRow();
      patientRow['date_of_birth'] = '1990-01-01';
      patientRow['blood_type'] = 'O+';
      patientRow['allergies'] = <Object?>[];
      patientRow['chronic_conditions'] = <Object?>[];

      fake.routeJson('/rest/v1/users', patientRow);
      fake.routeJson('/rest/v1/patients', patientRow);
      fake.routeJson('/rest/v1/consultations', [consultationRow()]);
      fake.routeJson('/rest/v1/triage_assessments', <Object?>[]);
      fake.routeJson('/rest/v1/lab_orders', <Object?>[]);
      fake.routeJson('/rest/v1/radiology_orders', <Object?>[]);
      fake.routeJson('/rest/v1/prescriptions', <Object?>[]);
      fake.routeJson('/rest/v1/referrals', <Object?>[]);

      final provider = ProviderPatientProvider();
      await provider.loadPatientDetail('p1');

      expect(provider.isLoadingPatient, isFalse);
      expect(provider.error, isNull);
      expect(provider.patientProfile, isNotNull);
      expect(provider.patientProfile!['full_name'], 'John Doe');
      expect(provider.consultations, hasLength(1));
      expect(provider.triageAssessments, isEmpty);
      expect(provider.labOrders, isEmpty);
      expect(provider.radiologyOrders, isEmpty);
      expect(provider.prescriptions, isEmpty);
      expect(provider.referrals, isEmpty);
    });

    test('records an error when the profile query fails', () async {
      fake.routeRaw(
        '/rest/v1/users',
        http.Response('{"message":"not found"}', 404),
      );

      final provider = ProviderPatientProvider();
      await provider.loadPatientDetail('p1');

      expect(provider.isLoadingPatient, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('ProviderPatientProvider.clear', () {
    test('resets all loaded state', () async {
      final provider = ProviderPatientProvider();
      provider.clear();

      expect(provider.searchResults, isEmpty);
      expect(provider.patientProfile, isNull);
      expect(provider.consultations, isEmpty);
      expect(provider.triageAssessments, isEmpty);
      expect(provider.labOrders, isEmpty);
      expect(provider.radiologyOrders, isEmpty);
      expect(provider.prescriptions, isEmpty);
      expect(provider.referrals, isEmpty);
    });
  });
}
