import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/providers/analytics_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> userRow(String id, String role, String createdAt) => {
        'id': id,
        'role': role,
        'created_at': createdAt,
      };

  group('AnalyticsProvider.loadAll', () {
    test('aggregates counts and distributions from each table', () async {
      fake.routeJson('/rest/v1/users', [
        userRow('u1', 'patient', '2026-01-01T09:00:00.000Z'),
        userRow('u2', 'patient', '2026-01-01T10:00:00.000Z'),
        userRow('u3', 'doctor', '2026-01-02T09:00:00.000Z'),
        userRow('u4', 'chw', '2026-01-02T09:00:00.000Z'),
        userRow('u5', 'nurse', '2026-01-03T09:00:00.000Z'),
      ]);
      fake.routeJson('/rest/v1/referrals', [
        {'id': 'r1', 'to_facility': 'Hospital A'},
        {'id': 'r2', 'to_facility': 'Hospital A'},
        {'id': 'r3', 'to_facility': 'Clinic B'},
      ]);
      fake.routeJson('/rest/v1/appointments', [
        {'id': 'a1', 'status': 'cancelled', 'scheduled_at': '2026-01-01T09:00:00.000Z'},
        {'id': 'a2', 'status': 'confirmed', 'scheduled_at': '2026-01-01T11:00:00.000Z'},
      ]);
      fake.routeJson('/rest/v1/consultations', [
        {'id': 'c1'},
        {'id': 'c2'},
        {'id': 'c3'},
      ]);
      fake.routeJson('/rest/v1/facilities', [
        {'id': 'f1'},
        {'id': 'f2'},
      ]);
      fake.routeJson('/rest/v1/triage_assessments', [
        {'triage_level': 'emergency'},
        {'triage_level': 'urgent'},
        {'triage_level': 'urgent'},
        {'triage_level': 'non_urgent'},
      ]);

      final provider = AnalyticsProvider();
      await provider.loadAll();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);

      // Counts.
      expect(provider.totalUsers, 5);
      expect(provider.totalConsultations, 3);
      expect(provider.totalFacilities, 2);

      // Display lists.
      expect(provider.roleDistribution,
          containsAllInOrder([
            {'role': 'patient', 'count': 2},
            {'role': 'doctor', 'count': 1},
          ]));

      final facilities = provider.referralsByFacility;
      // Sorted by count descending.
      expect(facilities, containsAllInOrder([
        {'facility': 'Hospital A', 'count': 2},
        {'facility': 'Clinic B', 'count': 1},
      ]));
      expect(facilities.first['facility'], 'Hospital A');

      expect(provider.usersOverTime,
          containsAllInOrder([
            {'date': '2026-01-01', 'count': 2},
            {'date': '2026-01-02', 'count': 2},
            {'date': '2026-01-03', 'count': 1},
          ]));

      expect(provider.triageBreakdown, containsAllInOrder([
        {'level': 'emergency', 'count': 1},
        {'level': 'urgent', 'count': 2},
        {'level': 'non_urgent', 'count': 1},
      ]));
      expect(provider.appointmentTrend, [
        {'date': '2026-01-01', 'count': 2},
      ]);
    });

    test('empty tables produce empty lists without error', () async {
      fake.routeJson('/rest/v1/users', <Object?>[]);
      fake.routeJson('/rest/v1/referrals', <Object?>[]);
      fake.routeJson('/rest/v1/appointments', <Object?>[]);
      fake.routeJson('/rest/v1/consultations', <Object?>[]);
      fake.routeJson('/rest/v1/facilities', <Object?>[]);
      fake.routeJson('/rest/v1/triage_assessments', <Object?>[]);

      final provider = AnalyticsProvider();
      await provider.loadAll();

      expect(provider.error, isNull);
      expect(provider.totalUsers, 0);
      expect(provider.usersOverTime, isEmpty);
      expect(provider.roleDistribution, isEmpty);
      expect(provider.triageBreakdown, isEmpty);
    });
  });

  group('AnalyticsProvider filters', () {
    test('setPeriodFilter and setFacilityFilter update and notify', () {
      final provider = AnalyticsProvider();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.setPeriodFilter('last_quarter');
      provider.setFacilityFilter('f1');

      expect(provider.periodFilter, 'last_quarter');
      expect(provider.facilityFilter, 'f1');
      expect(notified, 2);
    });
  });
}