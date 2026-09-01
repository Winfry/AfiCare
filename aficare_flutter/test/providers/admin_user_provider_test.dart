import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/admin_user_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> userRow({
    String id = 'u1',
    String fullName = 'Jane Doe',
    String email = 'jane@example.com',
    String role = 'doctor',
    String status = 'active',
    String? medilinkId,
  }) {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'status': status,
      'medilink_id': medilinkId,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('AdminUserProvider filters and selection', () {
    test('filteredUsers applies role, status and search', () async {
      fake.routeJson('/rest/v1/users', [
        userRow(),
        userRow(
          id: 'u2',
          fullName: 'John Smith',
          role: 'patient',
          status: 'suspended',
          medilinkId: 'ML-000001',
        ),
        userRow(id: 'u3', fullName: 'Ann Lee', role: 'nurse', status: 'active'),
      ]);

      final provider = AdminUserProvider();
      await provider.loadUsers();

      provider.setRoleFilter('doctor');
      expect(provider.filteredUsers.map((u) => u.id), ['u1']);

      provider.setStatusFilter('active');
      provider.setRoleFilter('all');
      expect(provider.filteredUsers.map((u) => u.id), ['u1', 'u3']);

      provider.setSearchQuery('john');
      provider.setStatusFilter('all');
      expect(provider.filteredUsers.map((u) => u.id), ['u2']);
    });

    test('selection toggles and clears', () async {
      final provider = AdminUserProvider();
      provider.toggleSelection('u1');
      provider.toggleSelection('u2');
      expect(provider.selectedIds, {'u1', 'u2'});
      provider.toggleSelection('u1');
      expect(provider.selectedIds, {'u2'});
      provider.clearSelection();
      expect(provider.selectedIds, isEmpty);
    });
  });

  group('AdminUserProvider.loadUsers', () {
    test('maps rows and sets users', () async {
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = AdminUserProvider();
      await provider.loadUsers();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.users, hasLength(1));
      expect(provider.users.first.role, UserRole.doctor);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/users',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AdminUserProvider();
      await provider.loadUsers();

      expect(provider.error, isNotNull);
      expect(provider.users, isEmpty);
    });
  });

  group('AdminUserProvider.updateUserRole', () {
    test('patches role and reloads', () async {
      fake.routeJson('/rest/v1/users', [
        userRow(id: 'u1', role: 'admin'),
      ]);

      final provider = AdminUserProvider();
      final ok = await provider.updateUserRole('u1', UserRole.admin);

      expect(ok, isTrue);
      final update = fake.requestsTo('PATCH', 'users').single;
      expect(jsonDecode(update.body), containsPair('role', 'admin'));
      expect(provider.users.single.role, UserRole.admin);
    });
  });

  group('AdminUserProvider.inviteUser', () {
    test('inserts an invited user and reloads', () async {
      fake.routeJson('/rest/v1/users', [userRow(id: 'u1', role: 'chw')]);

      final provider = AdminUserProvider();
      final ok = await provider.inviteUser(
        email: 'new@example.com',
        fullName: 'New Person',
        role: UserRole.chw,
      );

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'users').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('email', 'new@example.com'));
      expect(body, containsPair('role', 'chw'));
      expect(body, containsPair('status', 'invited'));
    });
  });

  group('AdminUserProvider.resetPassword', () {
    test('calls auth recover for a user with email', () async {
      fake.routeJson('/rest/v1/users', [userRow()]);
      fake.routeJson('/auth/v1/recover', <String, dynamic>{});

      final provider = AdminUserProvider();
      await provider.loadUsers();

      final ok = await provider.resetPassword('u1');
      expect(ok, isTrue);
      expect(fake.requestsTo('POST', 'recover'), isNotEmpty);
    });

    test('fails when the user has no email', () async {
      final provider = AdminUserProvider();
      final ok = await provider.resetPassword('missing');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
