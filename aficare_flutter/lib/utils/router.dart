import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/patient/patient_shell.dart';
import '../screens/patient/patient_dashboard.dart';
import '../screens/patient/health_summary.dart';
import '../screens/patient/share_records.dart';
import '../screens/patient/qr_scanner.dart';
import '../screens/patient/appointments_screen.dart';
import '../screens/patient/expenses_screen.dart';
import '../screens/provider/provider_shell.dart';
import '../screens/provider/provider_dashboard.dart';
import '../screens/provider/consultation_screen.dart';
import '../screens/provider/patient_access.dart';
import '../screens/provider/patient_search_screen.dart';
import '../screens/provider/patient_detail_screen.dart';
import '../screens/provider/reports_screen.dart';
import '../screens/provider/resource_dashboard_screen.dart';
import '../screens/provider/radiology_order_screen.dart';
import '../screens/provider/radiology_report_viewer_screen.dart';
import '../screens/provider/referral_tracker_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_user_management_screen.dart';
import '../screens/admin/admin_facility_management_screen.dart';
import '../screens/admin/system_settings_screen.dart';
import '../screens/admin/audit_log_screen.dart';
import '../screens/admin/reports_analytics_screen.dart';
import '../screens/web/provider_web_dashboard_screen.dart';
import '../screens/web/referral_receiving_portal_screen.dart';
import '../screens/facility_registration_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Splash Screen
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // Authentication
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/register-facility',
      builder: (context, state) => const FacilityRegistrationScreen(),
    ),

    // Patient Routes — new bottom-nav shell
    GoRoute(
      path: '/patient',
      builder: (context, state) => const PatientShell(),
      routes: [
        GoRoute(
          path: 'full',
          builder: (context, state) => const PatientDashboard(),
        ),
        GoRoute(
          path: 'health',
          builder: (context, state) => const HealthSummary(),
        ),
        GoRoute(
          path: 'share',
          builder: (context, state) => const ShareRecords(),
        ),
        GoRoute(
          path: 'scan',
          builder: (context, state) => const QRScanner(),
        ),
        GoRoute(
          path: 'appointments',
          builder: (context, state) => const AppointmentsScreen(),
        ),
        GoRoute(
          path: 'expenses',
          builder: (context, state) => const ExpensesScreen(),
        ),
      ],
    ),

    // Doctor and Nurse redirect to provider shell
    GoRoute(
      path: '/doctor',
      redirect: (context, state) => '/provider',
    ),
    GoRoute(
      path: '/nurse',
      redirect: (context, state) => '/provider',
    ),

    // Healthcare Provider Routes — new bottom-nav shell
    GoRoute(
      path: '/provider',
      builder: (context, state) => const ProviderShell(),
      routes: [
        GoRoute(
          path: 'full',
          builder: (context, state) => const ProviderDashboard(),
        ),
        GoRoute(
          path: 'search',
          builder: (context, state) => const PatientSearchScreen(),
        ),
        GoRoute(
          path: 'consultation',
          builder: (context, state) => const ConsultationScreen(),
        ),
        GoRoute(
          path: 'access',
          builder: (context, state) => const PatientAccess(),
        ),
        GoRoute(
          path: 'patient-detail/:patientId',
          builder: (context, state) {
            final patientId = state.pathParameters['patientId']!;
            return PatientDetailScreen(patientId: patientId);
          },
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: 'resources',
          builder: (context, state) => const ResourceDashboardScreen(),
        ),
        GoRoute(
          path: 'radiology-order/:patientId',
          builder: (context, state) {
            final patientId = state.pathParameters['patientId']!;
            final extra = state.extra as Map<String, String>? ?? {};
            return RadiologyOrderScreen(
              patientId: patientId,
              patientName: extra['name'] ?? 'Patient',
              medilinkId: extra['medilinkId'],
              age: extra['age'],
              gender: extra['gender'],
              bloodType: extra['bloodType'],
            );
          },
        ),
        GoRoute(
          path: 'radiology-reports/:patientId/:patientName',
          builder: (context, state) {
            final patientId = state.pathParameters['patientId']!;
            final patientName = state.pathParameters['patientName']!;
            return RadiologyReportViewerScreen(
              patientId: patientId,
              patientName: patientName,
            );
          },
        ),
        GoRoute(
          path: 'referral-tracker',
          builder: (context, state) => const ReferralTrackerScreen(),
        ),
      ],
    ),

    // Admin Routes
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
      routes: [
        GoRoute(
          path: 'users',
          builder: (context, state) => const AdminUserManagementScreen(),
        ),
        GoRoute(
          path: 'facilities',
          builder: (context, state) => const AdminFacilityManagementScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SystemSettingsScreen(),
        ),
        GoRoute(
          path: 'audit-log',
          builder: (context, state) => const AuditLogScreen(),
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const ReportsAnalyticsScreen(),
        ),
      ],
    ),

    // Web Routes
    GoRoute(
      path: '/web/provider-dashboard',
      builder: (context, state) => const ProviderWebDashboardScreen(),
    ),
    GoRoute(
      path: '/web/referral/:referralId',
      builder: (context, state) {
        final referralId = state.pathParameters['referralId']!;
        return ReferralReceivingPortalScreen(referralId: referralId);
      },
    ),
  ],
);
