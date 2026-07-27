import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../widgets/app_shell.dart';
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

  static const _sidebarEntries = [
    SidebarGroupLabel('Clinical'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
    SidebarNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    SidebarNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    SidebarGroupLabel('Records'),
    SidebarNavItem(icon: Icons.medical_information_outlined, label: 'Records'),
    SidebarNavItem(icon: Icons.receipt_long_outlined, label: 'Expenses'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
    BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    BottomNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    BottomNavItem(icon: Icons.person_outline, label: 'Profile'),
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
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      onBottomNavSelect: (i) => setState(() => _index = i),
      searchHint: 'Search patients, records...',
      avatarLabel: 'P',
      body: IndexedStack(index: _index, children: _screens),
    );
  }
}
