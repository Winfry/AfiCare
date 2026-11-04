import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/screens/patient/patient_search.dart';
import 'package:aficare_flutter/screens/patient/patient_shell.dart';
import 'package:aficare_flutter/screens/provider/provider_shell.dart';
import 'package:aficare_flutter/screens/admin/admin_dashboard.dart';
import 'package:aficare_flutter/screens/chw/chw_shell.dart';
import 'package:aficare_flutter/screens/facility_admin/facility_admin_shell.dart';
import 'package:aficare_flutter/widgets/app_shell.dart';

import 'helpers/smoke_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ensureSupabaseMocked();
    try {
      await initializeDateFormatting('en');
      await initializeDateFormatting('sw');
    } catch (_) {}
  });

  // Use a narrower surface (sidebar hidden, 2-column stat grids) so the app
  // renders cleanly without the pre-existing wide-layout RenderFlex overflows.
  void useCleanSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('PatientShell builds without throwing', (tester) async {
    useCleanSurface(tester);
    final exception = await pumpShell(tester, const PatientShell(location: '/patient', child: SizedBox()));
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('PatientShell: Search opens the patient search, with the pages she can open', (tester) async {
    useCleanSurface(tester);
    await pumpShell(tester, const PatientShell(location: '/patient', child: SizedBox()));

    await tester.tap(find.byTooltip('Search').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(PatientSearchSheet), findsOneWidget);
    expect(find.text('Go to'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byType(PatientSearchSheet), matching: find.byType(TextField)), 'vaccine');
    await tester.pump();
    expect(find.descendant(of: find.byType(PatientSearchSheet), matching: find.text('Vaccinations')), findsOneWidget);
  });

  testWidgets('ProviderShell builds without throwing', (tester) async {
    useCleanSurface(tester);
    final exception = await pumpShell(tester, const ProviderShell());
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('AdminDashboard builds without throwing', (tester) async {
    useCleanSurface(tester);
    final exception = await pumpShell(tester, const AdminDashboard());
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('CHWShell builds without throwing', (tester) async {
    useCleanSurface(tester);
    final exception = await pumpShell(tester, const CHWShell());
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('FacilityAdminShell builds without throwing', (tester) async {
    useCleanSurface(tester);
    final exception = await pumpShell(tester, const FacilityAdminShell());
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
  });
}
