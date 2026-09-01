import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/medication_reminder_model.dart';
import 'package:aficare_flutter/providers/medication_reminder_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> reminder({
    String id = 'r1',
    String name = 'Metformin',
    bool active = true,
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'medication_name': name,
      'dosage': '500mg',
      'frequency': 'twice_daily',
      'times': [
        {'hour': 8, 'minute': 0},
        {'hour': 20, 'minute': 0},
      ],
      'is_active': active,
      'start_date': '2026-01-01T00:00:00.000Z',
      'end_date': null,
      'notes': null,
      'prescription_id': null,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('MedicationReminderProvider.loadReminders', () {
    test('loads and exposes active count', () async {
      fake.routeJson('/rest/v1/medication_reminders', [
        reminder(),
        reminder(id: 'r2', name: 'Paracetamol', active: false),
      ]);

      final provider = MedicationReminderProvider();
      await provider.loadReminders('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.reminders, hasLength(2));
      expect(provider.activeReminders, hasLength(1));
      expect(provider.todaysCount, 1);
      expect(provider.reminders.first.medicationName, 'Metformin');

      final req =
          fake.requestsTo('GET', 'medication_reminders').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('server error yields empty list without throwing', () async {
      fake.routeRaw(
        '/rest/v1/medication_reminders',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = MedicationReminderProvider();
      await provider.loadReminders('p1');

      expect(provider.reminders, isEmpty);
      expect(provider.error, isNull);
    });
  });

  group('MedicationReminderProvider.saveReminder', () {
    test('inserts a new reminder and prepends', () async {
      fake.routeJson('/rest/v1/medication_reminders', <String, dynamic>{});

      final provider = MedicationReminderProvider();
      final ok = await provider.saveReminder(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        frequency: 'once_daily',
        times: [ReminderTime(hour: 12, minute: 0)],
      );

      expect(ok, isTrue);
      final insert =
          fake.requestsTo('POST', 'medication_reminders').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('medication_name', 'Ibuprofen'));
      expect(body, containsPair('is_active', isTrue));

      expect(provider.reminders, hasLength(1));
      expect(provider.reminders.first.medicationName, 'Ibuprofen');
    });

    test('updates an existing reminder in place', () async {
      fake.routeJson('/rest/v1/medication_reminders', [reminder()]);

      final provider = MedicationReminderProvider();
      await provider.loadReminders('p1');

      final ok = await provider.saveReminder(
        patientId: 'p1',
        medicationName: 'Metformin XR',
        dosage: '750mg',
        frequency: 'once_daily',
        times: [ReminderTime(hour: 8, minute: 0)],
        existingId: 'r1',
      );

      expect(ok, isTrue);
      final update =
          fake.requestsTo('PATCH', 'medication_reminders').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('medication_name', 'Metformin XR'));

      expect(provider.reminders.single.medicationName, 'Metformin XR');
    });

    test('failure returns false', () async {
      fake.routeRaw(
        '/rest/v1/medication_reminders',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = MedicationReminderProvider();
      final ok = await provider.saveReminder(
        patientId: 'p1',
        medicationName: 'X',
        dosage: '1',
        frequency: 'once_daily',
        times: [ReminderTime(hour: 8, minute: 0)],
      );

      expect(ok, isFalse);
    });
  });

  group('MedicationReminderProvider.toggleReminder', () {
    test('deactivates a reminder and updates state', () async {
      fake.routeJson('/rest/v1/medication_reminders', [reminder()]);

      final provider = MedicationReminderProvider();
      await provider.loadReminders('p1');

      await provider.toggleReminder('r1', false);

      final update =
          fake.requestsTo('PATCH', 'medication_reminders').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('is_active', false));
      expect(provider.reminders.single.isActive, isFalse);
      expect(provider.activeReminders, isEmpty);
    });
  });

  group('MedicationReminderProvider.deleteReminder', () {
    test('deletes and removes from state', () async {
      fake.routeJson('/rest/v1/medication_reminders', [reminder()]);

      final provider = MedicationReminderProvider();
      await provider.loadReminders('p1');

      await provider.deleteReminder('r1');

      final del = fake.requestsTo('DELETE', 'medication_reminders').single;
      expect(del.url.queryParameters['id'], 'eq.r1');
      expect(provider.reminders, isEmpty);
    });
  });
}
