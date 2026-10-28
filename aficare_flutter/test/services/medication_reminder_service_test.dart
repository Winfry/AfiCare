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

  group('Alarms', () {
    MedicationReminder reminder(Map<String, dynamic> changes) =>
        MedicationReminder.fromJson({...reminderRow(), ...changes});

    test('each alarm has its own id, the same every time, and fits Android', () {
      const id = '3f2b8c1e-6a4d-4e2b-9c1a-7d5e8f9a0b1c';
      final ids = [for (var i = 0; i < MedicationReminderService.maxTimesPerReminder; i++)
        MedicationReminderService.notificationId(id, i)];
      expect(ids.toSet().length, ids.length);
      expect(MedicationReminderService.notificationId(id, 0), ids.first);
      expect(ids.every((n) => n >= 0 && n <= 0x7FFFFFFF), isTrue);
      expect(MedicationReminderService.notificationId('another-reminder', 0), isNot(ids.first));
    });

    test('an on reminder at set times rings; paused, "when needed" or ended ones do not', () {
      final today = DateTime(2026, 10, 28, 9);
      expect(MedicationReminderService.shouldRing(reminder({}), today), isTrue);
      expect(MedicationReminderService.shouldRing(reminder({'is_active': false}), today), isFalse);
      expect(MedicationReminderService.shouldRing(reminder({'frequency': 'as_needed'}), today), isFalse);
      expect(MedicationReminderService.shouldRing(reminder({'times': <Object>[]}), today), isFalse);
      expect(MedicationReminderService.shouldRing(reminder({'end_date': '2026-10-27'}), today), isFalse);
      expect(MedicationReminderService.shouldRing(reminder({'end_date': '2026-10-28'}), today), isTrue,
          reason: 'the last day still rings');
    });

    test("the alarm names a dependant, so it isn't taken as the parent's", () {
      final r = reminder({});
      expect(MedicationReminderService.notificationText(r), ('Time for your medicine', 'Amoxicillin · 500mg'));
      expect(MedicationReminderService.notificationText(r, personName: 'Brian').$1, "Time for Brian's medicine");
      expect(MedicationReminderService.notificationText(reminder({'dosage': ''})).$2, 'Amoxicillin');
    });

    test('turning a paused reminder back on makes it ring again', () {
      final paused = reminder({'is_active': false});
      expect(MedicationReminderService.shouldRing(paused.copyWith(isActive: true), DateTime(2026, 10, 28)), isTrue);
    });
  });
}
