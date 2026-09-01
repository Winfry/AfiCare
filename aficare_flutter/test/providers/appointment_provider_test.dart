import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/appointment_model.dart';
import 'package:aficare_flutter/providers/appointment_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> appointmentRow({
    String id = 'ap1',
    String patientId = 'p1',
    String providerId = 'prov-1',
    String facilityId = 'f1',
    String scheduledAt = '2026-06-01T09:00:00.000Z',
    int duration = 30,
    String type = 'in-person',
    String status = 'confirmed',
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'facility_id': facilityId,
      'scheduled_at': scheduledAt,
      'duration_minutes': duration,
      'type': type,
      'status': status,
      'chief_complaint': null,
      'notes': null,
      'is_follow_up': false,
      'consultation_id': null,
    };
  }

  group('AppointmentProvider.loadAppointments', () {
    test('maps rows to AppointmentModel for a patient', () async {
      fake.routeJson('/rest/v1/appointments', [
        appointmentRow(),
        appointmentRow(
          id: 'ap2',
          scheduledAt: '2026-06-01T11:00:00.000Z',
          type: 'telehealth',
          status: 'pending',
        ),
      ]);

      final provider = AppointmentProvider();
      await provider.loadAppointments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.appointments, hasLength(2));
      expect(provider.appointments.first.patientId, 'p1');
      expect(provider.appointments.first.scheduledAt.isUtc, isTrue);
      expect(provider.appointments.first.type, AppointmentType.inPerson);
      expect(provider.appointments.first.status, AppointmentStatus.confirmed);
      expect(provider.appointments.last.type, AppointmentType.telehealth);
      expect(provider.appointments.last.status, AppointmentStatus.pending);

      final req = fake.requestsTo('GET', 'appointments').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('loads provider appointments by provider id', () async {
      fake.routeJson('/rest/v1/appointments', [appointmentRow()]);

      final provider = AppointmentProvider();
      await provider.loadProviderAppointments('prov-1');

      expect(provider.appointments, hasLength(1));
      final req = fake.requestsTo('GET', 'appointments').single;
      expect(req.url.queryParameters['provider_id'], 'eq.prov-1');
    });

    test('empty response leaves an empty list without error', () async {
      fake.routeJson('/rest/v1/appointments', <Object?>[]);

      final provider = AppointmentProvider();
      await provider.loadAppointments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.appointments, isEmpty);
    });

    test('server error sets error and stops loading', () async {
      fake.routeRaw(
        '/rest/v1/appointments',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AppointmentProvider();
      await provider.loadAppointments('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.appointments, isEmpty);
    });
  });

  group('AppointmentProvider.bookAppointment', () {
    test('inserts the schema columns without id and reloads', () async {
      fake.routeJson('/rest/v1/appointments', [
        appointmentRow(id: 'ap-new', scheduledAt: '2026-06-01T09:00:00.000Z'),
      ]);

      final provider = AppointmentProvider();
      final appointment = AppointmentModel(
        id: 'ap-new',
        patientId: 'p1',
        providerId: 'prov-1',
        facilityId: 'f1',
        scheduledAt: DateTime.utc(2026, 6, 1, 9, 0),
        durationMinutes: 30,
        type: AppointmentType.inPerson,
        status: AppointmentStatus.pending,
        notes: 'bring records',
      );

      final ok = await provider.bookAppointment(appointment);

      expect(ok, isTrue);
      expect(provider.error, isNull);

      final insert = fake.requestsTo('POST', 'appointments').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('provider_id', 'prov-1'));
      expect(body, containsPair('type', 'in-person'));
      expect(body, containsPair('status', 'pending'));
      expect(body, containsPair('notes', 'bring records'));
    });
  });

  group('AppointmentProvider.updateStatus', () {
    test('sends the update and mutates the local row', () async {
      fake.routeJson('/rest/v1/appointments', [appointmentRow()]);

      final provider = AppointmentProvider();
      await provider.loadAppointments('p1');

      final ok = await provider.updateStatus('ap1', AppointmentStatus.cancelled);

      expect(ok, isTrue);
      expect(provider.appointments.single.status, AppointmentStatus.cancelled);

      final update = fake.requestsTo('PATCH', 'appointments').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('status', 'cancelled'));
    });

    test('failure sets an error and returns false', () async {
      fake.routeRaw(
        '/rest/v1/appointments',
        http.Response('{"message":"not found"}', 404),
      );

      final provider = AppointmentProvider();
      final ok = await provider.updateStatus('missing', AppointmentStatus.cancelled);

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
