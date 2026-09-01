import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/medication_reminder_model.dart';
import 'package:aficare_flutter/services/medication_reminder_service.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> reminderRow({
    String id = 'r1',
    String patientId = 'p1',
    String medicationName = 'Amoxicillin',
    bool isActive = true,
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'medication_name': medicationName,
      'dosage': '500mg',
      'frequency': 'twice_daily',
      'times': [
        {'hour': 8, 'minute': 0, 'label': 'Morning'},
        {'hour': 20, 'minute': 0, 'label': 'Evening'},
      ],
      'is_active': isActive,
      'start_date': null,
      'end_date': null,
      'notes': null,
      'prescription_id': null,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('MedicationReminderService.loadReminders', () {
    test('maps rows for a patient', () async {
      fake.routeJson('/rest/v1/medication_reminders', [
        reminderRow(),
        reminderRow(
          id: 'r2',
          medicationName: 'Paracetamol',
          isActive: false,
        ),
      ]);

      final reminders =
          await MedicationReminderService().loadReminders('p1');

      expect(reminders, hasLength(2));
      expect(reminders.first.medicationName, 'Amoxicillin');
      expect(reminders.first.times, hasLength(2));
      expect(reminders.first.times.first.hour, 8);
      expect(reminders.last.medicationName, 'Paracetamol');
      expect(reminders.last.isActive, isFalse);

      final req = fake.requestsTo('GET', 'medication_reminders').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('empty response returns an empty list', () async {
      fake.routeJson('/rest/v1/medication_reminders', <Object?>[]);

      final reminders =
          await MedicationReminderService().loadReminders('p1');

      expect(reminders, isEmpty);
    });

    test('server error returns an empty list without throwing', () async {
      fake.routeRaw(
        '/rest/v1/medication_reminders',
        http.Response('{"message":"boom"}', 500),
      );

      final reminders =
          await MedicationReminderService().loadReminders('p1');

      expect(reminders, isEmpty);
    });
  });

  group('MedicationReminderService.saveReminder', () {
    test('inserts a new reminder with the schema columns', () async {
      fake.routeJson('/rest/v1/medication_reminders', <String, dynamic>{});
      // `_initialized` is false on the VM, so saveReminder never touches the
      // notification plugin and only performs the Supabase insert.

      final service = MedicationReminderService();
      final result = await service.saveReminder(
        patientId: 'p1',
        medicationName: 'Aspirin',
        dosage: '100mg',
        frequency: 'once_daily',
        times: [ReminderTime(hour: 8, minute: 0)],
      );

      expect(result, isNotNull);
      expect(result!.medicationName, 'Aspirin');
      expect(result.isActive, isTrue);

      final insert = fake.requestsTo('POST', 'medication_reminders').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('medication_name', 'Aspirin'));
      expect(body, containsPair('dosage', '100mg'));
      expect(body, containsPair('frequency', 'once_daily'));
      expect(body, containsPair('is_active', true));
      final times = body['times'] as List;
      expect(times, hasLength(1));
      expect(body['id'], isNotEmpty);
    });

    test('updates when an existing id is supplied', () async {
      fake.routeJson('/rest/v1/medication_reminders', <String, dynamic>{});

      final service = MedicationReminderService();
      final result = await service.saveReminder(
        patientId: 'p1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        frequency: 'three_times',
        times: [
          ReminderTime(hour: 8, minute: 0),
        ],
        existingId: 'r1',
      );

      expect(result, isNotNull);
      expect(result!.id, 'r1');

      final update = fake.requestsTo('PATCH', 'medication_reminders').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('id', 'r1'));
      expect(body, containsPair('medication_name', 'Ibuprofen'));
    });
  });

  group('MedicationReminderService.toggleReminder', () {
    test('updates is_active to false', () async {
      fake.routeJson('/rest/v1/medication_reminders', <String, dynamic>{});

      await MedicationReminderService().toggleReminder('r1', false);

      final update = fake.requestsTo('PATCH', 'medication_reminders').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('is_active', false));
    });
  });

  group('MedicationReminderService.deleteReminder', () {
    test('deletes the row by id', () async {
      fake.routeJson('/rest/v1/medication_reminders', <String, dynamic>{});

      await MedicationReminderService().deleteReminder('r1');

      final del = fake.requestsTo('DELETE', 'medication_reminders').single;
      expect(del.url.queryParameters['id'], 'eq.r1');
    });
  });
}
