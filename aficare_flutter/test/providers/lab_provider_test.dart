import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/lab_model.dart';
import 'package:aficare_flutter/providers/lab_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> orderRow({
    String id = 'o1',
    String patientId = 'p1',
    String status = 'ordered',
    Map<String, dynamic>? result,
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': 'prov-1',
      'consultation_id': null,
      'test_name': 'CBC',
      'test_category': 'hematology',
      'priority': 'routine',
      'status': status,
      'ordered_at': '2026-06-01T09:00:00.000Z',
      'notes': null,
      'lab_results': result != null ? [result] : <Object?>[],
    };
  }

  group('LabProvider.loadOrders', () {
    test('maps orders including an embedded critical result', () async {
      fake.routeJson('/rest/v1/lab_orders', [
        orderRow(),
        orderRow(
          id: 'o2',
          status: 'completed',
          result: {
            'id': 'lr1',
            'lab_order_id': 'o2',
            'result_value': '2.0',
            'result_flag': 'critical',
          },
        ),
      ]);

      final provider = LabProvider();
      await provider.loadOrders('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.orders, hasLength(2));
      expect(provider.pending, hasLength(1));
      expect(provider.completed, hasLength(1));
      expect(provider.critical, hasLength(1));
      expect(provider.hasCritical, isTrue);

      final req = fake.requestsTo('GET', 'lab_orders').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('empty response leaves empty list', () async {
      fake.routeJson('/rest/v1/lab_orders', <Object?>[]);

      final provider = LabProvider();
      await provider.loadOrders('p1');

      expect(provider.orders, isEmpty);
      expect(provider.hasCritical, isFalse);
      expect(provider.error, isNull);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/lab_orders',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = LabProvider();
      await provider.loadOrders('p1');

      expect(provider.error, isNotNull);
      expect(provider.orders, isEmpty);
    });
  });

  group('LabProvider.createOrder', () {
    test('inserts without id and reloads', () async {
      fake.routeJson('/rest/v1/lab_orders', <String, dynamic>{});

      final provider = LabProvider();
      final order = LabOrderModel(
        id: 'o-new',
        patientId: 'p1',
        providerId: 'prov-1',
        testName: 'Malaria',
        testCategory: 'parasitology',
        orderedAt: DateTime.utc(2026, 6, 1),
      );

      final ok = await provider.createOrder(order);
      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'lab_orders').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body, containsPair('test_name', 'Malaria'));
      expect(body, containsPair('priority', 'routine'));
    });

    test('failure returns false', () async {
      fake.routeRaw(
        '/rest/v1/lab_orders',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = LabProvider();
      final order = LabOrderModel(
        id: 'o-new',
        patientId: 'p1',
        providerId: 'prov-1',
        testName: 'Malaria',
        orderedAt: DateTime.utc(2026, 6, 1),
      );

      expect(await provider.createOrder(order), isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
