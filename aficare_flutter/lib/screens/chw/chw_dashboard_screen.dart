import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class CHWDashboardScreen extends StatefulWidget {
  const CHWDashboardScreen({super.key});

  @override
  State<CHWDashboardScreen> createState() => _CHWDashboardScreenState();
}

class _CHWDashboardScreenState extends State<CHWDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignedPatients = [];
  List<Map<String, dynamic>> _recentVisits = [];
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load user name
      final userData = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      if (userData != null) _userName = userData['full_name'] as String? ?? '';

      // Load assigned patients (via care_team where this user is the provider)
      try {
        final teamData = await _supabase
            .from('care_team')
            .select('patient_id')
            .eq('provider_id', userId);
        final patientIds = (teamData as List).map((r) => r['patient_id'] as String).toList();

        if (patientIds.isNotEmpty) {
          final patientsData = await _supabase
              .from('users')
              .select('id, full_name, phone, medilink_id')
              .inFilter('id', patientIds)
              .limit(50);
          _assignedPatients = List<Map<String, dynamic>>.from(patientsData as List);
        }
      } catch (_) {}

      // Load recent community health visits
      try {
        final visitsData = await _supabase
            .from('chw_visits')
            .select('*, patients!chw_visits_patient_id_fkey(full_name)')
            .eq('chw_id', userId)
            .order('visit_date', ascending: false)
            .limit(10);
        _recentVisits = List<Map<String, dynamic>>.from(visitsData as List);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading CHW data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {},
            ),
            title: Text(
              'CHW Dashboard',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  _buildGreetingCard(),
                  const SizedBox(height: 16),

                  // Quick stats
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // Quick actions
                  const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildQuickActions(),
                  const SizedBox(height: 20),

                  // Assigned patients
                  Row(
                    children: [
                      const Text('My Patients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      Text('${_assignedPatients.length}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_assignedPatients.isEmpty)
                    _buildEmptyPatients()
                  else
                    ...(_assignedPatients.take(5).map((p) => _buildPatientCard(p))),

                  const SizedBox(height: 16),

                  // Recent visits
                  if (_recentVisits.isNotEmpty) ...[
                    const Text('Recent Visits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_recentVisits.take(5).map((v) => _buildVisitCard(v))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF194D43), AppColors.canopy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.canopy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting${_userName.isNotEmpty ? ', ' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    _userName.isNotEmpty ? _userName : 'CHW',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Community Health Worker',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('${_assignedPatients.length}', 'Patients', Icons.people_rounded, const Color(0xFF5C6BC0)),
        const SizedBox(width: 12),
        _statCard('${_recentVisits.length}', 'Visits', Icons.local_hospital_rounded, AppColors.canopy),
        const SizedBox(width: 12),
        _statCard('0', 'Referrals', Icons.send_rounded, const Color(0xFFF57F17)),
      ],
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
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _actionCard('Record Visit', Icons.edit_note_rounded, AppColors.canopy, () => context.go('/chw/visit')),
        _actionCard('Vital Signs', Icons.monitor_heart_rounded, const Color(0xFF5C6BC0), () => context.go('/chw/vitals')),
        _actionCard('Referral', Icons.send_rounded, const Color(0xFFF57F17), () => context.go('/chw/referral')),
        _actionCard('Health Education', Icons.school_rounded, const Color(0xFF26A69A), () => context.go('/chw/education')),
      ],
    );
  }

  Widget _actionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
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

  Widget _buildEmptyPatients() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, color: Colors.grey.shade300, size: 40),
          const SizedBox(height: 10),
          Text('No patients assigned yet', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['full_name'] as String? ?? 'Unknown';
    final medilinkId = patient['medilink_id'] as String? ?? '';

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
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.canopy.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.canopy)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (medilinkId.isNotEmpty)
                  Text(medilinkId, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final date = visit['visit_date'] as String? ?? '';
    final visitType = visit['visit_type'] as String? ?? 'General';
    final notes = visit['notes'] as String? ?? '';

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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.canopy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_hospital_rounded, color: AppColors.canopy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visitType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (notes.isNotEmpty)
                  Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (date.isNotEmpty)
            Text(
              _formatDate(date),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month}/${d.year}';
  }
}
