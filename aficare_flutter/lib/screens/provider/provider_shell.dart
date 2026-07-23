import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/bottom_nav.dart';
import 'provider_dashboard.dart';
import 'patient_search_screen.dart';
import 'provider_inbox_screen.dart';
import 'provider_settings_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;
  bool _isDark = false;

  final List<Widget> _screens = const [
    ProviderDashboard(),
    PatientSearchScreen(),
    ProviderInboxScreen(),
    ProviderSettingsScreen(),
  ];

  static const _sidebarItems = [
    SidebarItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/provider', group: 'Clinical'),
    SidebarItem(icon: Icons.search, label: 'Patient Search', route: '/provider/search'),
    SidebarItem(icon: Icons.reorder_outlined, label: 'Referrals', route: '/provider/referrals'),
    SidebarItem(icon: Icons.analytics_outlined, label: 'Reports', route: '/provider/reports', group: 'Workspace'),
    SidebarItem(icon: Icons.inbox_outlined, label: 'Inbox', route: '/provider/inbox'),
    SidebarItem(icon: Icons.settings_outlined, label: 'Settings', route: '/provider/settings'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', route: '/provider'),
    BottomNavItem(icon: Icons.search, activeIcon: Icons.search, label: 'Search', route: '/provider/search'),
    BottomNavItem(icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'Inbox', route: '/provider/inbox'),
    BottomNavItem(icon: Icons.reorder_outlined, activeIcon: Icons.reorder, label: 'Referrals', route: '/provider/referrals'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarItems: _sidebarItems,
      bottomNavItems: _bottomNavItems,
      currentBottomIndex: _currentIndex,
      onBottomNavTap: (i) => setState(() => _currentIndex = i),
      currentRoute: '/provider',
      role: 'Provider',
      showDarkToggle: true,
      isDark: _isDark,
      onDarkToggle: () => setState(() => _isDark = !_isDark),
      notificationCount: 0,
      child: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
