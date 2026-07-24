import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/brand_switch.dart';
import '../widgets/stat_card.dart';
import '../widgets/dashboard_panel.dart';
import '../widgets/timeline_list.dart';
import '../widgets/appointment_list.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({
    super.key,
    required this.providerName,
    required this.facilityName,
    required this.department,
  });

  final String providerName;
  final String facilityName;
  final String department;

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedIndex = 0;
  bool _isDark = false;

  static final _sidebarEntries = <SidebarEntry>[
    SidebarGroupLabel('Clinical'),
    SidebarNavItem(icon: Icons.home_outlined, label: 'Dashboard'),
    SidebarNavItem(icon: Icons.search, label: 'Patient search'),
    SidebarNavItem(icon: Icons.north_east_rounded, label: 'Referrals'),
    SidebarNavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
    SidebarGroupLabel('Workspace'),
    SidebarNavItem(icon: Icons.inbox_outlined, label: 'Inbox'),
    SidebarNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.home_outlined, label: 'Dashboard'),
    BottomNavItem(icon: Icons.search, label: 'Search'),
    BottomNavItem(icon: Icons.inbox_outlined, label: 'Inbox'),
    BottomNavItem(icon: Icons.north_east_rounded, label: 'Referrals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDark ? AppTheme.dark : AppTheme.light,
      child: AppShell(
        sidebarEntries: _sidebarEntries,
        bottomNavItems: _bottomNavItems,
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
        onBottomNavSelect: (i) => setState(() => _selectedIndex = i),
        searchHint: 'Search patients, referrals…',
        avatarLabel: 'DO',
        isDark: _isDark,
        onLogout: () => context.go('/login'),
        trailingActions: [
          BrandSwitch(
            label: 'Dark',
            value: _isDark,
            onChanged: (v) => setState(() => _isDark = v),
            mutedColor: _isDark ? const Color(0xFFC7D2DC) : AppColors.textMuted,
          ),
          const SizedBox(width: 16),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${widget.providerName}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _isDark ? Colors.white : AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.facilityName} — ${widget.department}',
              style: TextStyle(fontSize: 14, color: _isDark ? const Color(0xFF93A0AB) : AppColors.textMuted),
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
                    value: '1,842',
                    label: 'Patients under care',
                    deltaLabel: '+12%',
                    hero: true,
                  ),
                  StatCard(
                    icon: Icons.medical_services_outlined,
                    value: '63',
                    label: 'Consultations this week',
                    iconBackground: AppColors.tintSteelBg,
                    iconColor: AppColors.steelBlue,
                    deltaLabel: '+4%',
                    deltaBackground: AppColors.tintSuccessBg,
                    deltaColor: AppColors.nonUrgent,
                    isDark: _isDark,
                  ),
                  StatCard(
                    icon: Icons.north_east_rounded,
                    value: '17',
                    label: 'Open referrals',
                    iconBackground: AppColors.tintUrgentBg,
                    iconColor: AppColors.urgent,
                    deltaLabel: '3 urgent',
                    deltaBackground: AppColors.tintUrgentBg,
                    deltaColor: AppColors.urgent,
                    isDark: _isDark,
                  ),
                  StatCard(
                    icon: Icons.calendar_today_outlined,
                    value: '9',
                    label: 'Appointments today',
                    iconBackground: const Color(0xFFEFF6FA),
                    iconColor: AppColors.steelBlue,
                    deltaLabel: 'Today',
                    deltaBackground: const Color(0xFFEFF6FA),
                    deltaColor: AppColors.steelBlue,
                    isDark: _isDark,
                  ),
                ];
                return cards[i];
              },
            ),
            const SizedBox(height: 30),

            LayoutBuilder(
              builder: (context, constraints) {
                final activity = DashboardPanel(
                  isDark: _isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelHeader(title: 'Recent activity', actionLabel: 'View all', isDark: _isDark),
                      const SizedBox(height: 16),
                      TimelineList(
                        isDark: _isDark,
                        entries: const [
                          TimelineEntry(
                            icon: Icons.biotech_outlined,
                            title: 'Lab result flagged',
                            meta: 'A. Kimani — elevated glucose · 14 min ago',
                          ),
                          TimelineEntry(
                            icon: Icons.north_east_rounded,
                            title: 'Referral sent to Kenyatta National',
                            meta: 'S. Mwangi — Cardiology, urgent · 1h ago',
                          ),
                          TimelineEntry(
                            icon: Icons.check_rounded,
                            title: 'Consultation completed',
                            meta: 'J. Achieng — follow-up, hypertension · 2h ago',
                          ),
                          TimelineEntry(
                            icon: Icons.description_outlined,
                            title: 'Prescription issued',
                            meta: 'P. Wafula — Metformin 500mg · 3h ago',
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final appointments = DashboardPanel(
                  isDark: _isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelHeader(title: 'Upcoming appointments', isDark: _isDark),
                      const SizedBox(height: 12),
                      AppointmentList(
                        isDark: _isDark,
                        entries: const [
                          AppointmentEntry(time: '09:30', who: 'Grace Achieng', what: 'Follow-up · Room 4'),
                          AppointmentEntry(time: '10:15', who: 'Peter Wafula', what: 'New patient · Room 4'),
                          AppointmentEntry(time: '11:00', who: 'Alice Kimani', what: 'Lab review · Room 2'),
                          AppointmentEntry(time: '13:45', who: 'Samuel Mwangi', what: 'Pre-referral check · Room 4'),
                        ],
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth < 700) {
                  return Column(children: [activity, const SizedBox(height: 22), appointments]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 14, child: activity),
                    const SizedBox(width: 22),
                    Expanded(flex: 10, child: appointments),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.actionLabel, required this.isDark});
  final String title;
  final String? actionLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.deepNavy),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
