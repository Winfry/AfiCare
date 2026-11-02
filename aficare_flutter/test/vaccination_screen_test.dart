import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/dependent_profile_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/screens/patient/vaccination_screen.dart';

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

/// Mary, optionally looking at her baby Brian's profile.
class _FakeDependants extends DependentProvider {
  _FakeDependants(this.brian);
  final DependentProfileModel? brian;

  @override
  String? get ownId => 'mary';
  @override
  String? get activePatientId => brian?.id ?? 'mary';
  @override
  bool get isViewingDependent => brian != null;
  @override
  DependentProfileModel? get activeDependent => brian;
  @override
  List<DependentProfileModel> get dependents => [if (brian != null) brian!];
}

DependentProfileModel _brian(DateTime? dob) => DependentProfileModel(
      id: 'brian',
      guardianId: 'mary',
      fullName: 'Brian Otieno',
      relationship: 'child',
      dateOfBirth: dob,
      createdAt: DateTime(2026, 1, 1),
    );

Map<String, dynamic> _given(String name, {String status = 'completed'}) => {
      'id': name,
      'patient_id': 'brian',
      'vaccine_name': name,
      'date_given': '2026-09-01T09:00:00.000',
      'status': status,
    };

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, {DependentProfileModel? brian}) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<DependentProvider>(create: (_) => _FakeDependants(brian)),
        ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: VaccinationScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder dueCard(String name) => find.ancestor(of: find.text(name), matching: find.byType(Row));

  testWidgets('an adult is not told every baby vaccine is overdue', (tester) async {
    fake.routeJson('/rest/v1/patients', {'date_of_birth': '1990-05-01'});
    await pump(tester);

    expect(find.text('OVERDUE'), findsNothing);
    expect(find.text('DUE'), findsNothing);
    expect(find.text('Due / Overdue'), findsNothing);
    expect(find.text('This schedule is for young children'), findsOneWidget);
    expect(find.textContaining('tetanus booster'), findsOneWidget);
    expect(find.text('0'), findsWidgets, reason: 'nothing due');
    expect(find.textContaining('yrs'), findsOneWidget, reason: 'age in years, not thousands of weeks');
  });

  testWidgets('without a date of birth nothing is called due', (tester) async {
    await pump(tester, brian: _brian(null));

    expect(find.text('DUE'), findsNothing);
    expect(find.text('OVERDUE'), findsNothing);
    expect(find.text('Add a date of birth to see what is due'), findsOneWidget);
    expect(find.textContaining("Brian's date of birth"), findsOneWidget);
  });

  testWidgets('a baby: each dose counts on its own, so OPV 0 does not tick OPV 1-3', (tester) async {
    final dob = DateTime.now().subtract(const Duration(days: 7 * 7));
    fake.routeJson('/rest/v1/vaccination_records', [
      _given('BCG'),
      _given('OPV 0'),
      _given('HepB 0'),
      _given('PCV 1', status: 'scheduled'),
    ]);
    await pump(tester, brian: _brian(dob));

    expect(find.text("Brian's vaccinations"), findsOneWidget);
    // At 7 weeks: the four 6-week doses are due, and only those.
    expect(find.text('DUE'), findsNWidgets(4));
    expect(find.text('OVERDUE'), findsNothing);
    for (final name in ['OPV 1', 'Penta 1', 'PCV 1', 'Rota 1']) {
      expect(find.descendant(of: dueCard('DUE'), matching: find.text(name)), findsWidgets, reason: name);
    }
    expect(find.text('3'), findsWidgets, reason: 'three given; the planned PCV 1 is not counted');
  });

  testWidgets('a toddler who missed doses sees them overdue with a catch-up note', (tester) async {
    final dob = DateTime.now().subtract(const Duration(days: 7 * 30));
    fake.routeJson('/rest/v1/vaccination_records', [
      for (final n in ['BCG', 'OPV 0', 'HepB 0', 'OPV 1', 'Penta 1', 'PCV 1', 'Rota 1', 'OPV 2', 'Penta 2', 'PCV 2', 'Rota 2'])
        _given(n),
    ]);
    await pump(tester, brian: _brian(dob));

    expect(find.text('OVERDUE'), findsNWidgets(4), reason: 'OPV 3, Penta 3, PCV 3, IPV');
    expect(find.text('Ask your clinic about a catch-up dose'), findsNWidgets(4));
    expect(find.text('DUE'), findsNothing, reason: 'the 9-month doses are not due yet');
  });

  testWidgets('recording Penta 1 sets the next dose for when Brian turns 10 weeks', (tester) async {
    final today = DateTime.now();
    final dob = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 7 * 6));
    await pump(tester, brian: _brian(dob));

    await tester.tap(find.text('Add a record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaccine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penta 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Record'));
    await tester.pumpAndSettle();

    final body = jsonDecode(fake.requestsTo('POST', 'vaccination_records').single.body) as Map;
    expect(body['vaccine_name'], 'Penta 1');
    expect(body['patient_id'], 'brian');
    final next = DateTime.parse(body['next_due_date'] as String);
    expect(next, dob.add(const Duration(days: 7 * 10)), reason: 'Penta 2 is due at 10 weeks old, not 4 weeks from today');
  });
}
