import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aficare_flutter/models/consultation_patient_model.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  group('before looking anyone up', () {
    test('an empty ID is refused', () {
      expect(ConsultationPatient.problemWith('  '), contains('MediLink ID'));
    });

    test("a dependant's ID says plainly that it isn't available yet", () {
      expect(ConsultationPatient.problemWith('ml-dep-123456'), contains("aren't available yet"));
    });

    test('a normal MediLink ID can be looked up', () {
      expect(ConsultationPatient.problemWith('ML-NBO-123456'), isNull);
    });
  });

  group('find', () {
    test('by MediLink ID: upper-cased, patients only, and the account id comes back', () async {
      fake.routeJson('/rest/v1/users', {
        'id': '1b2c3d4e-0000-4000-8000-000000000001',
        'full_name': 'Mary Wanjiru',
        'medilink_id': 'ML-NBO-123456',
        'gender': 'female',
      });
      fake.routeJson('/rest/v1/patients', {'date_of_birth': '1992-03-04'});

      final (patient, problem) = await ConsultationPatient.find(Supabase.instance.client, ' ml-nbo-123456 ');

      expect(problem, isNull);
      expect(patient!.id, '1b2c3d4e-0000-4000-8000-000000000001');
      expect(patient.label, 'Mary Wanjiru · ML-NBO-123456');
      expect(patient.ageOn(DateTime(2026, 10, 27)), 34);
      final q = fake.requestsTo('GET', 'users').single.url.queryParameters;
      expect(q['medilink_id'], 'eq.ML-NBO-123456');
      expect(q['role'], 'eq.patient');
    });

    test('by account id, when opened from the patient record', () async {
      fake.routeJson('/rest/v1/users', {
        'id': '1b2c3d4e-0000-4000-8000-000000000001',
        'full_name': 'Mary Wanjiru',
        'medilink_id': 'ML-NBO-123456',
      });

      final (patient, _) =
          await ConsultationPatient.find(Supabase.instance.client, '1b2c3d4e-0000-4000-8000-000000000001');

      expect(patient!.medilinkId, 'ML-NBO-123456');
      expect(fake.requestsTo('GET', 'users').single.url.queryParameters['id'],
          'eq.1b2c3d4e-0000-4000-8000-000000000001');
    });

    test('nobody with that ID: a clear reason, and no patient', () async {
      fake.routeJson('/rest/v1/users', <Map<String, dynamic>>[]);

      final (patient, problem) = await ConsultationPatient.find(Supabase.instance.client, 'ML-NBO-000000');

      expect(patient, isNull);
      expect(problem, contains('No patient has the MediLink ID ML-NBO-000000'));
    });

    test("a dependant's ID is never looked up", () async {
      final (patient, problem) = await ConsultationPatient.find(Supabase.instance.client, 'ML-DEP-123456');

      expect(patient, isNull);
      expect(problem, isNotNull);
      expect(fake.requests, isEmpty);
    });
  });
}
