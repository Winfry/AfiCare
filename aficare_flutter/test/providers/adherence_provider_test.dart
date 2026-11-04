import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/adherence_model.dart';
import 'package:aficare_flutter/providers/adherence_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> dose({
    String id = 'd1',
    String status = 'pending',
    String scheduled = '2026-08-01T08:00:00.000Z',
  }) {
    return {
      'id': id,
      'prescription_id': 'rx1',
      'patient_id': 'p1',
      'scheduled_time': scheduled,
      'taken_time': null,
      'skipped_reason': null,
      'status': status,
      'noted_at': '2026-08-01T08:00:00.000Z',
      'prescriptions': {'medication_name': 'Metformin', 'dosage': '500mg'},
    };
  }

  group('AdherenceProvider.today', () {
    test('loadToday maps doses and computes score', () async {
      fake.routeJson('/rest/v1/adherence_log', [
        dose(id: 'd1', status: 'taken'),
        dose(id: 'd2', status: 'pending'),
        dose(id: 'd3', status: 'pending'),
      ]);

      final provider = AdherenceProvider();
      await provider.loadToday('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.today, hasLength(3));
      expect(provider.todayDoses, hasLength(3));
      expect(provider.todayScore, 33);
      expect(provider.todayRemaining, 2);
      expect(provider.today.first.medicationName, 'Metformin');
    });

    test('todayScore is zero when empty', () async {
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);

      final provider = AdherenceProvider();
      await provider.loadToday('p1');

      expect(provider.todayScore, 0);
      expect(provider.todayRemaining, 0);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/adherence_log',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AdherenceProvider();
      await provider.loadToday('p1');

      expect(provider.error, isNotNull);
      expect(provider.today, isEmpty);
    });
  });

  group('AdherenceProvider.history', () {
    test('loadHistory computes rate, totals and missed doses', () async {
      fake.routeJson('/rest/v1/adherence_log', [
        dose(id: 'h1', status: 'taken', scheduled: '2026-07-30T08:00:00.000Z'),
        dose(id: 'h2', status: 'taken', scheduled: '2026-07-30T13:00:00.000Z'),
        dose(id: 'h3', status: 'skipped', scheduled: '2026-07-29T08:00:00.000Z'),
      ]);

      final provider = AdherenceProvider();
      await provider.loadHistory('p1');

      expect(provider.history, hasLength(3));
      expect(provider.historyRate, 67);
      expect(provider.historyTaken, 2);
      expect(provider.historyTotal, 3);
      expect(provider.missedDoses, hasLength(1));
    });

    test('historyRate is zero without resolved doses', () async {
      fake.routeJson('/rest/v1/adherence_log', [
        dose(id: 'h1', status: 'pending'),
      ]);

      final provider = AdherenceProvider();
      await provider.loadHistory('p1');

      expect(provider.historyRate, 0);
      expect(provider.historyTotal, 0);
    });
  });

  group('AdherenceProvider.markStatus', () {
    test('updates a today dose to taken', () async {
      fake.routeJson('/rest/v1/adherence_log', [dose(status: 'pending')]);

      final provider = AdherenceProvider();
      await provider.loadToday('p1');

      final ok = await provider.markStatus('d1', AdherenceStatus.taken);
      expect(ok, isTrue);

      final update = fake.requestsTo('PATCH', 'adherence_log').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('status', 'taken'));
      expect(update.url.queryParameters['id'], 'eq.d1');

      expect(provider.today.single.status, AdherenceStatus.taken);
      expect(provider.todayScore, 100);
    });

    test('records skipped reason', () async {
      fake.routeJson('/rest/v1/adherence_log', [dose(status: 'pending')]);

      final provider = AdherenceProvider();
      await provider.loadToday('p1');

      final ok = await provider.markStatus(
        'd1',
        AdherenceStatus.skipped,
        reason: 'side effect',
      );
      expect(ok, isTrue);

      final body =
          jsonDecode(fake.requestsTo('PATCH', 'adherence_log').single.body)
              as Map<String, dynamic>;
      expect(body, containsPair('status', 'skipped'));
      expect(body, containsPair('skipped_reason', 'side effect'));
      expect(provider.today.single.status, AdherenceStatus.skipped);
    });
  });

  group('AdherenceProvider.addMedication', () {
    test('creates prescription, doses and reloads today', () async {
      fake.routeJson('/rest/v1/prescriptions', {
        'id': 'rx-new',
        'patient_id': 'p1',
      });
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);

      final provider = AdherenceProvider();
      final ok = await provider.addMedication(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        timesPerDay: 2,
        instructions: 'with food',
      );

      expect(ok, AddMedicationResult.added);

      final rxInsert = fake.requestsTo('POST', 'prescriptions').single;
      final rxBody = jsonDecode(rxInsert.body) as Map<String, dynamic>;
      expect(rxBody, containsPair('medication_name', 'Ibuprofen'));
      expect(rxBody, containsPair('provider_id', 'p1'));
      expect(rxBody, containsPair('status', 'active'));

      final doseInsert = fake.requestsTo('POST', 'adherence_log').single;
      final doseBody = jsonDecode(doseInsert.body) as List;
      expect(doseBody, hasLength(2));
    });

    test('twice a day is 12 hours apart', () async {
      fake.routeJson('/rest/v1/prescriptions', {'id': 'rx-new', 'patient_id': 'p1'});
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);

      await AdherenceProvider().addMedication(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        timesPerDay: 2,
      );

      final doses = jsonDecode(fake.requestsTo('POST', 'adherence_log').single.body) as List;
      expect(doses.map((d) => DateTime.parse(d['scheduled_time'] as String).hour), [8, 20]);
    });

    for (final (times, hours) in [
      (5, [6, 10, 14, 18, 22]),
      (6, [6, 10, 14, 18, 22, 2]),
    ]) {
      test('$times times a day saves, with $times doses spread across the day', () async {
        fake.routeJson('/rest/v1/prescriptions', {'id': 'rx-new', 'patient_id': 'p1'});
        fake.routeJson('/rest/v1/adherence_log', <Object?>[]);

        final result = await AdherenceProvider().addMedication(
          patientId: 'p1',
          medicationName: 'Salbutamol',
          dosage: '2 puffs',
          timesPerDay: times,
        );

        expect(result, AddMedicationResult.added);
        final rx = jsonDecode(fake.requestsTo('POST', 'prescriptions').single.body) as Map;
        expect(rx['frequency'], '$times times a day');
        final doses = jsonDecode(fake.requestsTo('POST', 'adherence_log').single.body) as List;
        expect(doses.map((d) => DateTime.parse(d['scheduled_time'] as String).hour), hours);
        expect(doses.every((d) => d['prescription_id'] == 'rx-new' && d['status'] == 'pending'), isTrue);
      });
    }

    test('every choice from 1 to 6 saves', () async {
      for (var times = 1; times <= 6; times++) {
        fake.reset();
        fake.routeJson('/rest/v1/prescriptions', {'id': 'rx-$times', 'patient_id': 'p1'});
        fake.routeJson('/rest/v1/adherence_log', <Object?>[]);
        final result = await AdherenceProvider().addMedication(
          patientId: 'p1',
          medicationName: 'Medicine',
          dosage: '1 tablet',
          timesPerDay: times,
        );
        expect(result, AddMedicationResult.added, reason: '$times a day');
        final doses = jsonDecode(fake.requestsTo('POST', 'adherence_log').single.body) as List;
        expect(doses, hasLength(times));
      }
    });

    test('if the medicine cannot be saved, nothing is saved and she is told plainly', () async {
      fake.routeRaw(
        '/rest/v1/prescriptions',
        http.Response('{"message":"denied"}', 403, headers: {'content-type': 'application/json'}),
      );

      final provider = AdherenceProvider();
      final result = await provider.addMedication(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        timesPerDay: 2,
      );

      expect(result, AddMedicationResult.failed);
      expect(fake.requestsTo('POST', 'adherence_log'), isEmpty, reason: 'no doses for a medicine that was not saved');
      expect(provider.error, contains("couldn't add this medicine"));
      expect(provider.error, isNot(contains('denied')));
    });

    test("if today's doses cannot be saved, it tries again, then says the medicine is saved without them", () async {
      fake.routeJson('/rest/v1/prescriptions', {'id': 'rx-new', 'patient_id': 'p1'});
      fake.routeRaw('/rest/v1/adherence_log',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));

      final result = await AdherenceProvider().addMedication(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        timesPerDay: 5,
      );

      expect(result, AddMedicationResult.addedDosesLater);
      expect(fake.requestsTo('POST', 'prescriptions'), hasLength(1), reason: 'the medicine is saved once');
      expect(fake.requestsTo('POST', 'adherence_log'), hasLength(2), reason: 'tried twice');
    });

    test('the doses that could not be saved are added the next time the tracker loads', () async {
      fake.routeJson('/rest/v1/prescriptions', [
        {'id': 'rx-new', 'frequency': '5 times a day', 'status': 'active'},
      ]);
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);
      await AdherenceProvider().ensureTodayDoses('p1');
      final doses = jsonDecode(fake.requestsTo('POST', 'adherence_log').single.body) as List;
      expect(doses, hasLength(5));
    });
  });

  group('AdherenceProvider.markStatus confirmation', () {
    test('a change the database did not make is a failure, and nothing changes on screen', () async {
      fake.routeJson('/rest/v1/adherence_log', [dose(status: 'pending')]);
      final provider = AdherenceProvider();
      await provider.loadToday('p1');
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);

      final ok = await provider.markStatus('d1', AdherenceStatus.taken);

      expect(ok, isFalse);
      expect(provider.today.single.status, AdherenceStatus.pending);
      expect(provider.error, contains("couldn't save that"));
    });
  });

  group('AdherenceProvider.ensureTodayDoses', () {
    /// The dose rows made for each prescription, as clock hours.
    Future<Map<String, List<int>>> dosesFor(List<Map<String, String>> prescriptions) async {
      fake.routeJson('/rest/v1/prescriptions', prescriptions);
      fake.routeJson('/rest/v1/adherence_log', <Object?>[]);
      await AdherenceProvider().ensureTodayDoses('p1');
      final posts = fake.requestsTo('POST', 'adherence_log');
      final made = <String, List<int>>{};
      for (final post in posts) {
        for (final d in jsonDecode(post.body) as List) {
          made
              .putIfAbsent(d['prescription_id'] as String, () => [])
              .add(DateTime.parse(d['scheduled_time'] as String).hour);
        }
      }
      return made;
    }

    test('a doctor\'s shorthand gives the right number of doses today', () async {
      final made = await dosesFor([
        {'id': 'tds', 'frequency': 'TDS', 'status': 'active'},
        {'id': 'bd', 'frequency': 'BD', 'status': 'active'},
        {'id': 'q8', 'frequency': 'every 8 hours', 'status': 'active'},
        {'id': 'od', 'frequency': 'Once daily', 'status': 'active'},
        {'id': 'prn', 'frequency': 'PRN', 'status': 'active'},
      ]);
      expect(made['tds'], [8, 14, 20]);
      expect(made['bd'], [8, 20]);
      expect(made['q8'], [8, 14, 20], reason: 'every 8 hours is 3 doses, not 4');
      expect(made['od'], [8]);
      expect(made.containsKey('prn'), isFalse, reason: 'as-needed medicine has no fixed doses');
    });

    test('nothing is added when today\'s doses already exist', () async {
      fake.routeJson('/rest/v1/prescriptions', [
        {'id': 'tds', 'frequency': 'TDS', 'status': 'active'},
      ]);
      fake.routeJson('/rest/v1/adherence_log', [
        {'prescription_id': 'tds'},
      ]);
      await AdherenceProvider().ensureTodayDoses('p1');
      expect(fake.requestsTo('POST', 'adherence_log'), isEmpty);
    });
  });
}
