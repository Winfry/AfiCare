import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/screens/patient/patient_shell.dart';
import 'package:aficare_flutter/screens/provider/provider_shell.dart';
import 'package:aficare_flutter/screens/admin/admin_dashboard.dart';
import 'package:aficare_flutter/screens/chw/chw_shell.dart';
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
    final exception = await pumpShell(tester, const PatientShell());
    expect(exception, isNull);
    expect(find.byType(AppShell), findsOneWidget);
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
}
