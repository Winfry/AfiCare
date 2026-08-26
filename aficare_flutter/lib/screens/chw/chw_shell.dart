import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_shell.dart';
import 'chw_dashboard.dart';

class CHWShell extends StatefulWidget {
  const CHWShell({super.key});

  @override
  State<CHWShell> createState() => _CHWShellState();
}

class _CHWShellState extends State<CHWShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CHWDashboard(),
  ];

  static const _sidebarEntries = [
    SidebarGroupLabel('Field Work'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    SidebarNavItem(icon: Icons.add_home_rounded, label: 'New Visit'),
    SidebarNavItem(icon: Icons.people_rounded, label: 'My Patients'),
    SidebarNavItem(icon: Icons.send_rounded, label: 'Referrals'),
    SidebarGroupLabel('Health'),
    SidebarNavItem(icon: Icons.monitor_heart_rounded, label: 'Vitals Check'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
    BottomNavItem(icon: Icons.add_home_rounded, label: 'New Visit'),
    BottomNavItem(icon: Icons.people_rounded, label: 'Patients'),
    BottomNavItem(icon: Icons.send_rounded, label: 'Referrals'),
  ];

  void _onSidebarSelect(int navIndex) {
    switch (navIndex) {
      case 0:
        setState(() => _currentIndex = 0);
      case 1:
        context.go('/chw/new-visit');
      case 2:
        context.go('/chw/patients');
      case 3:
        context.go('/chw/referrals');
      case 4:
        context.go('/chw/vitals');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _currentIndex,
      onSelect: _onSidebarSelect,
      onBottomNavSelect: (i) {
        if (i == 0) setState(() => _currentIndex = 0);
        if (i == 1) context.go('/chw/new-visit');
        if (i == 2) context.go('/chw/patients');
        if (i == 3) context.go('/chw/referrals');
      },
      searchHint: 'Search patients...',
      avatarLabel: 'CHW',
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
