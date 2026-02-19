import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/patient/patient_dashboard.dart';
import '../screens/patient/health_summary.dart';
import '../screens/patient/share_records.dart';
import '../screens/patient/qr_scanner.dart';
import '../screens/provider/provider_dashboard.dart';
import '../screens/provider/consultation_screen.dart';
import '../screens/provider/patient_access.dart';
import '../screens/admin/admin_dashboard.dart';
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

    // Patient Routes
    GoRoute(
      path: '/patient',
      builder: (context, state) => const PatientDashboard(),
      routes: [
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
      ],
    ),

    // Doctor and Nurse redirect to provider dashboard
    GoRoute(
      path: '/doctor',
      redirect: (context, state) => '/provider',
    ),
    GoRoute(
      path: '/nurse',
      redirect: (context, state) => '/provider',
    ),

    // Healthcare Provider Routes
    GoRoute(
      path: '/provider',
      builder: (context, state) => const ProviderDashboard(),
      routes: [
        GoRoute(
          path: 'consultation',
          builder: (context, state) => const ConsultationScreen(),
        ),
        GoRoute(
          path: 'access',
          builder: (context, state) => const PatientAccess(),
        ),
      ],
    ),

    // Admin Routes
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
  ],
);
