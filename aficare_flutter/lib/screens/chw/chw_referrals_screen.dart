import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';

class CHWReferralsScreen extends StatefulWidget {
  const CHWReferralsScreen({super.key});

  @override
  State<CHWReferralsScreen> createState() => _CHWReferralsScreenState();
}

class _CHWReferralsScreenState extends State<CHWReferralsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _referrals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null) return;
    try {
      final data = await _supabase
          .from('referrals')
          .select()
          .eq('from_provider_id', chvId)
          .order('created_at', ascending: false)
          .limit(50);
      _referrals = (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error loading referrals: $e');
      showErrorSnackBar(context, 'Could not load referrals');
    }
    if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Referrals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _openCreateSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.canopy))
          : _referrals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No referrals yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Tap + to refer a patient to a facility.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openCreateSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('New Referral'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _referrals.length,
                  itemBuilder: (context, i) => _referralCard(_referrals[i]),
                ),
    );
  }

  Widget _referralCard(Map<String, dynamic> r) {
    final status = (r['status'] as String? ?? 'pending').toUpperCase();
    final toFacility = r['to_facility'] as String? ?? '';
    final reason = r['reason'] as String? ?? '';
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();
    final color = status == 'COMPLETED'
        ? const Color(0xFF2E7D32)
        : status == 'ACCEPTED'
            ? const Color(0xFF1565C0)
            : const Color(0xFFF57F17);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
              const Spacer(),
              Text('${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.local_hospital_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(child: Text(toFacility, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 6),
          Text(reason, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewReferralSheet(onComplete: _load),
    );
  }
}

class _NewReferralSheet extends StatefulWidget {
  final VoidCallback onComplete;
  const _NewReferralSheet({required this.onComplete});

  @override
  State<_NewReferralSheet> createState() => _NewReferralSheetState();
}

class _NewReferralSheetState extends State<_NewReferralSheet> {
  final _supabase = Supabase.instance.client;
  final _reasonCtrl = TextEditingController();
  final _facilityCtrl = TextEditingController();
  String? _patientId;
  List<Map<String, dynamic>> _patients = [];
  bool _isSaving = false;

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
      debugPrint('Error loading patients for referral: $e');
      showErrorSnackBar(context, 'Could not load patients for referral');
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final chvId = _supabase.auth.currentUser?.id;
    final reason = _reasonCtrl.text.trim();
    final facility = _facilityCtrl.text.trim();
    if (chvId == null || _patientId == null || reason.isEmpty || facility.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a patient, facility, and provide a reason'), backgroundColor: Color(0xFFC62828)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _supabase.from('referrals').insert({
        'id': const Uuid().v4(),
        'from_provider_id': chvId,
        'patient_id': _patientId,
        'to_facility': facility,
        'reason': reason,
        'urgency': 'routine',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral sent'), backgroundColor: Color(0xFF2E7D32)),
        );
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('New Referral', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
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
                              color: sel ? AppColors.canopy.withOpacity(0.1) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? AppColors.canopy : AppColors.borderSubtle),
                            ),
                            child: Text(p['full_name'] as String? ?? 'Unknown',
                                style: TextStyle(fontSize: 13, color: sel ? AppColors.canopy : Colors.grey.shade700, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                          ),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 14),
              TextField(
                controller: _facilityCtrl,
                decoration: InputDecoration(labelText: 'Facility / Department', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Reason for referral', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Referral', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
