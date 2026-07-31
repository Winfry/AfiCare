import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_shell.dart';
import 'provider_dashboard.dart';
import 'patient_search_screen.dart';
import 'provider_inbox_screen.dart';
import 'referral_tracker_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ProviderDashboard(),
    PatientSearchScreen(),
    ProviderInboxScreen(),
    ReferralTrackerScreen(),
  ];

  static const _sidebarEntries = [
    SidebarGroupLabel('Clinical'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    SidebarNavItem(icon: Icons.search, label: 'Patient Search'),
    SidebarNavItem(icon: Icons.reorder_outlined, label: 'Referrals'),
    SidebarGroupLabel('Workspace'),
    SidebarNavItem(icon: Icons.analytics_outlined, label: 'Reports'),
    SidebarNavItem(icon: Icons.inbox_outlined, label: 'Inbox'),
    SidebarNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    BottomNavItem(icon: Icons.search, label: 'Search'),
    BottomNavItem(icon: Icons.inbox_outlined, label: 'Inbox'),
    BottomNavItem(icon: Icons.reorder_outlined, label: 'Referrals'),
  ];

  void _onSidebarSelect(int navIndex) {
    switch (navIndex) {
      case 0: // Dashboard
        setState(() => _currentIndex = 0);
      case 1: // Patient Search
        setState(() => _currentIndex = 1);
      case 2: // Referrals
        setState(() => _currentIndex = 3);
      case 3: // Reports (full page)
        context.go('/provider/reports');
      case 4: // Inbox
        setState(() => _currentIndex = 2);
      case 5: // Settings (full page)
        context.go('/provider/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _currentIndex,
      onSelect: _onSidebarSelect,
      onBottomNavSelect: (i) => setState(() => _currentIndex = i),
      searchHint: 'Search patients, records...',
      avatarLabel: 'DR',
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
