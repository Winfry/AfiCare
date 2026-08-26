import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../screens/landing_screen.dart';
import '../screens/login_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../presentation/auth/register/role_selection/register_role_screen.dart';
import '../presentation/auth/register/patient/patient_register_screen.dart';
import '../presentation/auth/register/clinician/clinician_register_screen.dart';
import '../presentation/auth/register/admin/admin_register_screen.dart';
import '../screens/patient/patient_shell.dart';
import '../screens/patient/patient_onboarding_screen.dart';
import '../screens/patient/patient_dashboard.dart';
import '../screens/patient/patient_profile_screen.dart';
import '../screens/patient/messages_screen.dart';
import '../screens/patient/health_summary.dart';
import '../screens/patient/share_records.dart';
import '../screens/patient/qr_scanner.dart';
import '../screens/patient/appointments_screen.dart';
import '../screens/patient/expenses_screen.dart';
import '../screens/patient/mental_health_screen.dart';
import '../screens/patient/emergency_screen.dart';
import '../screens/patient/anc_screen.dart';
import '../screens/patient/vaccination_screen.dart';
import '../screens/patient/medication_reminder_screen.dart';
import '../screens/patient/mens_health_screen.dart';
import '../screens/patient/caregiver_portal_screen.dart';
import '../screens/patient/receipt_upload_screen.dart';
import '../screens/patient/drug_interaction_screen.dart';
import '../screens/patient/medication_cost_screen.dart';
import '../screens/patient/insurance_claims_screen.dart';
import '../screens/patient/accessibility_settings_screen.dart';
import '../screens/chw/chw_shell.dart';
import '../screens/chw/chw_new_visit_screen.dart';
import '../screens/chw/chw_patient_search.dart';
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
import '../screens/provider/provider_inbox_screen.dart';
import '../screens/provider/provider_settings_screen.dart';
import '../screens/provider/adherence_monitoring_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_user_management_screen.dart';
import '../screens/admin/admin_facility_management_screen.dart';
import '../screens/admin/system_settings_screen.dart';
import '../screens/admin/audit_log_screen.dart';
import '../screens/admin/reports_analytics_screen.dart';
import '../screens/web/provider_web_dashboard_screen.dart';
import '../screens/web/referral_receiving_portal_screen.dart';
import '../screens/facility_registration_screen.dart';

/// Paths that are accessible without authentication.
const _publicPaths = {
  '/',
  '/login',
  '/register',
  '/register/patient',
  '/register/doctor',
  '/register/nurse',
  '/register/radiologist',
  '/register/admin',
  '/register-facility',
  '/forgot-password',
};

/// Paths that are accessible without authentication but only for
/// new users (onboarding).
const _onboardingPaths = {
  '/onboarding',
};

/// Resolves the user's role from the [_UserProfileCache] or Supabase session.
/// Returns null if not authenticated.
class _UserProfileCache {
  static UserRole? _cachedRole;

  static void update(UserModel user) {
    _cachedRole = user.role;
  }

  static void clear() {
    _cachedRole = null;
  }

  static UserRole? get role => _cachedRole;
}

/// Notifier that triggers GoRouter redirect re-evaluation on auth state changes.
final ValueNotifier<int> _authRefreshNotifier = ValueNotifier<int>(0);

/// Call this whenever AuthProvider updates `_currentUser` so the
/// router's redirect has the latest role info without querying Supabase.
void updateRouterProfile(UserModel? user) {
  if (user != null) {
    _UserProfileCache.update(user);
  } else {
    _UserProfileCache.clear();
  }
  _authRefreshNotifier.value++;
}

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  refreshListenable: _authRefreshNotifier,

  redirect: (context, state) {
    final location = state.matchedLocation;
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    // ── Public routes — always accessible ─────────────────────
    if (_publicPaths.contains(location)) {
      // If logged in and visiting /login or /register, redirect to dashboard
      if (isLoggedIn && _UserProfileCache.role != null) {
        return _dashboardForRole(_UserProfileCache.role!);
      }
      return null; // allow
    }

    // ── Onboarding — only for logged-in users ─────────────────
    if (_onboardingPaths.contains(location)) {
      if (!isLoggedIn) return '/login';
      return null;
    }

    // ── Protected routes — require auth ───────────────────────
    if (!isLoggedIn) return '/login';

    final role = _UserProfileCache.role;

    // Profile not loaded yet — prevent routing to protected pages
    if (role == null) return '/login';

    // Role-based access control
    if (location.startsWith('/admin')) {
      if (role != UserRole.admin) {
        return _dashboardForRole(role);
      }
      return null;
    }

    if (location.startsWith('/provider') || location == '/doctor' || location == '/nurse') {
      if (role != UserRole.doctor && role != UserRole.nurse && role != UserRole.radiologist) {
        return _dashboardForRole(role);
      }
      return null;
    }

    if (location.startsWith('/chw')) {
      if (role != UserRole.chw) {
        return _dashboardForRole(role);
      }
      return null;
    }

    if (location.startsWith('/patient')) {
      if (role != UserRole.patient) {
        return _dashboardForRole(role);
      }
      return null;
    }

    // Web routes — provider-only for now
    if (location.startsWith('/web/')) {
      if (role != UserRole.doctor && role != UserRole.nurse && role != UserRole.radiologist) {
        return _dashboardForRole(role);
      }
      return null;
    }

    // ── Root "/" — redirect logged-in users to their dashboard ─
    if (location == '/') {
      return _dashboardForRole(role);
    }

    return null; // allow
  },

  routes: [
    // Landing Screen
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),

    // Authentication
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterRoleScreen(),
      routes: [
        GoRoute(
          path: 'patient',
          builder: (context, state) => const PatientRegisterScreen(),
        ),
        GoRoute(
          path: 'doctor',
          builder: (context, state) => const ClinicianRegisterScreen(initialRole: 'doctor'),
        ),
        GoRoute(
          path: 'nurse',
          builder: (context, state) => const ClinicianRegisterScreen(initialRole: 'nurse'),
        ),
        GoRoute(
          path: 'radiologist',
          builder: (context, state) => const ClinicianRegisterScreen(initialRole: 'radiologist'),
        ),
        GoRoute(
          path: 'admin',
          builder: (context, state) => const AdminRegisterScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/register-facility',
      builder: (context, state) => const FacilityRegistrationScreen(),
    ),

    // First-run onboarding wizard (new patients)
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const PatientOnboardingScreen(),
    ),

    // Patient Routes — bottom-nav shell
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
        GoRoute(
          path: 'mental-health',
          builder: (context, state) => const MentalHealthScreen(),
        ),
        GoRoute(
          path: 'emergency',
          builder: (context, state) => const EmergencyScreen(),
        ),
        GoRoute(
          path: 'anc',
          builder: (context, state) => const AncScreen(),
        ),
        GoRoute(
          path: 'vaccinations',
          builder: (context, state) => const VaccinationScreen(),
        ),
        GoRoute(
          path: 'medication-reminders',
          builder: (context, state) => const MedicationReminderScreen(),
        ),
        GoRoute(
          path: 'mens-health',
          builder: (context, state) => const MensHealthScreen(),
        ),
        GoRoute(
          path: 'caregiver-portal',
          builder: (context, state) => const CaregiverPortalScreen(),
        ),
        GoRoute(
          path: 'receipt-upload',
          builder: (context, state) => const ReceiptUploadScreen(),
        ),
        GoRoute(
          path: 'drug-interactions',
          builder: (context, state) => const DrugInteractionScreen(),
        ),
        GoRoute(
          path: 'medication-costs',
          builder: (context, state) => const MedicationCostScreen(),
        ),
        GoRoute(
          path: 'insurance-claims',
          builder: (context, state) => const InsuranceClaimsScreen(),
        ),
        GoRoute(
          path: 'accessibility',
          builder: (context, state) => const AccessibilitySettingsScreen(),
        ),
        GoRoute(
          path: 'messages',
          builder: (context, state) => const MessagesScreen(),
        ),
        GoRoute(
          path: 'records',
          builder: (context, state) => const HealthSummary(),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const PatientProfileScreen(),
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

    // Healthcare Provider Routes — bottom-nav shell
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
        GoRoute(
          path: 'inbox',
          builder: (context, state) => const ProviderInboxScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const ProviderSettingsScreen(),
        ),
        GoRoute(
          path: 'adherence',
          builder: (context, state) => const AdherenceMonitoringScreen(),
        ),
        GoRoute(
          path: 'referrals',
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

    // CHW Routes
    GoRoute(
      path: '/chw',
      builder: (context, state) => const CHWShell(),
      routes: [
        GoRoute(
          path: 'new-visit',
          builder: (context, state) => const CHWNewVisitScreen(),
        ),
        GoRoute(
          path: 'patients',
          builder: (context, state) => const CHWPatientSearchScreen(),
        ),
      ],
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFD32F2F)),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The page "${state.matchedLocation}" does not exist.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);

/// Maps a [UserRole] to its default dashboard path.
String _dashboardForRole(UserRole role) {
  switch (role) {
    case UserRole.patient:
      return '/patient';
    case UserRole.doctor:
    case UserRole.nurse:
    case UserRole.radiologist:
      return '/provider';
    case UserRole.admin:
      return '/admin';
    case UserRole.chw:
      return '/chw';
    default:
      return '/login';
  }
}
