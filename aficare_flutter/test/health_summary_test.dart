import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/consultation_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
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
}
