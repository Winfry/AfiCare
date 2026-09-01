import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/dependent_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> dependentRow({
    String id = 'd1',
    String guardianId = 'g1',
  }) {
    return {
      'id': id,
      'guardian_id': guardianId,
      'full_name': 'Maya Doe',
      'date_of_birth': null,
      'gender': 'female',
      'relationship': 'child',
      'blood_type': null,
      'medilink_id': 'ML-DEP-000001',
      'notes': null,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('DependentProvider active-patient selection', () {
    test('setOwnId resets to own profile for a new user', () {
      final provider = DependentProvider();
      provider.setOwnId('g1');
      provider.switchTo('d1');

      provider.setOwnId('g2');
      expect(provider.ownId, 'g2');
      expect(provider.activePatientId, 'g2');
      expect(provider.dependents, isEmpty);
    });

    test('isViewingDependent and activeDependent behaviour', () {
      final provider = DependentProvider();
      expect(provider.isViewingDependent, isFalse);
      provider.setOwnId('g1');
      expect(provider.isViewingDependent, isFalse);
      expect(provider.activeDependent, isNull);
    });
  });

  group('DependentProvider.loadDependents', () {
    test('maps rows for a guardian', () async {
      fake.routeJson('/rest/v1/dependent_profiles', [dependentRow()]);

      final provider = DependentProvider();
      await provider.loadDependents('g1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.dependents, hasLength(1));
      expect(provider.dependents.first.fullName, 'Maya Doe');

      final req = fake.requestsTo('GET', 'dependent_profiles').single;
      expect(req.url.queryParameters['guardian_id'], 'eq.g1');
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/dependent_profiles',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = DependentProvider();
      await provider.loadDependents('g1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('DependentProvider.addDependent', () {
    test('inserts a dependent and reloads', () async {
      fake.routeJson('/rest/v1/dependent_profiles', <String, dynamic>{});

      final provider = DependentProvider();
      final ok = await provider.addDependent(
        guardianId: 'g1',
        fullName: 'Maya Doe',
        relationship: 'child',
        gender: 'female',
      );

      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'dependent_profiles').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('guardian_id', 'g1'));
      expect(body, containsPair('full_name', 'Maya Doe'));
      expect(body, containsPair('relationship', 'child'));
      expect(body['medilink_id'], startsWith('ML-DEP-'));
    });
  });

  group('DependentProvider.deleteDependent', () {
    test('switches back to own profile when deleting the active dependent',
        () async {
      fake.routeJson('/rest/v1/dependent_profiles', <String, dynamic>{});

      final provider = DependentProvider();
      provider.setOwnId('g1');
      provider.switchTo('d1');

      final ok = await provider.deleteDependent('d1', 'g1');

      expect(ok, isTrue);
      expect(provider.activePatientId, 'g1');

      final del = fake.requestsTo('DELETE', 'dependent_profiles').single;
      expect(del.url.queryParameters['id'], 'eq.d1');
    });
  });
}
