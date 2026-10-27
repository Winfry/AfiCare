import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/models/anc_visit_model.dart';
import 'package:aficare_flutter/models/pregnancy_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';
import 'package:aficare_flutter/screens/patient/anc_screen.dart';

import 'helpers/fake_pregnancy_provider.dart';
import 'helpers/smoke_harness.dart';

class _SignedIn extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'u1',
        email: 'amina@example.com',
        fullName: 'Amina Test',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
      );
}

Future<void> _pump(WidgetTester tester, FakePregnancyProvider pregnancies, {Size size = const Size(1280, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _SignedIn()),
      ChangeNotifierProvider<PregnancyProvider>.value(value: pregnancies),
    ],
    child: const MaterialApp(home: AncScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ensureSupabaseMocked();
  });

  final today = DateUtils.dateOnly(DateTime.now());
  final lmp = today.subtract(const Duration(days: 24 * 7 + 3));
  final ongoing = Pregnancy(id: 'p1', patientId: 'u1', lmpDate: lmp, dueDate: Pregnancy.dueDateFromLmp(lmp));
  final past = Pregnancy(
    id: 'p0',
    patientId: 'u1',
    dueDate: DateTime(2024, 6, 1),
    dueDateSource: 'scan',
    status: 'ended',
    outcome: 'birth',
    endedOn: DateTime(2024, 5, 28),
  );
  AncVisit visit(String id, int n, int weeks, {List<String> danger = const []}) => AncVisit(
        id: id,
        patientId: 'u1',
        pregnancyId: 'p1',
        visitNumber: n,
        gestationalWeeks: weeks,
        trimester: Pregnancy.trimesterForWeeks(weeks),
        visitDate: today.subtract(Duration(days: (24 - weeks) * 7)),
        systolicBP: 110,
        diastolicBP: 70,
        weight: 66,
        dangerSigns: danger,
        facility: 'Tamia Hospital',
      );

  for (final (name, size) in [('phone', const Size(375, 812)), ('desktop', const Size(1280, 900))]) {
    testWidgets('lays out on a $name without overflow', (tester) async {
      await _pump(
        tester,
        FakePregnancyProvider(
          pregnancies: [ongoing, past],
          visits: [visit('v2', 2, 20, danger: ['Severe headache']), visit('v1', 1, 12)],
        ),
        size: size,
      );
      final error = tester.takeException();
      if (error is FlutterError) debugPrint(error.toStringDeep());
      expect(error, isNull);
      expect(find.text('Week 24 · second trimester'), findsOneWidget);
      expect(find.textContaining('2 antenatal visits done, 6 to go'), findsOneWidget);
      expect(find.text('Visit 2 · 20 weeks'), findsOneWidget);
      expect(find.text('Danger signs'), findsOneWidget);
      expect(find.text('Past pregnancies'), findsOneWidget);
      expect(find.textContaining('Baby born'), findsOneWidget);
    });
  }

  testWidgets('with no pregnancy, it asks to start one', (tester) async {
    await _pump(tester, FakePregnancyProvider());
    expect(find.text('Tell us about your pregnancy'), findsOneWidget);
    expect(find.text('Add a visit'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('What do you know?'), findsOneWidget);
  });

  testWidgets('a due date from a scan saves as a scan date', (tester) async {
    final pregnancies = FakePregnancyProvider();
    await _pump(tester, pregnancies);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(pregnancies.started.single.dueDateSource, 'scan');
    expect(pregnancies.started.single.lmpDate, isNull);
    expect(find.textContaining('Week '), findsWidgets);
  });

  testWidgets('a visit is checked before it is saved', (tester) async {
    final pregnancies = FakePregnancyProvider(pregnancies: [ongoing]);
    await _pump(tester, pregnancies);

    await tester.tap(find.text('Add a visit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '400');
    await tester.ensureVisible(find.text('Save visit'));
    await tester.tap(find.text('Save visit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('should be a number between 60 and 250'), findsOneWidget);
    expect(pregnancies.addedVisits, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), '118');
    await tester.ensureVisible(find.text('Save visit'));
    await tester.tap(find.text('Save visit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter both blood pressure numbers, or neither.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '76');
    await tester.ensureVisible(find.text('Save visit'));
    await tester.tap(find.text('Save visit'));
    await tester.pumpAndSettle();

    final saved = pregnancies.addedVisits.single;
    expect(saved.systolicBP, 118);
    expect(saved.diastolicBP, 76);
    expect(saved.gestationalWeeks, 24);
    expect(find.text('Visit 1 · 24 weeks'), findsOneWidget);
  });
}
