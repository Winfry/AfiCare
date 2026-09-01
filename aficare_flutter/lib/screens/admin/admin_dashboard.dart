import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/analytics_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/section_head.dart';
import '../../widgets/management_card.dart';
import '../../theme/app_colors.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const _sidebarEntries = [
    SidebarGroupLabel('Management'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    SidebarNavItem(icon: Icons.people_outline, label: 'User Management'),
    SidebarNavItem(icon: Icons.local_hospital_outlined, label: 'Facility Management'),
    SidebarNavItem(icon: Icons.settings_outlined, label: 'System Settings'),
    SidebarGroupLabel('Insights'),
    SidebarNavItem(icon: Icons.analytics_outlined, label: 'Analytics'),
    SidebarNavItem(icon: Icons.history, label: 'Audit Log'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    BottomNavItem(icon: Icons.people_outline, label: 'Users'),
    BottomNavItem(icon: Icons.local_hospital_outlined, label: 'Facilities'),
    BottomNavItem(icon: Icons.analytics_outlined, label: 'Analytics'),
  ];

  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<AnalyticsProvider>(context, listen: false).loadAll();
    });
  }

  void _onSidebarSelect(int navIndex) {
    switch (navIndex) {
      case 0: // Dashboard
        setState(() => _bottomIndex = 0);
      case 1: // User Management
        context.push('/admin/users');
      case 2: // Facility Management
        context.push('/admin/facilities');
      case 3: // System Settings
        context.push('/admin/settings');
      case 4: // Analytics
        context.push('/admin/reports');
      case 5: // Audit Log
        context.push('/admin/audit-log');
    }
  }

  void _onBottomNavSelect(int i) {
    switch (i) {
      case 0: // Dashboard
        setState(() => _bottomIndex = 0);
      case 1: // Users
        context.push('/admin/users');
      case 2: // Facilities
        context.push('/admin/facilities');
      case 3: // Analytics
        context.push('/admin/reports');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _bottomIndex,
      onSelect: _onSidebarSelect,
      onBottomNavSelect: _onBottomNavSelect,
      searchHint: 'Search facilities, users...',
      avatarLabel: 'AD',
      body: Consumer<AnalyticsProvider>(
        builder: (context, analytics, _) {
          final patientCount = analytics.roleDistribution
              .where((r) => r['role'] == 'patient')
              .fold<int>(0, (sum, r) => sum + ((r['count'] as num?)?.toInt() ?? 0));
          final patientsStr = _formatCount(patientCount);
          final providersStr = _formatCount(analytics.activeProviders);
          final facilitiesStr = _formatCount(analytics.totalFacilities);
          final flagsStr = _formatCount(analytics.missedAppointments);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System overview',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Managing AfiCare MediLink across Kenya',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),

                const SizedBox(height: 24),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 2.0,
                      children: [
                        StatCard(
                          label: 'Registered Patients',
                          value: patientsStr,
                          icon: Icons.people_outline,
                          iconColor: AppColors.canopy,
                        ),
                        StatCard(
                          label: 'Active Providers',
                          value: providersStr,
                          icon: Icons.medical_services_outlined,
                          iconColor: AppColors.canopy2,
                        ),
                        StatCard(
                          label: 'Linked Facilities',
                          value: facilitiesStr,
                          icon: Icons.local_hospital_outlined,
                          iconColor: const Color(0xFF457B9D),
                        ),
                        StatCard(
                          label: 'Cancelled Appointments',
                          value: flagsStr,
                          icon: Icons.flag_outlined,
                          iconColor: AppColors.clay,
                        ),
                      ],
                    );
                  },
                ),

            const SizedBox(height: 32),

            const SectionHead(title: 'Management'),

            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.8,
                  children: [
                    ManagementCard(
                      icon: Icons.people_outline,
                      iconBackground: AppColors.canopy.withOpacity(0.08),
                      iconColor: AppColors.canopy,
                      title: 'User Management',
                      description: 'Roles, access levels, and account status across all facilities.',
                      onTap: () => context.push('/admin/users'),
                    ),
                    ManagementCard(
                      icon: Icons.local_hospital_outlined,
                      iconBackground: AppColors.canopy2.withOpacity(0.08),
                      iconColor: AppColors.canopy2,
                      title: 'Facility Management',
                      description: 'Add, edit, and manage healthcare facilities and their linkages.',
                      onTap: () => context.push('/admin/facilities'),
                    ),
                    ManagementCard(
                      icon: Icons.settings_outlined,
                      iconBackground: AppColors.textMuted.withOpacity(0.1),
                      iconColor: AppColors.textMuted,
                      title: 'System Settings',
                      description: 'App configuration, integrations, and platform preferences.',
                      onTap: () => context.push('/admin/settings'),
                    ),
                    ManagementCard(
                      icon: Icons.analytics_outlined,
                      iconBackground: AppColors.marigold.withOpacity(0.1),
                      iconColor: AppColors.marigold,
                      title: 'Analytics',
                      description: 'Utilization, referral patterns, and performance dashboards.',
                      onTap: () => context.push('/admin/reports'),
                    ),
                    ManagementCard(
                      icon: Icons.history,
                      iconBackground: AppColors.clay.withOpacity(0.1),
                      iconColor: AppColors.clay,
                      title: 'Audit Log',
                      description: 'Track all system changes, user actions, and access history.',
                      onTap: () => context.push('/admin/audit-log'),
                    ),
                  ],
                );
              },
            ),
                ],
              ),
            );
          },
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}
