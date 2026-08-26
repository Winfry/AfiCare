import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/consultation_provider.dart';
import 'providers/prescription_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/dependent_provider.dart';
import 'providers/care_team_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/message_provider.dart';
import 'providers/lab_provider.dart';
import 'providers/adherence_provider.dart';
import 'providers/patient_profile_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/triage_provider.dart';
import 'providers/referral_provider.dart';
import 'providers/provider_patient_provider.dart';
import 'providers/admin_user_provider.dart';
import 'providers/admin_facility_provider.dart';
import 'providers/audit_log_provider.dart';
import 'providers/system_settings_provider.dart';
import 'providers/analytics_provider.dart';
import 'models/user_preferences_model.dart';
import 'utils/theme.dart';
import 'utils/router.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    setUrlStrategy(const HashUrlStrategy());
  }

  String? initError;

  try {
    await Hive.initFlutter();
  } catch (e) {
    initError = 'Offline storage init failed: $e';
    debugPrint(initError);
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    initError = 'Network init failed: $e';
    debugPrint(initError);
  }

  // Required before DateFormat can be used with an explicit locale
  // (the patient dashboard formats dates in 'en' and 'sw').
  try {
    await initializeDateFormatting('en');
    await initializeDateFormatting('sw');
  } catch (e) {
    debugPrint('DateFormat init failed: $e');
  }

  // Catch any uncaught Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runApp(initError != null ? ErrorApp(error: initError) : const AfiCareApp());
}

class AfiCareApp extends StatelessWidget {
  const AfiCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
      ],
      child: const _RootApp(),
    );
  }
}

/// App root. Rebuilds on preference changes so the active theme,
/// text scaling and reduced-motion setting apply app-wide immediately.
class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null && id != _loadedUserId) {
      _loadedUserId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<PreferencesProvider>(context, listen: false).loadPreferences(id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<PreferencesProvider>(context).prefs;
    final themePref = prefs?.theme ?? AppThemePreference.light;
    final textScale = prefs?.textScale ?? 1.0;
    final reduceMotion = prefs?.reduceMotion ?? false;

    final ThemeData theme = switch (themePref) {
      AppThemePreference.light => AfiCareTheme.lightTheme,
      AppThemePreference.dark => AfiCareTheme.darkTheme,
      AppThemePreference.highContrast => AfiCareTheme.highContrastTheme,
    };

    return MaterialApp.router(
      title: 'AfiCare MediLink',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: AfiCareTheme.darkTheme,
      themeMode: themePref == AppThemePreference.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        );
      },
      routerConfig: appRouter,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'AfiCare failed to start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your internet connection and restart the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
