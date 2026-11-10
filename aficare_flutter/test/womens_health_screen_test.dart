import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/models/pregnancy_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';
import 'package:aficare_flutter/screens/patient/womens_health_screen.dart';
import 'package:aficare_flutter/services/womens_health_service.dart';

import 'helpers/fake_pregnancy_provider.dart';
import 'helpers/smoke_harness.dart';

/// Her private Women's health record, in memory.
class _FakeRecords extends WomensHealthService {
  _FakeRecords(this.stored) : super(null);

  Map<String, dynamic>? stored;
  bool saveSucceeds = true;
  bool loadFails = false;
  final saves = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> load(String patientId) async {
    if (loadFails) throw Exception('offline');
    return stored == null ? null : Map<String, dynamic>.from(stored!);
  }

  @override
  Future<void> save(String patientId, Map<String, dynamic> record) async {
    saves.add(Map<String, dynamic>.from(record));
    if (!saveSucceeds) throw Exception('refused');
    stored = Map<String, dynamic>.from(record);
  }
}

/// An AuthProvider with a signed-in patient, without touching Supabase.
/// Its account row is only written to take an old copy out of it.
class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);

  UserModel _user;
  final accountSaves = <Map<String, dynamic>>[];

  @override
  UserModel? get currentUser => _user;

  @override
  Future<bool> updateProfile({String? fullName, String? phone, Map<String, dynamic>? metadata}) async {
    accountSaves.add(Map<String, dynamic>.from(metadata ?? const {}));
    _user = UserModel(
      id: _user.id,
      email: _user.email,
      fullName: _user.fullName,
      role: _user.role,
      createdAt: _user.createdAt,
      metadata: metadata,
    );
    notifyListeners();
    return true;
  }
}

UserModel _patient(Map<String, dynamic>? oldCopy) => UserModel(
      id: 'u1',
      email: 'test@example.com',
      fullName: 'Amina Test',
      role: UserRole.patient,
      createdAt: DateTime(2026, 1, 1),
      metadata: {
        'blood_type': 'O+',
        if (oldCopy != null) 'maternal_health': oldCopy,
      },
    );

/// [maternal] is her private record; [oldCopy] is one an earlier version
/// left in the account row.
Future<(_FakeRecords, _FakeAuth)> _pump(
  WidgetTester tester, {
  required Size size,
  Map<String, dynamic>? maternal,
  Map<String, dynamic>? oldCopy,
  FakePregnancyProvider? pregnancies,
  bool loadFails = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth(_patient(oldCopy));
  final records = _FakeRecords(maternal)..loadFails = loadFails;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
      ChangeNotifierProvider<PregnancyProvider>.value(value: pregnancies ?? FakePregnancyProvider()),
    ],
    child: MaterialApp(home: Scaffold(body: WomensHealthScreen(service: records))),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return (records, auth);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // Outside the test body: Supabase starts a refresh timer when it
  // initialises, which a widget test would report as left pending.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ensureSupabaseMocked();
  });

  for (final (name, size) in [('phone', const Size(375, 812)), ('desktop', const Size(1280, 900))]) {
    testWidgets('lays out on a $name without overflow', (tester) async {
      await _pump(tester, size: size, maternal: {
        'pregnancy_status': 'trying',
        'menstrual_pain': 8,
        'cycle_length': 40,
        'last_pap_smear': '2020-01-01',
      });
      final error = tester.takeException();
      // Print the whole report, so an overflow names the widget at fault.
      if (error is FlutterError) debugPrint(error.toStringDeep());
      expect(error, isNull);
      expect(find.text("Women's health"), findsOneWidget);
      // Old-dashboard data shows up on the new page.
      expect(find.text('40 days'), findsOneWidget);
      expect(find.text('Getting ready for pregnancy'), findsOneWidget);
      expect(find.text("You don't have to put up with this"), findsOneWidget);
      expect(find.text('Due now'), findsOneWidget);
    });
  }

  testWidgets('choosing a life stage saves it to her private record', (tester) async {
    final (records, auth) = await _pump(tester, size: const Size(1280, 900));
    await tester.tap(find.text('Trying to conceive'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(records.saves, hasLength(1));
    expect(records.saves.single['pregnancy_status'], 'trying');
    expect(auth.accountSaves, isEmpty, reason: 'nothing goes into the account row any more');
    expect(find.text('✓ Saved'), findsOneWidget);
    expect(find.text('Getting ready for pregnancy'), findsOneWidget);
  });

  group('pregnancy', () {
    final today = DateUtils.dateOnly(DateTime.now());
    Pregnancy ongoing() => Pregnancy(
          id: 'p1',
          patientId: 'u1',
          lmpDate: today.subtract(const Duration(days: 70)),
          dueDate: Pregnancy.dueDateFromLmp(today.subtract(const Duration(days: 70))),
        );

    testWidgets('choosing Pregnant starts a pregnancy record first', (tester) async {
      final pregnancies = FakePregnancyProvider();
      final (records, _) = await _pump(tester, size: const Size(1280, 900), pregnancies: pregnancies);

      await tester.tap(find.text('Pregnant'));
      await tester.pumpAndSettle();
      expect(find.text('Tell us about your pregnancy'), findsOneWidget);

      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(pregnancies.started, hasLength(1));
      expect(pregnancies.started.single.dueDateSource, 'lmp');
      expect(records.saves.single['pregnancy_status'], 'pregnant');
      // The default date is 8 weeks ago.
      expect(find.textContaining('Week 8 · due'), findsOneWidget);
    });

    testWidgets('closing the form without saving changes nothing', (tester) async {
      final pregnancies = FakePregnancyProvider();
      final (records, _) = await _pump(tester, size: const Size(1280, 900), pregnancies: pregnancies);

      await tester.tap(find.text('Pregnant'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(pregnancies.started, isEmpty);
      expect(records.saves, isEmpty);
    });

    testWidgets('an ongoing pregnancy shows as Pregnant whatever was saved before', (tester) async {
      await _pump(
        tester,
        size: const Size(1280, 900),
        maternal: {'pregnancy_status': 'not_pregnant'},
        pregnancies: FakePregnancyProvider(pregnancies: [ongoing()]),
      );
      expect(find.textContaining('Week 10 · due'), findsOneWidget);
    });

    testWidgets('while pregnant, the period tile is paused, not "days late"', (tester) async {
      await _pump(
        tester,
        size: const Size(1280, 900),
        pregnancies: FakePregnancyProvider(pregnancies: [ongoing()]),
      );
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('days late'), findsNothing);
    });

    testWidgets('"Recently had a baby" closes the pregnancy as a birth', (tester) async {
      final pregnancies = FakePregnancyProvider(pregnancies: [ongoing()]);
      final (records, _) = await _pump(tester, size: const Size(1280, 900), pregnancies: pregnancies);

      await tester.tap(find.text('Recently had a baby'));
      await tester.pumpAndSettle();
      expect(find.text('Congratulations'), findsOneWidget);
      expect(find.text('What happened?'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(pregnancies.ended.single.$2, 'birth');
      expect(records.saves.single['pregnancy_status'], 'postpartum');
    });

    testWidgets('"Not pregnant" asks how it ended, and "rather not say" is enough', (tester) async {
      final pregnancies = FakePregnancyProvider(pregnancies: [ongoing()]);
      await _pump(tester, size: const Size(1280, 900), pregnancies: pregnancies);

      await tester.tap(find.text('Not pregnant'));
      await tester.pumpAndSettle();
      expect(find.text('What happened?'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(pregnancies.ended, isEmpty);
      expect(find.textContaining("I'd rather not say\"."), findsOneWidget);

      await tester.tap(find.text("I'd rather not say"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(pregnancies.ended.single.$2, 'not_said');
    });
  });

  testWidgets('a refused save is undone on screen and reported', (tester) async {
    final (records, _) = await _pump(tester, size: const Size(1280, 900), maternal: {'pregnancy_status': 'not_pregnant'});
    records.saveSucceeds = false;
    await tester.tap(find.text('Trying to conceive'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Not saved, please try again'), findsOneWidget);
    expect(find.text('Getting ready for pregnancy'), findsNothing);
    expect(find.textContaining("We couldn't save that"), findsOneWidget);
  });

  testWidgets('logging a period today predicts the next one', (tester) async {
    final (records, _) = await _pump(tester, size: const Size(1280, 900));
    await tester.tap(find.text('My period started today'));
    await tester.pump(const Duration(milliseconds: 300));

    final saved = records.saves.single;
    final today = DateUtils.dateOnly(DateTime.now());
    expect(saved['last_period_start'], today.toIso8601String().split('T').first);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('My period started today'), findsNothing);
  });

  group('privacy', () {
    testWidgets('an old copy in the account row is moved to her private record and removed', (tester) async {
      final (records, auth) = await _pump(
        tester,
        size: const Size(1280, 900),
        oldCopy: {'pregnancy_status': 'trying', 'cycle_length': 40},
      );

      expect(records.stored, {'pregnancy_status': 'trying', 'cycle_length': 40});
      expect(auth.accountSaves.single.containsKey('maternal_health'), isFalse);
      expect(auth.accountSaves.single['blood_type'], 'O+', reason: 'the rest of the account row is kept');
      expect(find.text('40 days'), findsOneWidget, reason: 'nothing is lost');
    });

    testWidgets('her private record wins over an old copy, which is left alone', (tester) async {
      final (records, auth) = await _pump(
        tester,
        size: const Size(1280, 900),
        maternal: {'cycle_length': 30},
        oldCopy: {'cycle_length': 40},
      );
      expect(find.text('30 days'), findsOneWidget);
      expect(records.saves, isEmpty);
      expect(auth.accountSaves, isEmpty);
    });

    testWidgets('if her record cannot be loaded it says so, and does not fall back to the old copy',
        (tester) async {
      final (records, _) = await _pump(
        tester,
        size: const Size(1280, 900),
        oldCopy: {'cycle_length': 40},
        loadFails: true,
      );
      expect(find.text("Could not load your women's health record"), findsOneWidget);
      expect(find.text('40 days'), findsNothing);

      records.loadFails = false;
      records.stored = {'cycle_length': 33};
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('33 days'), findsOneWidget);
    });

    testWidgets('the page says only she can see it, and that a pregnancy is shared', (tester) async {
      await _pump(tester, size: const Size(1280, 900));
      expect(find.textContaining('Only you.'), findsOneWidget);
      expect(find.textContaining('caregivers cannot see them'), findsOneWidget);
      expect(find.textContaining('A pregnancy is different'), findsOneWidget);
      expect(find.textContaining('Anyone you have given caregiver access'), findsNothing);
    });
  });
}
