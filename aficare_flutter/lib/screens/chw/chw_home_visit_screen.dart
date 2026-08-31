import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';

class CHWHomeVisitScreen extends StatefulWidget {
  const CHWHomeVisitScreen({super.key});

  @override
  State<CHWHomeVisitScreen> createState() => _CHWHomeVisitScreenState();
}

class _CHWHomeVisitScreenState extends State<CHWHomeVisitScreen> {
  final _supabase = Supabase.instance.client;
  final _notesCtrl = TextEditingController();
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  String? _patientId;
  String _visitType = 'routine';
  List<Map<String, dynamic>> _patients = [];
  bool _isSaving = false;

  static const _visitTypes = {
    'routine': 'Routine',
    'follow_up': 'Follow-up',
    'emergency': 'Emergency',
    'prenatal': 'Prenatal',
    'postnatal': 'Postnatal',
    'child_wellness': 'Child Wellness',
    'chronic_disease': 'Chronic Disease',
  };

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
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
            .select('id, full_name')
            .inFilter('id', ids)
            .order('full_name');
        _patients = (users as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading patients: $e');
      showErrorSnackBar(context, 'Could not load home visits');
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null || _patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a patient to record the visit'), backgroundColor: Color(0xFFC62828)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _supabase.from('chv_visits').insert({
        'id': const Uuid().v4(),
        'chv_id': chvId,
        'patient_id': _patientId,
        'visit_type': _visitType,
        'visit_date': DateTime.now().toIso8601String(),
        'vitals': {
          'systolic': int.tryParse(_bpSysCtrl.text),
          'diastolic': int.tryParse(_bpDiaCtrl.text),
          'weight_kg': double.tryParse(_weightCtrl.text),
          'temperature_c': double.tryParse(_tempCtrl.text),
        },
        'notes': _notesCtrl.text.trim(),
        'flags': [],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home visit saved'), backgroundColor: Color(0xFF2E7D32)),
        );
        context.go('/chw');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
        title: const Text('Record Home Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _patients.isEmpty
                ? Text('No assigned patients.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                : Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _patients.map((p) {
                      final sel = _patientId == p['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _patientId = p['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.canopy.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel ? AppColors.canopy : AppColors.borderSubtle),
                          ),
                          child: Text(p['full_name'] as String? ?? 'Unknown',
                              style: TextStyle(fontSize: 13, color: sel ? AppColors.canopy : Colors.grey.shade700, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),
            const Text('Visit Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _visitTypes.entries.map((e) {
                final sel = _visitType == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _visitType = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.canopy.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppColors.canopy : AppColors.borderSubtle),
                    ),
                    child: Text(e.value, style: TextStyle(fontSize: 13, color: sel ? AppColors.canopy : Colors.grey.shade700, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Vital Signs (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('Systolic BP', _bpSysCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _field('Diastolic BP', _bpDiaCtrl)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('Weight (kg)', _weightCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _field('Temp (°C)', _tempCtrl)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Visit', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
