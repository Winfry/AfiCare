import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/user_preferences_model.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> prefsRow({String userId = 'u1'}) {
    return {
      'user_id': userId,
      'theme': 'dark',
      'language': 'sw',
      'notifications_enabled': false,
      'email_notifications': true,
      'sms_notifications': true,
      'text_scale': 1.25,
      'reduce_motion': true,
      'text_to_speech': true,
    };
  }

  group('PreferencesProvider.loadPreferences', () {
    test('maps an existing preferences row', () async {
      fake.routeJson('/rest/v1/user_preferences', prefsRow());

      final provider = PreferencesProvider();
      await provider.loadPreferences('u1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.prefs!.theme, AppThemePreference.dark);
      expect(provider.prefs!.language, 'sw');
      expect(provider.prefs!.smsNotifications, isTrue);
      expect(provider.prefs!.reduceMotion, isTrue);
    });

    test('defaults when no row exists', () async {
      fake.routeJson('/rest/v1/user_preferences', <Object?>[]);

      final provider = PreferencesProvider();
      await provider.loadPreferences('u1');

      expect(provider.prefs, isNotNull);
      expect(provider.prefs!.userId, 'u1');
      expect(provider.prefs!.theme, AppThemePreference.light);
    });

    test('falls back to defaults on server error', () async {
      fake.routeRaw(
        '/rest/v1/user_preferences',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = PreferencesProvider();
      await provider.loadPreferences('u1');

      expect(provider.error, isNotNull);
      expect(provider.prefs, isNotNull);
      expect(provider.prefs!.userId, 'u1');
    });
  });

  group('PreferencesProvider.save', () {
    test('upserts and updates local state immediately', () async {
      fake.routeJson('/rest/v1/user_preferences', <String, dynamic>{});

      final provider = PreferencesProvider();
      final prefs = UserPreferencesModel(
        userId: 'u1',
        theme: AppThemePreference.highContrast,
        language: 'en',
      );

      final ok = await provider.save(prefs);

      expect(ok, isTrue);
      expect(provider.prefs, same(prefs));

      final upsert = fake.requestsTo('POST', 'user_preferences').single;
      final body = jsonDecode(upsert.body) as Map<String, dynamic>;
      expect(body, containsPair('user_id', 'u1'));
      expect(body, containsPair('theme', 'high_contrast'));
    });
  });
}
