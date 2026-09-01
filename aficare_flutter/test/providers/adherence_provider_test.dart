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

      expect(ok, isTrue);

      final rxInsert = fake.requestsTo('POST', 'prescriptions').single;
      final rxBody = jsonDecode(rxInsert.body) as Map<String, dynamic>;
      expect(rxBody, containsPair('medication_name', 'Ibuprofen'));
      expect(rxBody, containsPair('provider_id', 'p1'));
      expect(rxBody, containsPair('status', 'active'));

      final doseInsert = fake.requestsTo('POST', 'adherence_log').single;
      final doseBody = jsonDecode(doseInsert.body) as List;
      expect(doseBody, hasLength(2));
    });

    test('failure returns false', () async {
      fake.routeRaw(
        '/rest/v1/prescriptions',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = AdherenceProvider();
      final ok = await provider.addMedication(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        timesPerDay: 2,
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
