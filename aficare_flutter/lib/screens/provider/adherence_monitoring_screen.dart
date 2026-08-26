import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class AdherenceMonitoringScreen extends StatefulWidget {
  const AdherenceMonitoringScreen({super.key});

  @override
  State<AdherenceMonitoringScreen> createState() => _AdherenceMonitoringScreenState();
}

class _AdherenceMonitoringScreenState extends State<AdherenceMonitoringScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final data = await _supabase
          .from('patient_profiles')
          .select('id, full_name, date_of_birth, gender')
          .ilike('full_name', '%%')
          .order('full_name');
      _patients = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading patients for adherence: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _patients
        : _patients.where((p) => (p['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/provider'),
            ),
            title: const Text('Adherence Monitoring', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search patients by name...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      _statCard('Total', '${_patients.length}', AppColors.canopy),
                      const SizedBox(width: 10),
                      _statCard('Active', '${_patients.length}', const Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      _statCard('Defaulters', '0', const Color(0xFFE53935)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Patients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.canopy)))
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
                child: Text('No patients found', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _patientCard(filtered[i]),
                childCount: filtered.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _patientCard(Map<String, dynamic> patient) {
    final name = patient['full_name'] ?? 'Unknown';
    final dob = patient['date_of_birth'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.canopy.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.canopy, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (dob != null)
                  Text('DOB: $dob', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
            child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }
}
