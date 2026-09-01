import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/config/supabase_config.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() async {
    fake.reset();
    // Clear any session persisted by an earlier test so each test starts
    // signed-out and a fresh `AuthProvider()` reads no stale session.
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  });

  const userId = 'user-1';
  const phone = '+254712345678';
  const pin = '123456';
  final pinHash = BCrypt.hashpw(pin, BCrypt.gensalt(logRounds: 4));

  Map<String, dynamic> userRow() => {
        'id': userId,
        'email': '${phone.replaceAll('+', '')}@patient.aficare',
        'full_name': 'Test Patient',
        'role': 'patient',
        'phone': phone,
        'medilink_id': 'ML-NBO-123456',
        'pin_hash': pinHash,
        'created_at': '2026-01-01T00:00:00.000Z',
      };

  /// A valid GoTrue session response for a password sign-in.
  Map<String, dynamic> sessionJson() => {
        'access_token': 'test-access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': 4102444800,
        'refresh_token': 'test-refresh-token',
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': '${phone.replaceAll('+', '')}@patient.aficare',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00.000Z',
        },
      };

  String expectedDerivedPassword() {
    const input = '$phone:$pin:${SupabaseConfig.patientAuthSecret}';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 32);
  }

  group('AuthProvider.signInWithPhoneAndPin', () {
    test('accepts a valid PIN and completes a full sign-in', () async {
      fake.routeJson('/rest/v1/users', [userRow()]);
      fake.routeJson('/auth/v1/token', sessionJson());

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(
        phone: phone,
        pin: pin,
      );

      expect(ok, isTrue);
      expect(provider.error, isNull);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser?.id, userId);
      expect(provider.currentUser?.role.name, 'patient');

      // The Supabase auth password must be the deterministic derivation.
      final tokenBody = jsonDecode(
        fake.requestsTo('POST', 'auth/v1/token').last.body,
      ) as Map<String, dynamic>;
      expect(tokenBody['email'], '${phone.replaceAll('+', '')}@patient.aficare');
      expect(tokenBody['password'], expectedDerivedPassword());
    });

    test('rejects a wrong PIN before contacting auth', () async {
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(
        phone: phone,
        pin: '000000',
      );

      expect(ok, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, contains('Invalid phone number or PIN'));
      // No auth token call should have been made for a bad PIN.
      expect(fake.requestsTo('POST', 'auth/v1/token'), isEmpty);
    });

    test('unknown phone number returns false with a helpful error', () async {
      fake.routeJson('/rest/v1/users', <Object?>[]);

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(
        phone: '+254700000000',
        pin: pin,
      );

      expect(ok, isFalse);
      expect(provider.error, contains('No account found'));
    });
  });

  group('AuthProvider.signInWithMedilinkId', () {
    test('resolves the email from the users table and signs in', () async {
      fake.routeJson('/rest/v1/users', [userRow()]);
      fake.routeJson('/auth/v1/token', sessionJson());

      final provider = AuthProvider();
      final ok = await provider.signInWithMedilinkId(
        medilinkId: 'ML-NBO-123456',
        password: 'dummy-password',
      );

      expect(ok, isTrue);
      expect(provider.currentUser?.id, userId);
    });

    test('returns false instead of throwing when no user matches', () async {
      // `.maybeSingle()` on an empty result must not throw; the old code used
      // `.single()` which raised a PostgrestException.
      fake.routeJson('/rest/v1/users', <Object?>[]);

      final provider = AuthProvider();
      final ok = await provider.signInWithMedilinkId(
        medilinkId: 'ML-NBO-999999',
        password: 'whatever',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Invalid MediLink ID or password');
      expect(fake.requestsTo('POST', 'auth/v1/token'), isEmpty);
    });
  });

  group('AuthProvider.signIn', () {
    test('sets the current user from the users profile row', () async {
      fake.routeJson('/auth/v1/token', sessionJson());
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = AuthProvider();
      final ok = await provider.signIn(
        email: '${phone.replaceAll('+', '')}@patient.aficare',
        password: 'whatever',
      );

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser?.fullName, 'Test Patient');
      expect(provider.currentUser?.medilinkId, 'ML-NBO-123456');
    });

    test('auth failure is reported through `error` without crashing', () async {
      fake.routeRaw(
        '/auth/v1/token',
        http.Response(
          '{"error":"invalid_credentials","msg":"Invalid login credentials"}',
          400,
        ),
      );

      final provider = AuthProvider();
      final ok = await provider.signIn(
        email: 'nobody@aficare.test',
        password: 'wrong-password',
      );

      expect(ok, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('AuthProvider.signOut', () {
    test('clears the current user even if the remote call fails', () async {
      fake.routeJson('/auth/v1/token', sessionJson());
      fake.routeJson('/rest/v1/users', [userRow()]);
      fake.routeRaw(
        '/auth/v1/logout',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AuthProvider();
      await provider.signIn(
        email: '${phone.replaceAll('+', '')}@patient.aficare',
        password: 'whatever',
      );
      expect(provider.isLoggedIn, isTrue);

      await provider.signOut();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.currentUser, isNull);
    });
  });
}