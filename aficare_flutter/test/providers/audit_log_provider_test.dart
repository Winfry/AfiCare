import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/audit_log_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> logRow({
    String action = 'login',
    String userId = 'u1',
    String timestamp = '2026-06-01T09:00:00.000Z',
  }) {
    return {
      'action': action,
      'user_id': userId,
      'patient_id': null,
      'details': <String, dynamic>{},
      'timestamp': timestamp,
    };
  }

  group('AuditLogProvider filters', () {
    test('filteredLogs applies date range, action and user filter', () async {
      fake.routeJson('/rest/v1/audit_log', [
        logRow(action: 'login', timestamp: '2026-06-01T09:00:00.000Z'),
        logRow(
          action: 'user_created',
          userId: 'u2',
          timestamp: '2026-07-15T09:00:00.000Z',
        ),
        logRow(
          action: 'login',
          userId: 'u2',
          timestamp: '2026-08-01T09:00:00.000Z',
        ),
      ]);

      final provider = AuditLogProvider();
      await provider.loadLogs();
      expect(provider.logs, hasLength(3));

      provider.setActionFilter('login');
      expect(provider.filteredLogs, hasLength(2));

      provider.setUserFilter('u2');
      expect(provider.filteredLogs.map((l) => l['user_id']), ['u2']);

      provider.setDateRange(
        DateTimeRange(
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 6, 30),
        ),
      );
      provider.setActionFilter('all');
      provider.setUserFilter('');
      expect(provider.filteredLogs, hasLength(1));
    });

    test('uniqueActions returns sorted distinct actions', () async {
      fake.routeJson('/rest/v1/audit_log', [
        logRow(action: 'login'),
        logRow(action: 'logout'),
        logRow(action: 'login'),
      ]);

      final provider = AuditLogProvider();
      await provider.loadLogs();

      expect(provider.uniqueActions, ['login', 'logout']);
    });
  });

  group('AuditLogProvider.loadLogs', () {
    test('maps rows', () async {
      fake.routeJson('/rest/v1/audit_log', [logRow()]);

      final provider = AuditLogProvider();
      await provider.loadLogs();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.logs, hasLength(1));
      expect(provider.logs.first['action'], 'login');
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/audit_log',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AuditLogProvider();
      await provider.loadLogs();

      expect(provider.error, isNotNull);
    });
  });

  group('AuditLogProvider.logEvent', () {
    test('inserts an audit event', () async {
      fake.routeJson('/rest/v1/audit_log', <String, dynamic>{});

      final provider = AuditLogProvider();
      final ok = await provider.logEvent(
        action: 'referral_created',
        userId: 'u1',
        patientId: 'p1',
        details: {'id': 'r1'},
        ipAddress: '127.0.0.1',
      );

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'audit_log').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('action', 'referral_created'));
      expect(body, containsPair('details', {'id': 'r1'}));
    });

    test('failure returns false without throwing', () async {
      fake.routeRaw(
        '/rest/v1/audit_log',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = AuditLogProvider();
      expect(await provider.logEvent(action: 'logout'), isFalse);
    });
  });

  group('AuditLogProvider.getActionLabel', () {
    test('returns a known label or falls back to the action', () {
      final provider = AuditLogProvider();
      expect(provider.getActionLabel('login'), 'Login');
      expect(provider.getActionLabel('facility_created'), 'Facility Created');
      expect(provider.getActionLabel('unknown_action'), 'unknown_action');
    });
  });
}
