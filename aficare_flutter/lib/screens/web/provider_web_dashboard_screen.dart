import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/snackbar_utils.dart';
import '../provider/patient_search_screen.dart';
import '../provider/provider_inbox_screen.dart';
import '../provider/referral_tracker_screen.dart';
import '../provider/reports_screen.dart';
import '../provider/provider_settings_screen.dart';

class ProviderWebDashboardScreen extends StatefulWidget {
  const ProviderWebDashboardScreen({super.key});

  @override
  State<ProviderWebDashboardScreen> createState() => _ProviderWebDashboardScreenState();
}

class _ProviderWebDashboardScreenState extends State<ProviderWebDashboardScreen> {
  String _selectedNav = 'dashboard';
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingData = true;

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
      _loadActivity();
      _loadAppointments();
    });
  }

  Future<void> _loadActivity() async {
    final supabase = Supabase.instance.client;
    final items = <Map<String, dynamic>>[];

    try {
      final consults = await supabase
          .from('consultations')
          .select('id, chief_complaint, timestamp')
          .order('timestamp', ascending: false)
          .limit(3);
      for (final c in consults as List) {
        items.add({
          'icon': Icons.assignment,
          'title': 'Consultation completed',
          'subtitle': (c['chief_complaint'] ?? 'Patient visit').toString(),
          'timestamp': DateTime.tryParse(c['timestamp'] as String),
        });
      }
    } catch (e) { debugPrint('Provider web dashboard: failed to load consultations: $e'); showErrorSnackBar(context, 'Could not load consultations: $e'); }

    try {
      final referrals = await supabase
          .from('referrals')
          .select('id, reason, created_at')
          .order('created_at', ascending: false)
          .limit(3);
      for (final r in referrals as List) {
        items.add({
          'icon': Icons.swap_horiz,
          'title': 'Referral created',
          'subtitle': (r['reason'] ?? 'Patient referral').toString(),
          'timestamp': DateTime.tryParse(r['created_at'] as String),
        });
      }
    } catch (e) { debugPrint('Provider web dashboard: failed to load referrals: $e'); showErrorSnackBar(context, 'Could not load referrals: $e'); }

    try {
      final results = await supabase
          .from('lab_results')
          .select('id, lab_orders(test_name), resulted_at')
          .order('resulted_at', ascending: false)
          .limit(3);
      for (final lr in results as List) {
        final order = lr['lab_orders'] as Map?;
        items.add({
          'icon': Icons.science,
          'title': 'Lab results available',
          'subtitle': (order?['test_name'] ?? 'Lab test').toString(),
          'timestamp': DateTime.tryParse(lr['resulted_at'] as String),
        });
      }
    } catch (e) { debugPrint('Provider web dashboard: failed to load lab_results: $e'); showErrorSnackBar(context, 'Could not load lab_results: $e'); }

    items.sort((a, b) {
      final ta = a['timestamp'] as DateTime?;
      final tb = b['timestamp'] as DateTime?;
      return (tb ?? DateTime(0)).compareTo(ta ?? DateTime(0));
    });
    if (mounted) {
      setState(() {
        _activity = items.take(6).toList();
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('appointments')
          .select('id, scheduled_at, status, chief_complaint, type, users(full_name)')
          .eq('provider_id', user.id)
          .order('scheduled_at', ascending: true)
          .limit(20);

      final now = DateTime.now();
      final upcoming = <Map<String, dynamic>>[];
      for (final a in response as List) {
        final map = Map<String, dynamic>.from(a as Map);
        final when = DateTime.tryParse(map['scheduled_at'] as String);
        if (when != null && when.isAfter(now)) {
          final patient = map['users'] as Map<String, dynamic>?;
          upcoming.add({
            'name': patient?['full_name'] ?? 'Patient',
            'time': '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
            'type': map['chief_complaint'] ?? (map['type'] == 'telehealth' ? 'Telehealth' : 'Consultation'),
            'status': map['status'] ?? 'pending',
            'when': when,
          });
        }
      }
      upcoming.sort((a, b) => (a['when'] as DateTime).compareTo(b['when'] as DateTime));
      if (mounted) {
        setState(() => _appointments = upcoming.take(5).toList());
      }
    } catch (e) { debugPrint('Provider web dashboard: failed to load appointments: $e'); showErrorSnackBar(context, 'Could not load appointments: $e'); }
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
    switch (_selectedNav) {
      case 'search':
        return const PatientSearchScreen();
      case 'inbox':
        return const ProviderInboxScreen();
      case 'referrals':
        return const ReferralTrackerScreen();
      case 'reports':
        return const ReportsScreen();
      case 'settings':
        return const ProviderSettingsScreen();
    }
    return _buildDashboard(context);
  }

  Widget _buildDashboard(BuildContext context) {
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
    final totalAppointments = analytics.appointmentTrend.fold<int>(
      0,
      (sum, e) => sum + ((e['count'] as num?)?.toInt() ?? 0),
    );
    final cards = [
      _StatCard(title: 'Total Patients', value: '${analytics.totalUsers}', icon: Icons.people, color: Colors.blue),
      _StatCard(title: 'Consultations', value: '${analytics.totalConsultations}', icon: Icons.assignment, color: Colors.green),
      _StatCard(title: 'Active Referrals', value: '${analytics.referralsThisMonth}', icon: Icons.swap_horiz, color: Colors.orange),
      _StatCard(title: 'Appointments', value: '$totalAppointments', icon: Icons.calendar_today, color: Colors.purple),
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
            if (_isLoadingData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No recent activity', style: TextStyle(color: Colors.grey[500])),
              )
            else
              for (final item in _activity)
                _activityItem(
                  item['icon'] as IconData,
                  item['title'] as String,
                  '${item['subtitle']}',
                  _relativeTime(item['timestamp'] as DateTime?),
                ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _activityItem(IconData icon, String title, String subtitle, String time) {
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
                Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12), overflow: TextOverflow.ellipsis),
                Text(time, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
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
            if (_appointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No upcoming appointments', style: TextStyle(color: Colors.grey[500])),
              )
            else
              for (final a in _appointments)
                _apptItem(
                  a['name'] as String,
                  a['time'] as String,
                  a['type'] as String,
                  a['status'] as String,
                ),
          ],
        ),
      ),
    );
  }

  Widget _apptItem(String name, String time, String type, String status) {
    final confirmed = status == 'confirmed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
              color: (confirmed ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              confirmed ? 'Confirmed' : 'Pending',
              style: TextStyle(
                color: confirmed ? Colors.green : Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
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