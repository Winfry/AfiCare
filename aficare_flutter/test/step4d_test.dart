import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/appointment_model.dart';
import 'package:aficare_flutter/models/lab_model.dart';
import 'package:aficare_flutter/providers/appointment_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';
import 'package:aficare_flutter/providers/provider_patient_provider.dart';
import 'package:aficare_flutter/services/patient_lookup.dart';
import 'package:aficare_flutter/providers/message_provider.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';
import 'package:aficare_flutter/utils/medicine_course.dart';

import 'helpers/fake_supabase.dart';

/// Step 4d: weak spots — figures that flattered, failures that looked empty.
void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  http.Response boom() =>
      http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'});

  group('how long a course runs', () {
    test('the ways doctors write it', () {
      expect(MedicineCourse.daysIn('5 days'), 5);
      expect(MedicineCourse.daysIn('x7 days'), 7);
      expect(MedicineCourse.daysIn('5/7'), 5);
      expect(MedicineCourse.daysIn('2/52'), 14);
      expect(MedicineCourse.daysIn('3/12'), 90);
      expect(MedicineCourse.daysIn('2 weeks'), 14);
      expect(MedicineCourse.daysIn('1 month'), 30);
      expect(MedicineCourse.daysIn('10d'), 10);
    });

    test('no end: ongoing, lifelong, blank or unreadable', () {
      for (final t in ['ongoing', 'Continue', 'lifelong', '', null, 'as directed']) {
        expect(MedicineCourse.daysIn(t), isNull, reason: '$t');
      }
    });

    test('the last day is the earlier of the written length and the expiry', () {
      final start = DateTime(2026, 11, 1, 15);
      expect(MedicineCourse.lastDay(start: start, duration: '5/7'), DateTime(2026, 11, 5));
      expect(
        MedicineCourse.lastDay(start: start, duration: '30 days', expiresAt: DateTime(2026, 11, 3, 10)),
        DateTime(2026, 11, 3),
      );
      expect(MedicineCourse.lastDay(start: start, duration: 'ongoing'), isNull);
    });
  });

  group('a failed load is not "nothing here"', () {
    test('People I care for: a failed save is not shown as "could not load"', () async {
      fake.routeJson('/rest/v1/dependent_profiles', <Object?>[]);
      final dep = DependentProvider();
      await dep.loadDependents('g1');
      expect(dep.loadFailed, isFalse);

      fake.routeRaw('/rest/v1/dependent_profiles', boom());
      final ok = await dep.updateDependent('d1', guardianId: 'g1', fullName: 'Amani');
      expect(ok, isFalse);
      expect(dep.loadFailed, isFalse, reason: 'only the save failed');
      expect(dep.error, contains("couldn't save"));
      expect(dep.error, isNot(contains('Exception')), reason: 'plain words, not technical text');

      await dep.loadDependents('g1');
      expect(dep.loadFailed, isTrue);
    });

    test('Maternal care: a failed save is not "couldn\'t load your pregnancy record"', () async {
      fake.routeJson('/rest/v1/pregnancies', <Object?>[]);
      fake.routeJson('/rest/v1/anc_visits', <Object?>[]);
      final p = PregnancyProvider();
      await p.load('p1');
      expect(p.loadFailed, isFalse);

      fake.routeRaw('/rest/v1/pregnancies', boom());
      await p.load('p1');
      expect(p.loadFailed, isTrue);
    });

    test('a chat that failed to load says so, instead of "Write your first message"', () async {
      fake.routeRaw('/rest/v1/messages', boom());
      final mp = MessageProvider();
      await mp.loadThread('me', 'dr');
      expect(mp.threadFailed, isTrue);
      expect(mp.thread, isEmpty);

      fake.clearRoute('/rest/v1/messages');
      fake.routeJson('/rest/v1/messages', <Object?>[]);
      await mp.loadThread('me', 'dr');
      expect(mp.threadFailed, isFalse);
    });
  });

  group('People I care for: wrong details can be cleared', () {
    test('"Not known" sends an empty date of birth, gender and blood type', () async {
      fake.routeJson('/rest/v1/dependent_profiles', [{'id': 'd1'}]);
      final ok = await DependentProvider().updateDependent(
        'd1',
        guardianId: 'g1',
        fullName: 'Amani',
        relationship: 'child',
        allergies: const [],
      );
      expect(ok, isTrue);
      final body = jsonDecode(fake.requestsTo('PATCH', 'dependent_profiles').single.body) as Map;
      expect(body.containsKey('date_of_birth'), isTrue);
      expect(body['date_of_birth'], isNull);
      expect(body['gender'], isNull);
      expect(body['blood_type'], isNull);
    });

    test('an update the database quietly refused is a failure', () async {
      fake.routeJson('/rest/v1/dependent_profiles', <Object?>[]);
      final dep = DependentProvider();
      expect(await dep.updateDependent('d1', guardianId: 'g1', fullName: 'Amani'), isFalse);
    });
  });

  group('4d-1: staff see a patient only in their care, or by her exact ID', () {
    test('what counts as a whole MediLink ID', () {
      expect(PatientLookup.looksLikeMedilinkId('ML-NBO-AB1234'), isTrue);
      expect(PatientLookup.looksLikeMedilinkId(' ml-dep-x7k2p9 '), isTrue);
      expect(PatientLookup.looksLikeMedilinkId('Mary'), isFalse);
      expect(PatientLookup.looksLikeMedilinkId('ML-NBO'), isFalse);
    });

    test('an exact-ID lookup goes through the logged database function', () async {
      fake.routeJson('/rest/v1/rpc/find_patient_by_medilink',
          [{'id': 'p1', 'full_name': 'Mary Wanjiku', 'medilink_id': 'ML-NBO-AB1234'}]);
      final found = await PatientLookup.byMedilinkId(' ML-NBO-AB1234 ');
      expect(found?.id, 'p1');
      final body = jsonDecode(fake.requestsTo('POST', 'rpc/find_patient_by_medilink').single.body) as Map;
      expect(body, {'p_medilink': 'ML-NBO-AB1234'});
      expect(fake.requestsTo('GET', '/rest/v1/users'), isEmpty, reason: 'no direct read of accounts');
    });

    test('no such ID is "not found", not an error', () async {
      fake.routeJson('/rest/v1/rpc/find_patient_by_medilink', <Object?>[]);
      expect(await PatientLookup.byMedilinkId('ML-NBO-ZZ9999'), isNull);
    });

    test("a doctor's search for a whole ID uses the lookup; a name searches her own patients", () async {
      fake.routeJson('/rest/v1/rpc/find_patient_by_medilink',
          [{'id': 'p1', 'full_name': 'Mary Wanjiku', 'medilink_id': 'ML-NBO-AB1234'}]);
      fake.routeJson('/rest/v1/users', <Object?>[]);
      final pp = ProviderPatientProvider();
      await pp.searchPatients('ML-NBO-AB1234');
      expect(pp.searchResults.single['id'], 'p1');
      expect(pp.searchResults.single.containsKey('phone'), isFalse, reason: 'no phone from a lookup');
      expect(fake.requestsTo('GET', '/rest/v1/users'), isEmpty);

      await pp.searchPatients('Mary');
      expect(fake.requestsTo('GET', '/rest/v1/users'), hasLength(1));
    });
  });

  group('4d-1: nothing carries over or gets wiped', () {
    test("signing out forgets her settings, so the next person doesn't get them", () async {
      fake.routeJson('/rest/v1/user_preferences', {'user_id': 'u1', 'text_scale': 1.4, 'bold_text': true});
      final prefs = PreferencesProvider();
      await prefs.loadPreferences('u1');
      expect(prefs.prefs, isNotNull);
      prefs.clear();
      expect(prefs.prefs, isNull);
      expect(prefs.loadFailed, isFalse);
    });

    test('a profile that failed to load says so, so Edit profile can refuse to save over it', () async {
      fake.routeRaw('/rest/v1/patients', boom());
      final pp = PatientProfileProvider();
      await pp.loadProfile('p1');
      expect(pp.loadFailed, isTrue);
      fake.clearRoute('/rest/v1/patients');
      fake.routeJson('/rest/v1/patients', {'id': 'p1'});
      await pp.loadProfile('p1');
      expect(pp.loadFailed, isFalse);
    });

    test('an appointment she moves shows Pending again, not Confirmed', () async {
      final when = DateTime.now().add(const Duration(days: 3));
      fake.routeJson('/rest/v1/appointments', [
        {
          'id': 'ap1', 'patient_id': 'p1', 'provider_id': 'dr1',
          'scheduled_at': when.toIso8601String(), 'status': 'confirmed', 'type': 'in-person',
        },
      ]);
      fake.routeJson('/rest/v1/rpc/reschedule_appointment', null);
      final apt = AppointmentProvider();
      await apt.loadAppointments('p1');
      expect(apt.appointments.single.status, AppointmentStatus.confirmed);
      expect(await apt.rescheduleAppointment('ap1', when.add(const Duration(days: 1))), isTrue);
      expect(apt.appointments.single.status, AppointmentStatus.pending);
    });
  });

  group('4d-4: times are the real times', () {
    test('an appointment is sent as UTC and read back as local time', () {
      final local = DateTime(2026, 11, 10, 10, 0);
      final json = AppointmentModel(
        id: 'a', patientId: 'p', providerId: 'd', scheduledAt: local,
        type: AppointmentType.inPerson, status: AppointmentStatus.pending,
      ).toJson();
      final sent = json['scheduled_at'] as String;
      expect(sent, endsWith('Z'), reason: 'a bare clock time was read by the database as UTC');
      expect(DateTime.parse(sent).isAtSameMomentAs(local), isTrue);

      final back = AppointmentModel.fromJson({...json, 'type': 'in-person', 'status': 'pending'});
      expect(back.scheduledAt.isUtc, isFalse);
      expect(back.scheduledAt, local);
    });

    test('a new time is sent to the reschedule function as UTC', () async {
      final when = DateTime.now().add(const Duration(days: 3));
      fake.routeJson('/rest/v1/appointments', [
        {
          'id': 'ap1', 'patient_id': 'p1', 'provider_id': 'dr1',
          'scheduled_at': when.toUtc().toIso8601String(), 'status': 'confirmed', 'type': 'in-person',
        },
      ]);
      fake.routeJson('/rest/v1/rpc/reschedule_appointment', null);
      final apt = AppointmentProvider();
      await apt.loadAppointments('p1');
      final later = DateTime(when.year, when.month, when.day, 15, 30);
      await apt.rescheduleAppointment('ap1', later);
      final body = jsonDecode(fake.requestsTo('POST', 'rpc/reschedule_appointment').single.body) as Map;
      expect(body['new_scheduled_at'], later.toUtc().toIso8601String());
    });

    test('lab times are local, and a re-run test shows its newest result', () {
      final order = LabOrderModel.fromJson({
        'id': 'o1', 'patient_id': 'p1', 'provider_id': 'd1', 'test_name': 'Hb',
        'ordered_at': '2026-11-01T06:00:00Z', 'status': 'completed',
        'lab_results': [
          {'id': 'r1', 'lab_order_id': 'o1', 'result_value': '9.1', 'resulted_at': '2026-11-02T07:00:00Z'},
          {'id': 'r2', 'lab_order_id': 'o1', 'result_value': '11.4', 'resulted_at': '2026-11-05T07:00:00Z'},
          {'id': 'r0', 'lab_order_id': 'o1', 'result_value': '?', 'resulted_at': null},
        ],
      });
      expect(order.orderedAt.isUtc, isFalse);
      expect(order.orderedAt.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 6)), isTrue);
      expect(order.result!.id, 'r2');
      expect(order.result!.resultedAt!.isUtc, isFalse);
    });
  });
}

