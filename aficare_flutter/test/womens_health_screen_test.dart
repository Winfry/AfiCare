import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/screens/patient/womens_health_screen.dart';

import 'helpers/smoke_harness.dart';

/// An AuthProvider with a signed-in patient whose saves can be made to
/// succeed or fail, without touching Supabase.
class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);

  UserModel _user;
  bool saveSucceeds = true;
  final saves = <Map<String, dynamic>>[];

  @override
  UserModel? get currentUser => _user;

  @override
  Future<bool> updateProfile({String? fullName, String? phone, Map<String, dynamic>? metadata}) async {
    saves.add(Map<String, dynamic>.from(metadata ?? const {}));
    if (!saveSucceeds) return false;
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

UserModel _patient(Map<String, dynamic>? maternal) => UserModel(
      id: 'u1',
      email: 'test@example.com',
      fullName: 'Amina Test',
      role: UserRole.patient,
      createdAt: DateTime(2026, 1, 1),
      metadata: {
        'blood_type': 'O+',
        if (maternal != null) 'maternal_health': maternal,
      },
    );

Future<_FakeAuth> _pump(WidgetTester tester, {required Size size, Map<String, dynamic>? maternal}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth(_patient(maternal));
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
    ],
    child: const MaterialApp(home: Scaffold(body: WomensHealthScreen())),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return auth;
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

  testWidgets('choosing a life stage saves it and keeps other metadata', (tester) async {
    final auth = await _pump(tester, size: const Size(1280, 900));
    await tester.tap(find.text('Pregnant'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.saves, hasLength(1));
    expect(auth.saves.single['blood_type'], 'O+');
    expect((auth.saves.single['maternal_health'] as Map)['pregnancy_status'], 'pregnant');
    expect(find.text('✓ Saved'), findsOneWidget);
    expect(find.textContaining('Maternal care'), findsOneWidget);
  });

  testWidgets('a refused save is undone on screen and reported', (tester) async {
    final auth = await _pump(tester, size: const Size(1280, 900), maternal: {'pregnancy_status': 'not_pregnant'});
    auth.saveSucceeds = false;
    await tester.tap(find.text('Trying to conceive'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Not saved, please try again'), findsOneWidget);
    expect(find.text('Getting ready for pregnancy'), findsNothing);
    expect(find.textContaining("We couldn't save that"), findsOneWidget);
  });

  testWidgets('logging a period today predicts the next one', (tester) async {
    final auth = await _pump(tester, size: const Size(1280, 900));
    await tester.tap(find.text('My period started today'));
    await tester.pump(const Duration(milliseconds: 300));

    final saved = auth.saves.single['maternal_health'] as Map;
    final today = DateUtils.dateOnly(DateTime.now());
    expect(saved['last_period_start'], today.toIso8601String().split('T').first);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('My period started today'), findsNothing);
  });
}
