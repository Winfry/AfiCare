import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/patient_provider.dart';
import 'package:aficare_flutter/providers/consultation_provider.dart';
import 'package:aficare_flutter/providers/prescription_provider.dart';
import 'package:aficare_flutter/providers/appointment_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/care_team_provider.dart';
import 'package:aficare_flutter/providers/expense_provider.dart';
import 'package:aficare_flutter/providers/message_provider.dart';
import 'package:aficare_flutter/providers/lab_provider.dart';
import 'package:aficare_flutter/providers/adherence_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';
import 'package:aficare_flutter/providers/triage_provider.dart';
import 'package:aficare_flutter/providers/referral_provider.dart';
import 'package:aficare_flutter/providers/provider_patient_provider.dart';
import 'package:aficare_flutter/providers/admin_user_provider.dart';
import 'package:aficare_flutter/providers/admin_facility_provider.dart';
import 'package:aficare_flutter/providers/audit_log_provider.dart';
import 'package:aficare_flutter/providers/system_settings_provider.dart';
import 'package:aficare_flutter/providers/analytics_provider.dart';
import 'package:aficare_flutter/utils/theme.dart';

/// Guard so we only call [Supabase.initialize] once per test process.
/// Supabase.initialize throws an AssertionError if called more than once.
bool _supabaseMocked = false;

const _supabaseUrl = 'https://example.supabase.co';
const _anonKey = 'dummy-anon-key';

/// A mock HTTP client that answers every request with harmless JSON so the
/// real Supabase/Gotrue/PostgREST clients run without touching the network.
///
/// - GET (list `select`) -> `[]` so `.from(...).select()` yields an empty List.
/// - Everything else   -> `{}` so JSON parsing never throws.
http.Client _buildMockClient() {
  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    if (request.method == 'GET') {
      return http.Response('[]', 200, headers: headers);
    }
    return http.Response('{}', 200, headers: headers);
  });
}

/// Lazily initializes Supabase with a mocked HTTP client. Safe to call from
/// multiple tests; only the first call actually initializes.
Future<void> ensureSupabaseMocked() async {
  if (_supabaseMocked) return;
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _anonKey,
    httpClient: _buildMockClient(),
  );
  _supabaseMocked = true;
}

/// All ChangeNotifier providers from `lib/main.dart` `AfiCareApp`. Providing
/// the full set means no `Provider.of` throws no matter which child screen
/// builds, while keeping every provider's Supabase-backed calls on the mock.
List<SingleChildWidget> _allProviders() {
  return [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => PatientProvider()),
    ChangeNotifierProvider(create: (_) => ConsultationProvider()),
    ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
    ChangeNotifierProvider(create: (_) => AppointmentProvider()),
    ChangeNotifierProvider(create: (_) => DependentProvider()),
    ChangeNotifierProvider(create: (_) => CareTeamProvider()),
    ChangeNotifierProvider(create: (_) => ExpenseProvider()),
    ChangeNotifierProvider(create: (_) => MessageProvider()),
    ChangeNotifierProvider(create: (_) => LabProvider()),
    ChangeNotifierProvider(create: (_) => AdherenceProvider()),
    ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
    ChangeNotifierProvider(create: (_) => PreferencesProvider()),
    ChangeNotifierProvider(create: (_) => TriageProvider()),
    ChangeNotifierProvider(create: (_) => ReferralProvider()),
    ChangeNotifierProvider(create: (_) => ProviderPatientProvider()),
    ChangeNotifierProvider(create: (_) => AdminUserProvider()),
    ChangeNotifierProvider(create: (_) => AdminFacilityProvider()),
    ChangeNotifierProvider(create: (_) => AuditLogProvider()),
    ChangeNotifierProvider(create: (_) => SystemSettingsProvider()),
    ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
  ];
}

/// Wraps [shell] in the same MultiProvider set plus a MaterialApp with the
/// app theme, so a shell can be pumped standalone in a widget test.
Widget buildShell(Widget shell) {
  return MultiProvider(
    providers: _allProviders(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AfiCareTheme.lightTheme,
      home: shell,
    ),
  );
}

/// Pumps [shell] a bounded number of times so infinite spinners/animations
/// (e.g. the CHW dashboard's indefinite CircularProgressIndicator) don't hang
/// `pumpAndSettle`. Returns any exception captured during the pumps.
Future<Object?> pumpShell(WidgetTester tester, Widget shell) async {
  await tester.pumpWidget(buildShell(shell));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return tester.takeException();
}
