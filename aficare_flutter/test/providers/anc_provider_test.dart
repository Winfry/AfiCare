import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/anc_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> visit({
    String id = 'v1',
    int visitNumber = 1,
    int gestationalWeeks = 20,
    String visitDate = '2026-08-01T09:00:00.000Z',
    List<String> dangerSigns = const [],
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'visit_number': visitNumber,
      'gestational_weeks': gestationalWeeks,
      'trimester': 'second',
      'visit_date': visitDate,
      'fundal_height': 22.0,
      'fetal_heart_rate': 140,
      'systolic_bp': 110,
      'diastolic_bp': 70,
      'weight': 68.0,
      'hemoglobin': 12.5,
      'urine_protein': null,
      'urine_glucose': null,
      'hiv_tested': true,
      'hiv_result': 'negative',
      'notes': null,
      'danger_signs': dangerSigns,
      'next_visit_date': null,
      'facility': 'Clinic A',
    };
  }

  group('AncProvider.loadVisits', () {
    test('maps visits and reads LMP from patient notes', () async {
      final lmp = DateTime
          .utc(2026, 6, 1)
          .toIso8601String();
      fake.routeJson('/rest/v1/anc_visits', [visit()]);
      fake.routeJson('/rest/v1/patients', {
        'id': 'p1',
        'date_of_birth': '1990-01-01',
        'notes': 'lmp: $lmp;',
      });

      final provider = AncProvider();
      await provider.loadVisits('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.visits, hasLength(1));
      expect(provider.completedVisits, 1);
      expect(provider.lastMenstrualPeriod, isNotNull);

      final req = fake.requestsTo('GET', 'anc_visits').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('no LMP yields zero gestational weeks', () async {
      fake.routeJson('/rest/v1/anc_visits', [visit()]);
      fake.routeJson('/rest/v1/patients', {
        'id': 'p1',
        'date_of_birth': '1990-01-01',
        'notes': null,
      });

      final provider = AncProvider();
      await provider.loadVisits('p1');

      expect(provider.currentGestationalWeeks, 0);
      expect(provider.expectedVisitCount, 0);
    });
  });

  group('AncProvider pregnancy metrics', () {
    test('currentGestationalWeeks and trimester reflect LMP', () async {
      final provider = AncProvider();
      provider.setLMP('p1', DateTime.utc(2026, 1, 1));

      final weeks = provider.currentGestationalWeeks;
      expect(provider.currentTrimester,
          weeks <= 27 ? 'second' : 'third');
      expect(provider.estimatedDueDate, DateTime.utc(2026, 10, 8));
      expect(provider.expectedVisitCount, (weeks / 4).ceil());
    });

    test('activeDangerSigns come from the most recent visit', () async {
      fake.routeJson('/rest/v1/anc_visits', [
        visit(
          id: 'v2',
          visitNumber: 2,
          visitDate: '2026-08-01T09:00:00.000Z',
          dangerSigns: ['Vaginal bleeding'],
        ),
        visit(
          id: 'v1',
          visitNumber: 1,
          visitDate: '2026-07-01T09:00:00.000Z',
          dangerSigns: ['Fever > 38°C'],
        ),
      ]);
      // injure the LMP so visit list drives the metrics
      fake.routeJson('/rest/v1/patients', {
        'id': 'p1',
        'date_of_birth': '1990-01-01',
        'notes': null,
      });

      final provider = AncProvider();
      await provider.loadVisits('p1');

      expect(provider.visits.first.visitNumber, 2);
      expect(provider.activeDangerSigns, ['Vaginal bleeding']);
    });
  });

  group('AncProvider.addVisit', () {
    test('inserts a visit with generated id and prepends', () async {
      fake.routeJson('/rest/v1/anc_visits', <String, dynamic>{});

      final provider = AncProvider();
      final ok = await provider.addVisit(
        patientId: 'p1',
        visitNumber: 1,
        gestationalWeeks: 20,
        visitDate: DateTime.utc(2026, 8, 1),
        weight: 68.0,
        hivTested: true,
        dangerSigns: ['Fever > 38°C'],
      );

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'anc_visits').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('gestational_weeks', 20));
      expect(body, containsPair('trimester', 'second'));
      expect((body['id'] as String), isNotEmpty);

      expect(provider.visits.first.visitNumber, 1);
      expect(provider.visits.first.dangerSigns, ['Fever > 38°C']);
    });

    test('failure returns false and records error', () async {
      fake.routeRaw(
        '/rest/v1/anc_visits',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = AncProvider();
      final ok = await provider.addVisit(
        patientId: 'p1',
        visitNumber: 1,
        gestationalWeeks: 20,
        visitDate: DateTime.utc(2026, 8, 1),
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
