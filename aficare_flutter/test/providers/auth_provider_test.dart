import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

  Map<String, dynamic> userRow() => {
        'id': userId,
        'email': '${phone.replaceAll('+', '')}@patient.aficare',
        'full_name': 'Test Patient',
        'role': 'patient',
        'phone': phone,
        'medilink_id': 'ML-NBO-123456',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

  /// A valid GoTrue session response for a refresh-token grant — this is
  /// what `auth.setSession(refreshToken)` requests from `/auth/v1/token`
  /// once the patient-auth Edge Function hands the client a refresh token.
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

  /// Builds the exact response shape the real `patient-auth` Edge Function
  /// returns on failure: a JSON body with an `error` field, served with a
  /// real `content-type: application/json` header (without this header the
  /// Supabase functions client falls back to treating the body as plain
  /// text, which would silently defeat these tests).
  http.Response edgeError(String message, int status) => http.Response(
        jsonEncode({'error': message}),
        status,
        headers: const {'content-type': 'application/json'},
      );

  group('AuthProvider.signInWithPhoneAndPin', () {
    test('accepts a valid PIN and completes a full sign-in', () async {
      // PIN verification now happens entirely inside the patient-auth Edge
      // Function — from the client's perspective, success just means "the
      // function returned a session".
      fake.routeJson('/functions/v1/patient-auth', {
        'access_token': 'edge-access-token',
        'refresh_token': 'test-refresh-token',
        'user_id': userId,
      });
      fake.routeJson('/auth/v1/token', sessionJson());
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(phone: phone, pin: pin);

      expect(ok, isTrue);
      expect(provider.error, isNull);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser?.id, userId);
      expect(provider.currentUser?.role.name, 'patient');

      // The client must send the raw phone+PIN to the function and nothing
      // else — it no longer knows how to check a PIN or derive a password.
      final callBody = jsonDecode(
        fake.requestsTo('post', 'functions/v1/patient-auth').single.body,
      ) as Map<String, dynamic>;
      expect(callBody['action'], 'login');
      expect(callBody['phone'], phone);
      expect(callBody['pin'], pin);

      // And it must hand the resulting refresh token to setSession — never
      // call signInWithPassword itself.
      final tokenBody = jsonDecode(
        fake.requestsTo('POST', 'auth/v1/token').single.body,
      ) as Map<String, dynamic>;
      expect(tokenBody['refresh_token'], 'test-refresh-token');
    });

    test('a wrong PIN surfaces the function\'s generic error, without minting a session', () async {
      fake.routeRaw('/functions/v1/patient-auth', edgeError('Invalid phone number or PIN.', 401));

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(phone: phone, pin: '000000');

      expect(ok, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, 'Invalid phone number or PIN.');
      expect(fake.requestsTo('POST', 'auth/v1/token'), isEmpty);
    });

    test('an unknown phone number gets the exact same error as a wrong PIN', () async {
      // The Edge Function deliberately never distinguishes "no such
      // account" from "wrong PIN" — this is what prevents a caller from
      // using this endpoint to enumerate registered phone numbers.
      fake.routeRaw('/functions/v1/patient-auth', edgeError('Invalid phone number or PIN.', 401));

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(phone: '+254700000000', pin: pin);

      expect(ok, isFalse);
      expect(provider.error, 'Invalid phone number or PIN.');
    });

    test('too many failed attempts surfaces the lockout message', () async {
      fake.routeRaw(
        '/functions/v1/patient-auth',
        edgeError('Too many attempts. Please try again in a few minutes.', 429),
      );

      final provider = AuthProvider();
      final ok = await provider.signInWithPhoneAndPin(phone: phone, pin: pin);

      expect(ok, isFalse);
      expect(provider.error, contains('Too many attempts'));
    });
  });

  group('AuthProvider.signUpPatientDirect', () {
    test('registers and signs the patient in on success', () async {
      fake.routeJson('/functions/v1/patient-auth', {
        'access_token': 'edge-access-token',
        'refresh_token': 'test-refresh-token',
        'user_id': userId,
      });
      fake.routeJson('/auth/v1/token', sessionJson());
      fake.routeJson('/rest/v1/users', [userRow()]);

      final provider = AuthProvider();
      final ok = await provider.signUpPatientDirect(
        phone: phone,
        fullName: 'Test Patient',
        pin: pin,
      );

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser?.id, userId);

      final callBody = jsonDecode(
        fake.requestsTo('post', 'functions/v1/patient-auth').single.body,
      ) as Map<String, dynamic>;
      expect(callBody['action'], 'register');
      expect(callBody['phone'], phone);
      expect(callBody['pin'], pin);
      expect(callBody['fullName'], 'Test Patient');
    });

    test('rejects a PIN that is not exactly 6 digits without calling the server', () async {
      final provider = AuthProvider();
      final ok = await provider.signUpPatientDirect(
        phone: phone,
        fullName: 'Test Patient',
        pin: '123',
      );

      expect(ok, isFalse);
      expect(provider.error, contains('6 digits'));
      expect(fake.requestsTo('post', 'functions/v1/patient-auth'), isEmpty);
    });

    test('a phone number that is already registered surfaces the function\'s error', () async {
      fake.routeRaw(
        '/functions/v1/patient-auth',
        edgeError('An account with this phone number already exists. Please log in instead.', 409),
      );

      final provider = AuthProvider();
      final ok = await provider.signUpPatientDirect(
        phone: phone,
        fullName: 'Test Patient',
        pin: pin,
      );

      expect(ok, isFalse);
      expect(provider.error, contains('already exists'));
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
