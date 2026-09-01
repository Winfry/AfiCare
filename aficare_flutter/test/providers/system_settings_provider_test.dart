import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/system_settings_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> settingRow({
    String id = 's1',
    String category = 'general',
    String key = 'maintenance_mode',
    dynamic value = false,
  }) {
    return {
      'id': id,
      'category': category,
      'key': key,
      'value': value,
      'description': null,
      'updated_at': '2026-01-01T09:00:00.000Z',
      'updated_by': null,
    };
  }

  group('SystemSettingsProvider lookups', () {
    test('getByCategory, getBool, getString and getValue', () async {
      fake.routeJson('/rest/v1/system_settings', [
        settingRow(key: 'maintenance_mode', value: true),
        settingRow(
          id: 's2',
          category: 'notifications',
          key: 'smtp_host',
          value: 'smtp.example.com',
        ),
      ]);

      final provider = SystemSettingsProvider();
      await provider.loadSettings();

      expect(provider.getByCategory('general'), hasLength(1));
      expect(provider.getBool('general', 'maintenance_mode'), isTrue);
      expect(provider.getString('notifications', 'smtp_host'),
          'smtp.example.com');
      expect(provider.getValue('general', 'missing'), isNull);
      expect(provider.getString('general', 'missing', defaultValue: 'd'), 'd');
    });
  });

  group('SystemSettingsProvider.loadSettings', () {
    test('maps settings', () async {
      fake.routeJson('/rest/v1/system_settings', [settingRow()]);

      final provider = SystemSettingsProvider();
      await provider.loadSettings();

      expect(provider.error, isNull);
      expect(provider.settings, hasLength(1));
      expect(provider.settings.first.value, false);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/system_settings',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = SystemSettingsProvider();
      await provider.loadSettings();

      expect(provider.error, isNotNull);
    });
  });

  group('SystemSettingsProvider.saveSetting', () {
    test('updates an existing setting', () async {
      fake.routeJson('/rest/v1/system_settings', [settingRow()]);

      final provider = SystemSettingsProvider();
      await provider.loadSettings();

      final ok =
          await provider.saveSetting('general', 'maintenance_mode', true);

      expect(ok, isTrue);
      final update = fake.requestsTo('PATCH', 'system_settings').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('value', true));
    });

    test('inserts a new setting', () async {
      fake.routeJson('/rest/v1/system_settings', <String, dynamic>{});

      final provider = SystemSettingsProvider();
      final ok =
          await provider.saveSetting('general', 'app_name', 'AfiCare');

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'system_settings').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('category', 'general'));
      expect(body, containsPair('value', 'AfiCare'));
    });
  });
}
