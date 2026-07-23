import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/section_head.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const _sidebarItems = [
    SidebarItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/admin', group: 'Management'),
    SidebarItem(icon: Icons.people_outline, label: 'User Management', route: '/admin/users'),
    SidebarItem(icon: Icons.local_hospital_outlined, label: 'Facility Management', route: '/admin/facilities'),
    SidebarItem(icon: Icons.settings_outlined, label: 'System Settings', route: '/admin/settings'),
    SidebarItem(icon: Icons.analytics_outlined, label: 'Analytics', route: '/admin/reports', group: 'Insights'),
    SidebarItem(icon: Icons.history, label: 'Audit Log', route: '/admin/audit-log'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', route: '/admin'),
    BottomNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Users', route: '/admin/users'),
    BottomNavItem(icon: Icons.local_hospital_outlined, activeIcon: Icons.local_hospital, label: 'Facilities', route: '/admin/facilities'),
    BottomNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Analytics', route: '/admin/reports'),
  ];

  int _bottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return AppShell(
      sidebarItems: _sidebarItems,
      bottomNavItems: _bottomNavItems,
      currentBottomIndex: _bottomIndex,
      onBottomNavTap: (i) => setState(() => _bottomIndex = i),
      currentRoute: '/admin',
      role: 'Admin',
      notificationCount: 0,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'System overview',
              style: GoogleFonts.fraunces(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AfiCareTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Managing AfiCare MediLink across Kenya',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AfiCareTheme.slate,
              ),
            ),

            const SizedBox(height: 24),

            // Stat cards
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
                  children: const [
                    StatCard(
                      title: 'Registered Patients',
                      value: '1,234',
                      icon: Icons.people_outline,
                      iconColor: AfiCareTheme.canopy,
                    ),
                    StatCard(
                      title: 'Active Providers',
                      value: '56',
                      subtitle: '+12%',
                      icon: Icons.medical_services_outlined,
                      iconColor: AfiCareTheme.canopy2,
                    ),
                    StatCard(
                      title: 'Linked Facilities',
                      value: '28',
                      icon: Icons.local_hospital_outlined,
                      iconColor: Color(0xFF457B9D),
                    ),
                    StatCard(
                      title: 'Flags Needing Review',
                      value: '3',
                      icon: Icons.flag_outlined,
                      iconColor: AfiCareTheme.clay,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Management section
            SectionHead(title: 'Management'),

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
                    _buildMgmtCard(
                      icon: Icons.people_outline,
                      iconBg: AfiCareTheme.canopy.withValues(alpha: 0.08),
                      iconColor: AfiCareTheme.canopy,
                      title: 'User Management',
                      onTap: () => context.push('/admin/users'),
                    ),
                    _buildMgmtCard(
                      icon: Icons.local_hospital_outlined,
                      iconBg: AfiCareTheme.canopy2.withValues(alpha: 0.08),
                      iconColor: AfiCareTheme.canopy2,
                      title: 'Facility Management',
                      onTap: () => context.push('/admin/facilities'),
                    ),
                    _buildMgmtCard(
                      icon: Icons.settings_outlined,
                      iconBg: AfiCareTheme.slate.withValues(alpha: 0.1),
                      iconColor: AfiCareTheme.slate,
                      title: 'System Settings',
                      onTap: () => context.push('/admin/settings'),
                    ),
                    _buildMgmtCard(
                      icon: Icons.analytics_outlined,
                      iconBg: AfiCareTheme.marigold.withValues(alpha: 0.1),
                      iconColor: AfiCareTheme.marigold,
                      title: 'Analytics',
                      onTap: () => context.push('/admin/reports'),
                    ),
                    _buildMgmtCard(
                      icon: Icons.history,
                      iconBg: AfiCareTheme.clay.withValues(alpha: 0.1),
                      iconColor: AfiCareTheme.clay,
                      title: 'Audit Log',
                      onTap: () => context.push('/admin/audit-log'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMgmtCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AfiCareTheme.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AfiCareTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AfiCareTheme.ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AfiCareTheme.slate),
            ],
          ),
        ),
      ),
    );
  }
}
