import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/care_team_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> teamRow({
    String id = 'ct1',
    String patientId = 'p1',
    String providerId = 'prov-1',
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'specialty_label': 'Cardiologist',
      'notes': null,
      'is_primary': true,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  Map<String, dynamic> userRow({String id = 'prov-1'}) {
    return {
      'id': id,
      'full_name': 'Dr. Jane',
      'role': 'doctor',
      'department': 'Cardiology',
      'gender': 'female',
      'email': 'jane@example.com',
      'status': 'active',
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('CareTeamProvider.loadCareTeam', () {
    test('joins provider details into members', () async {
      fake.routeJson('/rest/v1/care_team', [teamRow()]);
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = CareTeamProvider();
      await provider.loadCareTeam('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.members, hasLength(1));
      expect(provider.members.first.providerName, 'Dr. Jane');
      expect(provider.members.first.providerRole, 'doctor');
      expect(provider.members.first.isPrimary, isTrue);
    });

    test('empty team leaves empty list without querying users', () async {
      fake.routeJson('/rest/v1/care_team', <Object?>[]);
      fake.routeJson('/rest/v1/users', <Object?>[]);

      final provider = CareTeamProvider();
      await provider.loadCareTeam('p1');

      expect(provider.members, isEmpty);
      expect(provider.error, isNull);
      // Only the care_team query should have been made.
      expect(fake.requestsTo('GET', 'users'), isEmpty);
    });

    test('server error sets an error', () async {
      fake.routeRaw(
        '/rest/v1/care_team',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = CareTeamProvider();
      await provider.loadCareTeam('p1');

      expect(provider.members, isEmpty);
      expect(provider.error, isNotNull);
    });
  });

  group('CareTeamProvider.addMember', () {
    test('inserts a member and reloads team and suggestions', () async {
      fake.routeJson('/rest/v1/care_team', <Object?>[]);
      fake.routeJson('/rest/v1/users', <Object?>[]);
      fake.routeJson('/rest/v1/appointments', <Object?>[]);

      final provider = CareTeamProvider();
      final ok = await provider.addMember(
        'p1',
        'prov-2',
        specialtyLabel: 'Neurologist',
        isPrimary: false,
      );

      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'care_team').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('provider_id', 'prov-2'));
      expect(body, containsPair('specialty_label', 'Neurologist'));
      expect(body, containsPair('is_primary', false));
    });
  });

  group('CareTeamProvider.removeMember', () {
    test('deletes the row by id', () async {
      fake.routeJson('/rest/v1/care_team', <Object?>[]);
      fake.routeJson('/rest/v1/users', <Object?>[]);
      fake.routeJson('/rest/v1/appointments', <Object?>[]);

      final provider = CareTeamProvider();
      final ok = await provider.removeMember('ct1', 'p1');

      expect(ok, isTrue);
      final del = fake.requestsTo('DELETE', 'care_team').single;
      expect(del.url.queryParameters['id'], 'eq.ct1');
    });
  });

  group('CareTeamProvider.updateLabel', () {
    test('patches the specialty label', () async {
      fake.routeJson('/rest/v1/care_team', <Object?>[]);
      fake.routeJson('/rest/v1/users', <Object?>[]);

      final provider = CareTeamProvider();
      final ok = await provider.updateLabel('ct1', 'p1', 'Endocrinologist');

      expect(ok, isTrue);
      final update = fake.requestsTo('PATCH', 'care_team').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('specialty_label', 'Endocrinologist'));
    });
  });
}
