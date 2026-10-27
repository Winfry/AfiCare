import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/pregnancy_model.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> pregnancyRow({
    String id = 'p1',
    String status = 'ongoing',
    String lmp = '2026-05-10',
    String? outcome,
    String? endedOn,
    String createdAt = '2026-07-01T08:00:00+00:00',
  }) =>
      {
        'id': id,
        'patient_id': 'u1',
        'lmp_date': lmp,
        'due_date': Pregnancy.dateOnly(Pregnancy.dueDateFromLmp(DateTime.parse(lmp))),
        'due_date_source': 'lmp',
        'status': status,
        'outcome': outcome,
        'ended_on': endedOn,
        'created_at': createdAt,
      };

  Map<String, dynamic> visitRow({String id = 'v1', String pregnancyId = 'p1', String date = '2026-08-01T09:00:00Z'}) => {
        'id': id,
        'patient_id': 'u1',
        'pregnancy_id': pregnancyId,
        'visit_number': 1,
        'gestational_weeks': 12,
        'trimester': 'first',
        'visit_date': date,
        'danger_signs': <String>[],
        'facility': '',
      };

  Map<String, dynamic> lastBody(String method, String table) =>
      jsonDecode(fake.requestsTo(method, table).last.body) as Map<String, dynamic>;

  group('load', () {
    test("finds the ongoing pregnancy, past ones, and each one's visits", () async {
      fake.routeJson('/rest/v1/pregnancies', [
        pregnancyRow(),
        pregnancyRow(id: 'p0', status: 'ended', lmp: '2024-01-01', outcome: 'birth', endedOn: '2024-10-01',
            createdAt: '2024-02-01T08:00:00+00:00'),
      ]);
      fake.routeJson('/rest/v1/anc_visits', [
        visitRow(),
        visitRow(id: 'v0', pregnancyId: 'p0', date: '2024-05-01T09:00:00Z'),
      ]);

      final provider = PregnancyProvider();
      await provider.load('u1');

      expect(provider.loaded, isTrue);
      expect(provider.error, isNull);
      expect(provider.current!.id, 'p1');
      expect(provider.past.single.id, 'p0');
      expect(provider.lastEnded!.outcome, 'birth');
      expect(provider.visitsOf(provider.current!).map((v) => v.id), ['v1']);
      expect(provider.visitsOf(provider.past.single).map((v) => v.id), ['v0']);
      expect(fake.requestsTo('GET', 'pregnancies').single.url.queryParameters['patient_id'], 'eq.u1');
    });

    test('a failed load says so instead of looking like no pregnancy', () async {
      fake.routeRaw('/rest/v1/pregnancies', http.Response('{"message":"boom"}', 500));

      final provider = PregnancyProvider();
      await provider.load('u1');

      expect(provider.loaded, isTrue);
      expect(provider.current, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('start', () {
    test('from the LMP: due date is worked out and the source is lmp', () async {
      fake.routeJson('/rest/v1/pregnancies', pregnancyRow());

      final provider = PregnancyProvider();
      final ok = await provider.start(patientId: 'u1', lmp: DateTime(2026, 5, 10));

      expect(ok, isTrue);
      expect(provider.current!.id, 'p1');
      final body = lastBody('POST', 'pregnancies');
      expect(body['patient_id'], 'u1');
      expect(body['lmp_date'], '2026-05-10');
      expect(body['due_date'], '2027-02-14');
      expect(body['due_date_source'], 'lmp');
      expect(body['status'], 'ongoing');
      expect(body.containsKey('id'), isFalse);
    });

    test('from a scan: no LMP is sent', () async {
      fake.routeJson('/rest/v1/pregnancies', {
        ...pregnancyRow(),
        'lmp_date': null,
        'due_date': '2027-02-14',
        'due_date_source': 'scan',
      });

      final provider = PregnancyProvider();
      expect(await provider.start(patientId: 'u1', dueDate: DateTime(2027, 2, 14)), isTrue);

      final body = lastBody('POST', 'pregnancies');
      expect(body['lmp_date'], isNull);
      expect(body['due_date'], '2027-02-14');
      expect(body['due_date_source'], 'scan');
    });

    test('a second ongoing pregnancy is refused with a plain reason', () async {
      fake.routeRaw(
        '/rest/v1/pregnancies',
        http.Response('{"code":"23505","message":"duplicate key value violates unique constraint"}', 409,
            headers: {'content-type': 'application/json'}),
      );

      final provider = PregnancyProvider();
      final ok = await provider.start(patientId: 'u1', lmp: DateTime(2026, 5, 10));

      expect(ok, isFalse);
      expect(provider.error, 'You already have a pregnancy in progress.');
    });

    test('a write that stored nothing is a failure, not a success', () async {
      fake.routeJson('/rest/v1/pregnancies', null);

      final provider = PregnancyProvider();
      expect(await provider.start(patientId: 'u1', lmp: DateTime(2026, 5, 10)), isFalse);
      expect(provider.current, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('end', () {
    test('sends the outcome and date, and the pregnancy moves to past', () async {
      fake.routeJson('/rest/v1/pregnancies', [pregnancyRow()]);
      fake.routeJson('/rest/v1/anc_visits', <Map<String, dynamic>>[]);
      final provider = PregnancyProvider();
      await provider.load('u1');

      fake.routeJson('/rest/v1/pregnancies',
          pregnancyRow(status: 'ended', outcome: 'not_said', endedOn: '2026-10-20'));
      final ok = await provider.end(provider.current!, outcome: 'not_said', endedOn: DateTime(2026, 10, 20));

      expect(ok, isTrue);
      final req = fake.requestsTo('PATCH', 'pregnancies').single;
      expect(req.url.queryParameters['id'], 'eq.p1');
      expect(jsonDecode(req.body), {'status': 'ended', 'outcome': 'not_said', 'ended_on': '2026-10-20'});
      expect(provider.current, isNull);
      expect(provider.past.single.outcome, 'not_said');
    });
  });

  group('addVisit', () {
    test('links the visit to the ongoing pregnancy and works out number and weeks', () async {
      fake.routeJson('/rest/v1/pregnancies', [pregnancyRow()]);
      fake.routeJson('/rest/v1/anc_visits', [visitRow()]);
      final provider = PregnancyProvider();
      await provider.load('u1');

      fake.routeJson('/rest/v1/anc_visits', {
        ...visitRow(id: 'v2', date: '2026-10-25T09:00:00Z'),
        'visit_number': 2,
        'gestational_weeks': 24,
        'trimester': 'second',
      });
      final ok = await provider.addVisit(
        visitDate: DateTime(2026, 10, 25, 12),
        systolicBP: 110,
        diastolicBP: 70,
        dangerSigns: ['Severe headache'],
      );

      expect(ok, isTrue);
      final body = lastBody('POST', 'anc_visits');
      expect(body['pregnancy_id'], 'p1');
      expect(body['patient_id'], 'u1');
      expect(body['visit_number'], 2);
      expect(body['gestational_weeks'], 24);
      expect(body['trimester'], 'second');
      expect(body['danger_signs'], ['Severe headache']);
      expect(provider.visitsOf(provider.current!).map((v) => v.id), ['v2', 'v1']);
    });

    test('without an ongoing pregnancy nothing is sent', () async {
      final provider = PregnancyProvider();
      final ok = await provider.addVisit(visitDate: DateUtils.dateOnly(DateTime.now()));

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(fake.requestsTo('POST', 'anc_visits'), isEmpty);
    });
  });
}
