import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/bottom_nav.dart';
import 'patient_home_screen.dart';
import 'appointments_screen.dart';
import 'messages_screen.dart';
import 'patient_profile_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  final _screens = const [
    PatientHomeScreen(),
    AppointmentsScreen(),
    MessagesScreen(),
    PatientProfileScreen(),
  ];

  static const _sidebarItems = [
    SidebarItem(icon: Icons.dashboard_outlined, label: 'Home', route: '/patient', group: 'Clinical'),
    SidebarItem(icon: Icons.calendar_today_outlined, label: 'Appointments', route: '/patient/appointments'),
    SidebarItem(icon: Icons.chat_bubble_outline, label: 'Messages', route: '/patient/messages', group: 'Communication'),
    SidebarItem(icon: Icons.medical_information_outlined, label: 'Records', route: '/patient/records'),
    SidebarItem(icon: Icons.receipt_long_outlined, label: 'Expenses', route: '/patient/expenses', group: 'Management'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home', route: '/patient'),
    BottomNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Appointments', route: '/patient/appointments'),
    BottomNavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages', route: '/patient/messages'),
    BottomNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', route: '/patient/profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProfile());
  }

  Future<void> _initProfile() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null) {
      dep.setOwnId(id);
      await dep.loadDependents(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarItems: _sidebarItems,
      bottomNavItems: _bottomNavItems,
      currentBottomIndex: _index,
      onBottomNavTap: (i) => setState(() => _index = i),
      currentRoute: '/patient',
      role: 'Patient',
      notificationCount: 0,
      child: IndexedStack(index: _index, children: _screens),
    );
  }
}
