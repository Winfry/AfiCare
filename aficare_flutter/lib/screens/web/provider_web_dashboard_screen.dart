import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class ProviderWebDashboardScreen extends StatefulWidget {
  const ProviderWebDashboardScreen({super.key});

  @override
  State<ProviderWebDashboardScreen> createState() => _ProviderWebDashboardScreenState();
}

class _ProviderWebDashboardScreenState extends State<ProviderWebDashboardScreen> {
  String _selectedNav = 'dashboard';

  final _navItems = [
    {'id': 'dashboard', 'icon': Icons.dashboard, 'label': 'Dashboard'},
    {'id': 'search', 'icon': Icons.search, 'label': 'Patient Search'},
    {'id': 'inbox', 'icon': Icons.inbox, 'label': 'Inbox'},
    {'id': 'referrals', 'icon': Icons.swap_horiz, 'label': 'Referrals'},
    {'id': 'reports', 'icon': Icons.bar_chart, 'label': 'Reports'},
    {'id': 'settings', 'icon': Icons.settings, 'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Row(
        children: [
          isTablet ? _buildSideNav() : _buildBottomNav(),
          const VerticalDivider(width: 1),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return NavigationRail(
      selectedIndex: _navItems.indexWhere((n) => n['id'] == _selectedNav),
      onDestinationSelected: (i) => setState(() => _selectedNav = _navItems[i]['id'] as String),
      labelType: NavigationRailLabelType.all,
      leading: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.medical_services, size: 32, color: AfiCareTheme.primaryBlue),
          const SizedBox(height: 4),
          Text('AfiCare', style: TextStyle(fontSize: 11, color: AfiCareTheme.primaryBlue, fontWeight: FontWeight.bold)),
        ],
      ),
      destinations: _navItems.map((n) => NavigationRailDestination(
        icon: Icon(n['icon'] as IconData),
        label: Text(n['label'] as String, style: const TextStyle(fontSize: 11)),
      )).toList(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.map((n) => InkWell(
              onTap: () => setState(() => _selectedNav = n['id'] as String),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(n['icon'] as IconData,
                    size: 22,
                    color: _selectedNav == n['id'] ? AfiCareTheme.primaryBlue : Colors.grey,
                  ),
                  Text(
                    n['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: _selectedNav == n['id'] ? AfiCareTheme.primaryBlue : Colors.grey,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, ${user?.fullName ?? 'Provider'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Here is your practice overview', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: AfiCareTheme.primaryBlue,
                child: Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'P',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickStats(analytics),
          const SizedBox(height: 24),
          MediaQuery.of(context).size.width > 800
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildActivityFeed()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildUpcomingAppointments()),
                  ],
                )
              : Column(
                  children: [
                    _buildActivityFeed(),
                    const SizedBox(height: 16),
                    _buildUpcomingAppointments(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(AnalyticsProvider analytics) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final cards = [
      _StatCard(title: 'Total Patients', value: '${analytics.totalUsers}', icon: Icons.people, color: Colors.blue),
      _StatCard(title: 'Consultations', value: '${analytics.totalConsultations}', icon: Icons.assignment, color: Colors.green),
      _StatCard(title: 'Active Referrals', value: '${analytics.referralsThisMonth}', icon: Icons.swap_horiz, color: Colors.orange),
      _StatCard(title: 'Appointments', value: '${analytics.totalConsultations}', icon: Icons.calendar_today, color: Colors.purple),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: c,
        ))).toList(),
      );
    }
    return Column(
      children: cards.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: c,
      )).toList(),
    );
  }

  Widget _buildActivityFeed() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _activityItem(Icons.person_add, 'New patient registered', '2 min ago'),
            _activityItem(Icons.assignment, 'Consultation completed', '15 min ago'),
            _activityItem(Icons.swap_horiz, 'Referral accepted', '1 hour ago'),
            _activityItem(Icons.science, 'Lab results available', '3 hours ago'),
            _activityItem(Icons.medication, 'Prescription refilled', '1 day ago'),
          ],
        ),
      ),
    );
  }

  Widget _activityItem(IconData icon, String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AfiCareTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AfiCareTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upcoming Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _apptItem('Sarah Johnson', '10:00 AM', 'Check-up'),
            _apptItem('Michael Kiprono', '11:30 AM', 'Follow-up'),
            _apptItem('Grace Akinyi', '2:00 PM', 'Consultation'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {},
              child: const Text('View Full Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apptItem(String name, String time, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
            child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('$time · $type', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Confirmed', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}