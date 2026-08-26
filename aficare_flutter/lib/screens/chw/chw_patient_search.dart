import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class CHWPatientSearchScreen extends StatefulWidget {
  const CHWPatientSearchScreen({super.key});

  @override
  State<CHWPatientSearchScreen> createState() => _CHWPatientSearchScreenState();
}

class _CHWPatientSearchScreenState extends State<CHWPatientSearchScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _assigned = [];
  bool _isLoading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadAssigned();
  }

  Future<void> _loadAssigned() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null) return;

    try {
      final data = await _supabase
          .from('care_team')
          .select('patient_id')
          .eq('provider_id', chvId);
      final ids = (data as List).map((r) => r['patient_id'] as String).toList();
      if (ids.isNotEmpty) {
        final users = await _supabase
            .from('users')
            .select('id, full_name, phone, medilink_id')
            .inFilter('id', ids)
            .order('full_name');
        _assigned = (users as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading patients: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _search(String query) async {
    if (query.length < 2) { _loadAssigned(); return; }
    setState(() => _searching = true);
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, phone, medilink_id')
          .eq('role', 'patient')
          .ilike('full_name', '%$query%')
          .limit(20);
      setState(() { _patients = (data as List).cast<Map<String, dynamic>>(); _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.canopy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/chw'),
        ),
        title: const Text('Patients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ) : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.canopy))
                : (_searchCtrl.text.isEmpty ? _assigned : _patients).isEmpty
                    ? Center(child: Text('No patients found', style: TextStyle(color: Colors.grey.shade400)))
                    : ListView.builder(
                        itemCount: (_searchCtrl.text.isEmpty ? _assigned : _patients).length,
                        itemBuilder: (context, i) {
                          final p = (_searchCtrl.text.isEmpty ? _assigned : _patients)[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.canopy,
                              child: Text((p['full_name'] as String? ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(p['full_name'] as String? ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(p['medilink_id'] as String? ?? p['phone'] as String? ?? ''),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
