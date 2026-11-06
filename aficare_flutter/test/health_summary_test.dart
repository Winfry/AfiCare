import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/appointment_model.dart';
import 'package:aficare_flutter/models/consultation_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/appointment_provider.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/providers/patient_provider.dart';
import 'package:aficare_flutter/screens/patient/health_summary.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'mary',
        email: 'mary@example.com',
        fullName: 'Mary Wanjiru',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
      );
}

class _FakePatient extends PatientProvider {
  _FakePatient(this._list);
  final List<ConsultationModel> _list;

  @override
  List<ConsultationModel> get consultations => _list;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  Future<void> loadConsultations(String patientId) async {}
}

ConsultationModel _visit(DateTime when, VitalSigns vitals) => ConsultationModel(
      id: 'c${when.millisecondsSinceEpoch}',
      patientId: 'mary',
      providerId: 'dr',
      timestamp: when,
      chiefComplaint: 'Cough',
      symptoms: const [],
      vitalSigns: vitals,
      triageLevel: 'non_urgent',
      diagnoses: const [],
      recommendations: const [],
      followUpRequired: false,
    );

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, List<ConsultationModel> visits, {Size size = const Size(1280, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<DependentProvider>(create: (_) => DependentProvider()),
        ChangeNotifierProvider<PatientProvider>(create: (_) => _FakePatient(visits)),
        ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: HealthSummary())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final today = DateTime.now();

  testWidgets('no score and no "Excellent": a dangerously low oxygen level leads', (tester) async {
    await pump(tester, [
      _visit(today.subtract(const Duration(days: 2)),
          VitalSigns(temperature: 36.8, systolicBP: 118, diastolicBP: 76, pulseRate: 80, oxygenSaturation: 85)),
    ]);

    expect(find.text('Health score'), findsNothing);
    expect(find.text('Excellent'), findsNothing);
    expect(find.text('80'), findsNothing);
    expect(find.text('Latest readings'), findsOneWidget);
    expect(find.text('One outside the usual range'), findsOneWidget);
    expect(find.text('Oxygen (SpO₂): Very low'), findsOneWidget);
    expect(find.textContaining('(2 days ago)'), findsOneWidget);
    expect(find.text('Readings from one visit, not a measure of your overall health.'), findsOneWidget);
  });

  testWidgets('all usual says so, plainly', (tester) async {
    await pump(tester, [
      _visit(today.subtract(const Duration(days: 10)), VitalSigns(systolicBP: 118, diastolicBP: 76, pulseRate: 72)),
    ]);
    expect(find.text('All in the usual range'), findsOneWidget);
    expect(find.textContaining('These may be out of date'), findsNothing);
  });

  testWidgets('old readings are flagged as possibly out of date', (tester) async {
    await pump(tester, [
      _visit(today.subtract(const Duration(days: 500)), VitalSigns(systolicBP: 118, diastolicBP: 76)),
    ]);
    expect(find.textContaining('(over a year ago). These may be out of date.'), findsOneWidget);
  });

  testWidgets('the latest visit is the one described, not an older one', (tester) async {
    await pump(tester, [
      _visit(today.subtract(const Duration(days: 40)), VitalSigns(systolicBP: 170, diastolicBP: 100)),
      _visit(today.subtract(const Duration(days: 3)), VitalSigns(systolicBP: 150, diastolicBP: 92, temperature: 39)),
    ]);
    expect(find.text('2 outside the usual range'), findsOneWidget);
    expect(find.text('Blood pressure: High'), findsOneWidget);
    expect(find.text('Temperature: Fever'), findsOneWidget);
    expect(find.text('Blood pressure trend'), findsOneWidget);
  });

  testWidgets('no visits, or a visit without readings, is said honestly', (tester) async {
    await pump(tester, []);
    expect(find.text('None recorded yet'), findsOneWidget);
    expect(find.textContaining('appear here after a visit'), findsOneWidget);
  });

  testWidgets('a visit with no readings', (tester) async {
    await pump(tester, [_visit(today, VitalSigns())]);
    expect(find.text('None recorded yet'), findsOneWidget);
    expect(find.text('No readings were recorded at your last visit.'), findsOneWidget);
  });

  testWidgets('lays out on a phone without overflow, with several badges', (tester) async {
    await pump(
      tester,
      [
        _visit(today.subtract(const Duration(days: 400)),
            VitalSigns(temperature: 39.2, systolicBP: 185, diastolicBP: 121, pulseRate: 130, oxygenSaturation: 86)),
      ],
      size: const Size(360, 2400),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('4 outside the usual range'), findsOneWidget);
  });

  group('follow-ups tell the truth about booking', () {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day).add(const Duration(days: 20));

    ConsultationModel visitWithFollowUp() => ConsultationModel(
          id: 'visit-1',
          patientId: 'mary',
          providerId: 'dr',
          timestamp: now.subtract(const Duration(days: 3)),
          chiefComplaint: 'Blood pressure check',
          symptoms: const [],
          vitalSigns: VitalSigns(systolicBP: 150, diastolicBP: 95),
          triageLevel: 'non_urgent',
          diagnoses: const [],
          recommendations: const [],
          followUpRequired: true,
          followUpDate: due,
        );

    Map<String, Object?> appt(DateTime when, String status, {String? consultationId}) => {
          'id': 'a-${when.millisecondsSinceEpoch}-$status',
          'patient_id': 'mary',
          'provider_id': 'dr',
          'scheduled_at': when.toUtc().toIso8601String(),
          'type': 'in-person',
          'status': status,
          if (consultationId != null) 'consultation_id': consultationId,
        };

    testWidgets('never says "Scheduled" when nothing is booked', (tester) async {
      fake.routeJson('/rest/v1/appointments', <Object?>[]);
      await pump(tester, [visitWithFollowUp()]);
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsNothing);
      expect(find.text('Not booked'), findsOneWidget);
      expect(find.text('Tap to book it.'), findsOneWidget);
    });

    testWidgets('a confirmed appointment near the date shows as booked, with its day', (tester) async {
      final when = due.add(const Duration(days: 2, hours: 9));
      fake.routeJson('/rest/v1/appointments', [appt(when, 'confirmed')]);
      await pump(tester, [visitWithFollowUp()]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Booked · '), findsOneWidget);
      expect(find.text('Not booked'), findsNothing);
    });

    testWidgets('a request not yet confirmed says Requested', (tester) async {
      fake.routeJson('/rest/v1/appointments', [appt(due.add(const Duration(hours: 10)), 'pending')]);
      await pump(tester, [visitWithFollowUp()]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Requested · '), findsOneWidget);
    });

    testWidgets('a cancelled appointment does not count', (tester) async {
      fake.routeJson('/rest/v1/appointments', [appt(due.add(const Duration(hours: 10)), 'cancelled')]);
      await pump(tester, [visitWithFollowUp()]);
      await tester.pumpAndSettle();
      expect(find.text('Not booked'), findsOneWidget);
    });

    testWidgets('when appointments fail to load it says it could not check, not "Not booked"', (tester) async {
      fake.routeRaw('/rest/v1/appointments',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await pump(tester, [visitWithFollowUp()]);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't check"), findsOneWidget);
      expect(find.text('Not booked'), findsNothing);
    });

    test('matching rules', () {
      final visit = visitWithFollowUp();
      AppointmentModel a(DateTime when, String status, {String? consultationId}) =>
          AppointmentModel.fromJson(appt(when, status, consultationId: consultationId));

      // Within two weeks either side counts; the nearest wins.
      final near = a(due.add(const Duration(days: 1)), 'confirmed');
      final far = a(due.add(const Duration(days: 10)), 'confirmed');
      expect(followUpBooking(visit, [far, near])!.id, near.id);
      // More than two weeks away is a different appointment.
      expect(followUpBooking(visit, [a(due.add(const Duration(days: 30)), 'confirmed')]), isNull);
      // Before the visit itself can't be its follow-up.
      expect(followUpBooking(visit, [a(now.subtract(const Duration(days: 10)), 'confirmed')]), isNull);
      // One made for this visit counts whenever it is.
      expect(followUpBooking(visit, [a(due.add(const Duration(days: 40)), 'pending', consultationId: 'visit-1')]),
          isNotNull);
      // Completed or cancelled never count.
      expect(followUpBooking(visit, [a(due, 'cancelled'), a(due, 'completed')]), isNull);
    });
  });
}
