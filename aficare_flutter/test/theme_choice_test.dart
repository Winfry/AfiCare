import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/models/user_preferences_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';
import 'package:aficare_flutter/screens/patient/accessibility_settings_screen.dart';
import 'package:aficare_flutter/screens/patient/patient_settings_screen.dart';
import 'package:aficare_flutter/theme/patient_tokens.dart';

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
  tearDown(() => PT.highContrast = false);

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

  group('patient colours (PT)', () {
    test('High contrast darkens text and lines, and switching back restores them', () {
      final mutedNormal = PT.muted;
      final lineNormal = PT.line;
      PT.highContrast = true;
      expect(PT.muted, isNot(mutedNormal));
      expect(PT.line, isNot(lineNormal));
      // Darker means lower luminance: grey text becomes near-black.
      expect(PT.muted.computeLuminance(), lessThan(mutedNormal.computeLuminance()));
      expect(PT.line.computeLuminance(), lessThan(lineNormal.computeLuminance()));
      PT.highContrast = false;
      expect(PT.muted, mutedNormal);
      expect(PT.line, lineNormal);
    });

    test('every High contrast text colour reaches 7:1 on white (WCAG AAA)', () {
      PT.highContrast = true;
      double ratio(Color c) => (1.0 + 0.05) / (c.computeLuminance() + 0.05);
      for (final c in [PT.ink, PT.muted, PT.teal, PT.navy, PT.green, PT.danger, PT.warn,
                       PT.badgeOkFg, PT.badgeWarnFg, PT.badgeRedFg, PT.badgeBlueFg, PT.badgeGrayFg]) {
        expect(ratio(c), greaterThanOrEqualTo(7.0), reason: '$c');
      }
    });
  });

  Map<String, Object?> savedPrefs() {
    final writes = fake.requests
        .where((r) => r.url.path.contains('user_preferences') && r.method != 'GET')
        .toList();
    expect(writes, isNotEmpty, reason: 'something was saved');
    return jsonDecode(writes.last.body) as Map<String, Object?>;
  }

  group('Accessibility page', () {
    Future<PreferencesProvider> pump(WidgetTester tester, {Map<String, Object?> saved = const {}}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake.routeJson('/rest/v1/user_preferences', {'user_id': 'mary', 'theme': 'light', ...saved});
      final prefs = PreferencesProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: const MaterialApp(home: AccessibilitySettingsScreen()),
      ));
      await tester.pump();
      await tester.pumpAndSettle();
      return prefs;
    }

    Future<void> tapRow(WidgetTester tester, String title) async {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('has the five real settings, and no device-only switches', (tester) async {
      await pump(tester);
      for (final t in ['Text size', 'Bold text', 'High contrast', 'Reduce motion', 'Read aloud']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('saved locally on this device'), findsNothing);
      expect(find.textContaining('saved to your account'), findsOneWidget);
    });

    testWidgets('Bold text is saved to her account', (tester) async {
      await pump(tester);
      await tapRow(tester, 'Bold text');
      expect(savedPrefs()['bold_text'], isTrue);
    });

    testWidgets('High contrast is saved as the high-contrast theme', (tester) async {
      await pump(tester);
      await tapRow(tester, 'High contrast');
      expect(savedPrefs()['theme'], 'high_contrast');
    });

    testWidgets('someone who chose Dark before sees High contrast off, and the page works', (tester) async {
      await pump(tester, saved: {'theme': 'dark'});
      expect(tester.takeException(), isNull);
      final contrast = tester.widget<Switch>(find.descendant(
        of: find.ancestor(of: find.text('High contrast'), matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      ));
      expect(contrast.value, isFalse);
    });

    testWidgets('Reduce motion and Read aloud are saved', (tester) async {
      await pump(tester);
      await tapRow(tester, 'Reduce motion');
      expect(savedPrefs()['reduce_motion'], isTrue);
      await tapRow(tester, 'Read aloud');
      expect(savedPrefs()['text_to_speech'], isTrue);
    });

    testWidgets('a refused save says so and the switch goes back', (tester) async {
      final prefs = await pump(tester);
      fake.routeRaw('/rest/v1/user_preferences',
          http.Response('{"message":"denied"}', 403, headers: {'content-type': 'application/json'}));
      await tapRow(tester, 'Bold text');
      expect(find.textContaining("couldn't save that setting"), findsOneWidget);
      expect(prefs.prefs!.boldText, isFalse);
    });

    testWidgets('when her settings did not load, it says so and saves nothing over them', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake.routeRaw('/rest/v1/user_preferences',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ],
        child: const MaterialApp(home: AccessibilitySettingsScreen()),
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Could not load your settings'), findsOneWidget);
      await tester.tap(find.text('Bold text'));
      await tester.pumpAndSettle();
      expect(fake.requests.where((r) => r.url.path.contains('user_preferences') && r.method != 'GET'),
          isEmpty);
    });
  });

  group('Settings', () {
    Future<void> pump(WidgetTester tester, {Map<String, Object?> saved = const {}}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake.routeJson('/rest/v1/user_preferences', {'user_id': 'mary', 'theme': 'light', ...saved});
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

    testWidgets('no switches that do nothing: Push, Email and SMS are gone', (tester) async {
      await pump(tester);
      expect(find.text('Push Notifications'), findsNothing);
      expect(find.text('Email Updates'), findsNothing);
      expect(find.text('SMS Alerts'), findsNothing);
      expect(find.text('Medicine alarms'), findsOneWidget);
      expect(find.textContaining("doesn't send text messages (SMS) or emails yet"), findsOneWidget);
    });

    testWidgets('accessibility is one link that says what is on', (tester) async {
      await pump(tester, saved: {'bold_text': true, 'theme': 'high_contrast'});
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('On: bold text, high contrast'), findsOneWidget);
      expect(find.byType(SegmentedButton<AppThemePreference>), findsNothing);
      expect(find.text('Dark'), findsNothing);
    });

    testWidgets('no Français; Kiswahili says how much is translated', (tester) async {
      await pump(tester, saved: {'language': 'fr'});
      expect(find.text('English'), findsOneWidget, reason: 'a saved Français shows as the English it got');
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('Français'), findsNothing);
      expect(find.text('Kiswahili'), findsOneWidget);
      expect(find.text('Only the home page is in Kiswahili so far.'), findsOneWidget);
    });
  });
}
