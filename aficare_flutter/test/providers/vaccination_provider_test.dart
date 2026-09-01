import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/vaccination_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> record({
    String id = 'r1',
    String vaccineName = 'BCG',
    String status = 'completed',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'vaccine_name': vaccineName,
      'vaccine_type': 'bcg',
      'date_given': '2026-01-01T09:00:00.000Z',
      'next_due_date': '2026-02-01',
      'facility': 'Clinic',
      'batch_number': 'B001',
      'administered_by': 'Nurse',
      'status': status,
      'notes': null,
    };
  }

  group('VaccinationProvider.loadRecords', () {
    test('maps records and counts completed', () async {
      fake.routeJson('/rest/v1/vaccination_records', [
        record(),
        record(id: 'r2', vaccineName: 'OPV', status: 'scheduled'),
      ]);

      final provider = VaccinationProvider();
      await provider.loadRecords('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.records, hasLength(2));
      expect(provider.completedCount, 1);

      final req =
          fake.requestsTo('GET', 'vaccination_records').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('server error leaves records empty without throwing', () async {
      fake.routeRaw(
        '/rest/v1/vaccination_records',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = VaccinationProvider();
      await provider.loadRecords('p1');

      expect(provider.records, isEmpty);
    });
  });

  group('VaccinationProvider.addRecord', () {
    test('inserts a completed record and prepends', () async {
      fake.routeJson('/rest/v1/vaccination_records', <String, dynamic>{});

      final provider = VaccinationProvider();
      final ok = await provider.addRecord(
        patientId: 'p1',
        vaccineName: 'Measles-Rubella',
        vaccineType: 'mr',
        dateGiven: DateTime.utc(2026, 8, 1),
      );

      expect(ok, isTrue);
      final insert =
          fake.requestsTo('POST', 'vaccination_records').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('vaccine_name', 'Measles-Rubella'));
      expect(body, containsPair('status', 'completed'));
      expect((body['id'] as String), isNotEmpty);

      expect(provider.records.first.vaccineName, 'Measles-Rubella');
      expect(provider.completedCount, 1);
    });

    test('failure returns false and records error', () async {
      fake.routeRaw(
        '/rest/v1/vaccination_records',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = VaccinationProvider();
      final ok = await provider.addRecord(
        patientId: 'p1',
        vaccineName: 'BCG',
        dateGiven: DateTime.utc(2026, 8, 1),
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('VaccinationProvider.getDueVaccines', () {
    test('excludes vaccines already administered by name match', () async {
      fake.routeJson('/rest/v1/vaccination_records', [
        record(vaccineName: 'BCG'),
        record(id: 'r2', vaccineName: 'OPV 1', status: 'scheduled'),
      ]);

      final provider = VaccinationProvider();
      await provider.loadRecords('p1');

      final due = provider.getDueVaccines(16);
      final dueNames = due.map((v) => v.type.toLowerCase()).toSet();
      expect(dueNames.contains('bcg'), isFalse);
      expect(dueNames.contains('opv'), isFalse);
      expect(due, isNotEmpty);

      final noRecords = VaccinationProvider();
      final allDue = noRecords.getDueVaccines(16);
      expect(allDue, isNotEmpty);
    });
  });
}
