import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/stat_card.dart';
import '../widgets/tier_badge.dart';
import '../widgets/management_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.facilityCount = 214,
    this.countyCount = 12,
    this.asOfTime = '08:42 EAT',
  });

  final int facilityCount;
  final int countyCount;
  final String asOfTime;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static final _sidebarEntries = <SidebarEntry>[
    SidebarNavItem(icon: Icons.home_outlined, label: 'Dashboard'),
    SidebarNavItem(icon: Icons.groups_outlined, label: 'User management'),
    SidebarNavItem(icon: Icons.local_hospital_outlined, label: 'Facility management'),
    SidebarNavItem(icon: Icons.settings_outlined, label: 'System settings'),
    SidebarNavItem(icon: Icons.bar_chart_outlined, label: 'Analytics'),
    SidebarNavItem(icon: Icons.receipt_long_outlined, label: 'Audit log'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.home_outlined, label: 'Dashboard'),
    BottomNavItem(icon: Icons.groups_outlined, label: 'Users'),
    BottomNavItem(icon: Icons.local_hospital_outlined, label: 'Facilities'),
    BottomNavItem(icon: Icons.bar_chart_outlined, label: 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    final baseTheme = AppTheme.light;

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(primary: AppColors.adminColor),
      ),
      child: AppShell(
        sidebarEntries: _sidebarEntries,
        bottomNavItems: _bottomNavItems,
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
        onBottomNavSelect: (i) => setState(() => _selectedIndex = i),
        searchHint: 'Search users, facilities…',
        avatarLabel: 'AD',
        avatarColor: AppColors.adminColor,
        onLogout: () => context.go('/login'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System overview',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
            ),
            const SizedBox(height: 4),
            Text(
              'Across ${widget.facilityCount} facilities · ${widget.countyCount} counties · live as of ${widget.asOfTime}',
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, i) {
                final cards = [
                  const StatCard(
                    icon: Icons.groups_outlined,
                    value: '128,430',
                    label: 'Registered patients',
                    iconBackground: AppColors.tintNavyBg,
                    iconColor: AppColors.primaryNavy,
                    trailing: TierBadge(label: '6'),
                  ),
                  const StatCard(
                    icon: Icons.medical_services_outlined,
                    value: '1,062',
                    label: 'Active providers',
                    iconBackground: AppColors.tintSteelBg,
                    iconColor: AppColors.steelBlue,
                    trailing: TierBadge(label: '5'),
                  ),
                  const StatCard(
                    icon: Icons.local_hospital_outlined,
                    value: '214',
                    label: 'Linked facilities',
                    iconBackground: Color(0xFFEFF6FA),
                    iconColor: AppColors.steelBlue,
                    trailing: TierBadge(label: '4'),
                  ),
                  const StatCard(
                    icon: Icons.warning_amber_rounded,
                    value: '6',
                    label: 'Flags needing review',
                    iconBackground: AppColors.tintUrgentBg,
                    iconColor: AppColors.urgent,
                    trailing: TierBadge(label: '!', color: AppColors.adminColor),
                  ),
                ];
                return cards[i];
              },
            ),
            const SizedBox(height: 30),

            const Text('Management', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, i) {
                final cards = [
                  ManagementCard(
                    icon: Icons.groups_outlined,
                    title: 'User management',
                    description: 'Roles, access levels, and account status across all facilities.',
                    iconBackground: AppColors.tintNavyBg,
                    iconColor: AppColors.primaryNavy,
                  ),
                  const ManagementCard(
                    icon: Icons.local_hospital_outlined,
                    title: 'Facility management',
                    description: 'Onboard facilities and set their referral tier.',
                    iconBackground: Color(0xFFEFF6FA),
                    iconColor: AppColors.steelBlue,
                  ),
                  const ManagementCard(
                    icon: Icons.settings_outlined,
                    title: 'System settings',
                    description: 'Notification rules, data retention, integrations.',
                    iconBackground: AppColors.tintAdminBg,
                    iconColor: AppColors.adminColor,
                  ),
                  const ManagementCard(
                    icon: Icons.bar_chart_outlined,
                    title: 'Analytics',
                    description: 'Referral volume, wait times, and load by county.',
                    iconBackground: AppColors.tintSteelBg,
                    iconColor: AppColors.steelBlue,
                  ),
                  const ManagementCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Audit log',
                    description: 'Every record access and edit, timestamped.',
                    iconBackground: AppColors.tintAdminBg,
                    iconColor: AppColors.adminColor,
                  ),
                ];
                return cards[i];
              },
            ),
          ],
        ),
      ),
    );
  }
}
