import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/models/user_preferences_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';
import 'package:aficare_flutter/screens/patient/patient_settings_screen.dart';

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

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  group('effectiveTheme', () {
    test('a saved Dark is shown as Light; the others are kept', () {
      expect(UserPreferencesModel(userId: 'u', theme: AppThemePreference.dark).effectiveTheme,
          AppThemePreference.light);
      expect(UserPreferencesModel(userId: 'u', theme: AppThemePreference.light).effectiveTheme,
          AppThemePreference.light);
      expect(UserPreferencesModel(userId: 'u', theme: AppThemePreference.highContrast).effectiveTheme,
          AppThemePreference.highContrast);
    });
  });

  group('Settings', () {
    Future<void> pump(WidgetTester tester, {required String savedTheme}) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake.routeJson('/rest/v1/user_preferences', {'user_id': 'mary', 'theme': savedTheme});
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ],
        child: const MaterialApp(home: PatientSettingsScreen()),
      ));
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('offers Light and High contrast, and no Dark', (tester) async {
      await pump(tester, savedTheme: 'light');
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('High contrast'), findsOneWidget);
      expect(find.text('Dark'), findsNothing);
    });

    testWidgets('someone who chose Dark before sees Light chosen, and the page works', (tester) async {
      await pump(tester, savedTheme: 'dark');
      expect(tester.takeException(), isNull);
      final picker = tester.widget<SegmentedButton<AppThemePreference>>(
          find.byType(SegmentedButton<AppThemePreference>));
      expect(picker.selected, {AppThemePreference.light});
    });

    testWidgets('choosing High contrast saves it', (tester) async {
      await pump(tester, savedTheme: 'light');
      await tester.tap(find.text('High contrast'));
      await tester.pumpAndSettle();
      final saved = fake.requests.where((r) => r.url.path.contains('user_preferences') && r.method != 'GET').toList();
      expect(saved, isNotEmpty);
      expect((jsonDecode(saved.last.body) as Map)['theme'], 'high_contrast');
    });
  });
}
