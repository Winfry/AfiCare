import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class CHWDashboard extends StatefulWidget {
  const CHWDashboard({super.key});

  @override
  State<CHWDashboard> createState() => _CHWDashboardState();
}

class _CHWDashboardState extends State<CHWDashboard> {
  final _supabase = Supabase.instance.client;
  String _chwName = '';
  int _totalPatients = 0;
  int _visitsToday = 0;
  int _pendingReferrals = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentVisits = [];
  List<Map<String, dynamic>> _highRiskPatients = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load user info
      final user = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      if (user != null) _chwName = (user['full_name'] as String?) ?? '';

      // Count assigned patients
      final patients = await _supabase
          .from('care_team')
          .select('patient_id')
          .eq('provider_id', userId);
      _totalPatients = (patients as List).length;

      // Count today's visits
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
      final visits = await _supabase
          .from('chv_visits')
          .select('id')
          .eq('chv_id', userId)
          .gte('visit_date', todayStart);
      _visitsToday = (visits as List).length;

      // Pending referrals
      final referrals = await _supabase
          .from('referrals')
          .select('id')
          .eq('referred_by', userId)
          .eq('status', 'pending');
      _pendingReferrals = (referrals as List).length;

      // Recent visits
      final recent = await _supabase
          .from('chv_visits')
          .select('*, patients(id, date_of_birth)')
          .eq('chv_id', userId)
          .order('visit_date', ascending: false)
          .limit(10);
      _recentVisits = (recent as List).cast<Map<String, dynamic>>();

      // High risk patients (from triage)
      try {
        final highRisk = await _supabase
            .from('triage_assessments')
            .select('patient_id, triage_level, created_at')
            .eq('assessed_by', userId)
            .inFilter('triage_level', ['emergency', 'urgent'])
            .order('created_at', ascending: false)
            .limit(10);
        _highRiskPatients = (highRisk as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading CHW dashboard: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.canopy)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: RefreshIndicator(
        onRefresh: () async { setState(() => _isLoading = true); await _loadDashboard(); },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.canopy,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_chwName.isNotEmpty ? _chwName.split(' ').first : 'CHW'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  const Text('Community Health Worker', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => context.go('/chw/patients'),
                  icon: const Icon(Icons.people_outline, color: Colors.white),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _statCard('$_totalPatients', 'Patients', Icons.people_rounded, AppColors.canopy),
                        const SizedBox(width: 10),
                        _statCard('$_visitsToday', 'Today\'s Visits', Icons.home_rounded, const Color(0xFF2E7D32)),
                        const SizedBox(width: 10),
                        _statCard('$_pendingReferrals', 'Referrals', Icons.send_rounded, const Color(0xFFF57F17)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick actions
                    const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    _quickActions(),
                    const SizedBox(height: 20),

                    // Recent visits
                    const Text('Recent Visits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    if (_recentVisits.isEmpty)
                      _emptyCard('No visits recorded yet. Start your first visit below.')
                    else
                      ...(_recentVisits.take(5).map((v) => _visitCard(v))),

                    // High risk
                    if (_highRiskPatients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.warning_rounded, color: Color(0xFFF57F17), size: 20),
                          const SizedBox(width: 6),
                          const Text('High Risk Patients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...(_highRiskPatients.take(5).map((p) => _riskCard(p))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _actionCard('New Visit', Icons.add_home_rounded, AppColors.canopy, () => context.go('/chw/new-visit')),
        _actionCard('Find Patient', Icons.search_rounded, const Color(0xFF5C6BC0), () => context.go('/chw/patients')),
        _actionCard('Refer Patient', Icons.send_rounded, const Color(0xFFF57F17), () => context.go('/chw/referrals')),
        _actionCard('Vitals Check', Icons.monitor_heart_rounded, const Color(0xFFE91E63), () => context.go('/chw/vitals')),
      ],
    );
  }

  Widget _actionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitCard(Map<String, dynamic> visit) {
    final visitDate = DateTime.tryParse(visit['visit_date'] as String? ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.canopy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_rounded, color: AppColors.canopy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit['visit_type'] as String? ?? 'Home Visit',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (visit['notes'] != null)
                  Text(visit['notes'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (visitDate != null)
            Text(
              '${visitDate.day}/${visitDate.month}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  Widget _riskCard(Map<String, dynamic> data) {
    final level = data['triage_level'] as String? ?? 'unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF57F17).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFF57F17), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(level.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFF57F17))),
          ),
          TextButton(
            onPressed: () => context.go('/chw/patients'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    );
  }
}
