import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/medilink_id_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/activity_list.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({
    super.key,
    required this.patientFirstName,
    required this.patientFullName,
    required this.mediLinkId,
    required this.county,
    this.insuranceLinked = true,
    this.facilityTier = '6',
    this.upcomingAppointmentCount = 1,
  });

  final String patientFirstName;
  final String patientFullName;
  final String mediLinkId;
  final String county;
  final bool insuranceLinked;
  final String facilityTier;
  final int upcomingAppointmentCount;

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _selectedIndex = 0;

  static final _sidebarEntries = <SidebarEntry>[
    SidebarNavItem(icon: Icons.home_outlined, label: 'Home'),
    SidebarNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    SidebarNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    SidebarNavItem(icon: Icons.description_outlined, label: 'Records'),
    SidebarNavItem(icon: Icons.payments_outlined, label: 'Expenses'),
    SidebarNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.home_outlined, label: 'Home'),
    BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    BottomNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    BottomNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  String get _initials {
    final parts = widget.patientFullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String get _todayLabel {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}day, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _selectedIndex,
      onSelect: (i) => setState(() => _selectedIndex = i),
      onBottomNavSelect: (i) => setState(() => _selectedIndex = i),
      searchHint: 'Search records, medications…',
      avatarLabel: _initials,
      onLogout: () => context.go('/login'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habari, ${widget.patientFirstName}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
          ),
          const SizedBox(height: 4),
          Text(
            '$_todayLabel — you have ${widget.upcomingAppointmentCount} upcoming appointment${widget.upcomingAppointmentCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          MediLinkIdCard(
            patientName: widget.patientFullName,
            mediLinkId: widget.mediLinkId,
            county: widget.county,
            insuranceLinked: widget.insuranceLinked,
            tier: widget.facilityTier,
          ),
          const SizedBox(height: 30),

          const _SectionHeader(title: 'Quick actions'),
          const SizedBox(height: 16),
          _QuickActionsGrid(),
          const SizedBox(height: 34),

          const _SectionHeader(title: 'Recent activity', actionLabel: 'See all'),
          const SizedBox(height: 16),
          ActivityList(
            items: [
              ActivityItem(
                icon: Icons.biotech_outlined,
                iconBackground: AppColors.tintNavyBg,
                iconColor: AppColors.primaryNavy,
                title: 'Lab results ready',
                meta: 'Full blood count — Aga Khan University Hospital',
                time: '2h ago',
              ),
              ActivityItem(
                icon: Icons.medication_outlined,
                iconBackground: AppColors.tintSteelBg,
                iconColor: AppColors.steelBlue,
                title: 'Prescription refilled',
                meta: 'Amlodipine 5mg — 30 day supply',
                time: 'Yesterday',
              ),
              ActivityItem(
                icon: Icons.north_east_rounded,
                iconBackground: AppColors.tintLightBlueBg,
                iconColor: AppColors.tintLightBlueFg,
                title: 'Referral accepted',
                meta: 'Dr. Otieno → Kenyatta National, Cardiology',
                time: '3 days ago',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel});
  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
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

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.description_outlined, 'Prescriptions', AppColors.tintNavyBg, AppColors.primaryNavy),
      (Icons.medication_outlined, 'Medications', AppColors.tintSteelBg, AppColors.steelBlue),
      (Icons.biotech_outlined, 'Lab results', const Color(0xFFEFF6FA), AppColors.steelBlue),
      (Icons.folder_shared_outlined, 'Health summary', AppColors.tintLightBlueBg, AppColors.tintLightBlueFg),
      (Icons.share_outlined, 'Share records', AppColors.tintNavyBg, AppColors.primaryNavy),
      (Icons.payments_outlined, 'Expenses (KES)', AppColors.tintSuccessBg, AppColors.nonUrgent),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, i) {
        final (icon, label, bg, fg) = actions[i];
        return QuickActionCard(icon: icon, label: label, iconBackground: bg, iconColor: fg, onTap: () {});
      },
    );
  }
}
