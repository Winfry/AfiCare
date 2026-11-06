import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/adherence_provider.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/prescription_provider.dart';
import 'package:aficare_flutter/screens/patient/medication_tracker_screen.dart';

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

Map<String, dynamic> _dose() {
  final now = DateTime.now();
  return {
    'id': 'd1',
    'prescription_id': 'rx1',
    'patient_id': 'mary',
    'scheduled_time': DateTime(now.year, now.month, now.day, 23, 30).toIso8601String(),
    'taken_time': null,
    'skipped_reason': null,
    'status': 'pending',
    'prescriptions': {'medication_name': 'Metformin', 'dosage': '500mg'},
  };
}

void main() {
  final fake = FakeSupabase();
  const rx = '/rest/v1/prescriptions';
  const log = '/rest/v1/adherence_log';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider(create: (_) => DependentProvider()),
        ChangeNotifierProvider(create: (_) => AdherenceProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: MedicationTrackerScreen())),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester, {required int timesPerDay}) async {
    await tester.tap(find.text('+ Add').first);
    await tester.pumpAndSettle();
    final boxes = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(boxes.at(0), 'Salbutamol');
    await tester.enterText(boxes.at(1), '2 puffs');
    await tester.tap(find.text('1 time a day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$timesPerDay times a day').last);
    await tester.pumpAndSettle();
  }

  testWidgets('6 times a day saves, with six doses for today', (tester) async {
    fake.routeJson(rx, <Object?>[]);
    fake.routeJson(log, <Object?>[]);
    await pump(tester);

    await fillForm(tester, timesPerDay: 6);
    fake.routeJson(rx, {'id': 'rx-new', 'patient_id': 'mary'});
    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no crash');
    expect(find.text('Medication added. It has no alarm yet.'), findsOneWidget);
    expect(find.text('Set a reminder'), findsOneWidget, reason: 'adding sets no alarm, so one is offered');
    final saved = jsonDecode(fake.requestsTo('POST', rx).single.body) as Map;
    expect(saved['frequency'], '6 times a day');
    final doses = jsonDecode(fake.requestsTo('POST', log).first.body) as List;
    expect(doses, hasLength(6));
  });

  testWidgets('if nothing could be saved, the form stays open with what she typed', (tester) async {
    fake.routeJson(rx, <Object?>[]);
    fake.routeJson(log, <Object?>[]);
    await pump(tester);

    await fillForm(tester, timesPerDay: 5);
    fake.routeRaw(rx, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(find.textContaining("We couldn't add this medicine"), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Salbutamol'), findsOneWidget, reason: 'still in the form');
    expect(find.text('5 times a day'), findsOneWidget);
    expect(find.textContaining('Medication added'), findsNothing);
    expect(fake.requestsTo('POST', log), isEmpty);

    // Trying again works, and saves it once.
    fake.clearRoute(rx);
    fake.routeJson(rx, {'id': 'rx-new', 'patient_id': 'mary'});
    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();
    expect(find.text('Medication added. It has no alarm yet.'), findsOneWidget);
    expect(find.text('Set a reminder'), findsOneWidget, reason: 'adding sets no alarm, so one is offered');
    expect(fake.requestsTo('POST', rx), hasLength(2), reason: 'the first attempt saved nothing');
  });

  testWidgets('saved without today\'s doses says so honestly', (tester) async {
    fake.routeJson(rx, <Object?>[]);
    fake.routeJson(log, <Object?>[]);
    await pump(tester);

    await fillForm(tester, timesPerDay: 2);
    fake.routeJson(rx, {'id': 'rx-new', 'patient_id': 'mary'});
    fake.routeRaw(log, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
    await tester.tap(find.text('Save medication'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Today's doses will appear when you're back online"), findsOneWidget);
    expect(find.text('Save medication'), findsNothing, reason: 'the form closes: the medicine is saved');
  });

  testWidgets('"Mark taken" that did not save says so, instead of "Dose marked as taken"', (tester) async {
    fake.routeJson(rx, <Object?>[]);
    fake.routeJson(log, [_dose()]);
    await pump(tester);
    expect(find.text('Mark taken'), findsOneWidget);

    fake.routeJson(log, <Object?>[]); // the database changed nothing
    await tester.tap(find.text('Mark taken'));
    await tester.pumpAndSettle();

    expect(find.text('Dose marked as taken'), findsNothing);
    expect(find.textContaining("couldn't save that"), findsOneWidget);
    expect(find.text('Mark taken'), findsOneWidget, reason: 'still to take');
  });

  testWidgets('"Mark taken" that saved says so', (tester) async {
    fake.routeJson(rx, <Object?>[]);
    fake.routeJson(log, [_dose()]);
    await pump(tester);

    await tester.tap(find.text('Mark taken'));
    await tester.pumpAndSettle();
    expect(find.text('Dose marked as taken'), findsOneWidget);
  });
}
