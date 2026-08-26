import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class CHWNewVisitScreen extends StatefulWidget {
  const CHWNewVisitScreen({super.key});

  @override
  State<CHWNewVisitScreen> createState() => _CHWNewVisitScreenState();
}

class _CHWNewVisitScreenState extends State<CHWNewVisitScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedPatient;
  String _visitType = 'routine';
  bool _isSaving = false;
  List<String> _flags = [];

  final _visitTypes = [
    ('routine', 'Routine Check-up'),
    ('followup', 'Follow-up'),
    ('emergency', 'Emergency'),
    ('antenatal', 'Antenatal'),
    ('postnatal', 'Postnatal'),
    ('child_health', 'Child Health'),
    ('ncd', 'NCD Management'),
  ];

  final _commonFlags = [
    'Hypertension', 'Diabetes', 'Pregnancy', 'Child under 5',
    'HIV+', 'Malnutrition', 'Tuberculosis', 'Elderly',
  ];

  Future<void> _searchPatient(String query) async {
    if (query.length < 2) { setState(() => _searchResults = []); return; }
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, phone, medilink_id')
          .eq('role', 'patient')
          .ilike('full_name', '%$query%')
          .limit(10);
      setState(() => _searchResults = (data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('Search error: $e');
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
        title: const Text('New Home Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            if (_selectedPatient == null) ...[
              TextField(
                controller: _searchCtrl,
                onChanged: _searchPatient,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: _searchResults.map((p) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.canopy,
                        child: Text((p['full_name'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(p['full_name'] as String? ?? 'Unknown'),
                      subtitle: Text(p['medilink_id'] as String? ?? p['phone'] as String? ?? ''),
                      onTap: () => setState(() {
                        _selectedPatient = p;
                        _searchCtrl.clear();
                        _searchResults = [];
                      }),
                    )).toList(),
                  ),
                ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canopy.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.canopy.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.canopy,
                      child: Text((_selectedPatient!['full_name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedPatient!['full_name'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_selectedPatient!['medilink_id'] as String? ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedPatient = null),
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            const Text('Visit Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _visitTypes.map((vt) {
                final sel = _visitType == vt.$1;
                return GestureDetector(
                  onTap: () => setState(() => _visitType = vt.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.canopy.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.canopy : AppColors.borderSubtle, width: sel ? 2 : 1,
                      ),
                    ),
                    child: Text(vt.$2, style: TextStyle(
                      fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? AppColors.canopy : Colors.grey.shade700,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text('Vitals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('Systolic BP', _bpSysCtrl, TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _field('Diastolic BP', _bpDiaCtrl, TextInputType.number)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('Weight (kg)', _weightCtrl, TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _field('Temp (\u00b0C)', _tempCtrl, TextInputType.number)),
            ]),
            const SizedBox(height: 20),

            const Text('Patient Flags', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _commonFlags.map((flag) {
                final sel = _flags.contains(flag);
                return FilterChip(
                  label: Text(flag, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey.shade700)),
                  selected: sel,
                  onSelected: (s) => setState(() { if (s) _flags.add(flag); else _flags.remove(flag); }),
                  selectedColor: AppColors.canopy,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: sel ? AppColors.canopy : AppColors.borderSubtle),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text('Visit Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the visit, observations, actions taken...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: (_selectedPatient != null && !_isSaving) ? _saveVisit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.canopy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Visit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _saveVisit() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null || _selectedPatient == null) return;
    setState(() => _isSaving = true);

    try {
      await _supabase.from('chv_visits').insert({
        'chv_id': chvId,
        'patient_id': _selectedPatient!['id'],
        'visit_type': _visitType,
        'systolic_bp': int.tryParse(_bpSysCtrl.text),
        'diastolic_bp': int.tryParse(_bpDiaCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
        'temperature': double.tryParse(_tempCtrl.text),
        'flags': _flags,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'visit_date': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit saved'), backgroundColor: Color(0xFF2E7D32)),
        );
        context.go('/chw');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    _bpSysCtrl.dispose();
    _bpDiaCtrl.dispose();
    _weightCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }
}
