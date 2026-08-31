import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/household_model.dart';
import '../../utils/snackbar_utils.dart';

class CHWHouseholdScreen extends StatefulWidget {
  const CHWHouseholdScreen({super.key});

  @override
  State<CHWHouseholdScreen> createState() => _CHWHouseholdScreenState();
}

class _CHWHouseholdScreenState extends State<CHWHouseholdScreen> {
  final _supabase = Supabase.instance.client;
  List<Household> _households = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
  }

  Future<void> _loadHouseholds() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null) return;

    try {
      final data = await _supabase
          .from('households')
          .select()
          .eq('chv_id', chvId)
          .order('created_at', ascending: false);
      _households = (data as List).map((j) => Household.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading households: $e');
      showErrorSnackBar(context, 'Could not load household data');
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
        title: const Text('Households', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          TextButton.icon(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.canopy))
          : _households.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadHouseholds,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _households.length,
                    itemBuilder: (context, i) => _householdCard(_households[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No Households', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text('Register households to track family health data.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Register Household'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.canopy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _householdCard(Household h) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.canopy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.home_rounded, color: AppColors.canopy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.householdName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (h.village != null) Text(h.village!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _pill('${h.totalMembers} members', Icons.people_rounded),
              if (h.childrenUnder5 > 0) _pill('${h.childrenUnder5} under 5', Icons.child_care_rounded),
              if (h.pregnantWomen > 0) _pill('${h.pregnantWomen} pregnant', Icons.pregnant_woman_rounded),
              if (h.elderlyMembers > 0) _pill('${h.elderlyMembers} elderly', Icons.elderly_rounded),
              if (h.chronicallyIll > 0) _pill('${h.chronicallyIll} chronic', Icons.healing_rounded),
              _pill(h.hasMosquitoNets ? ' nets ✓' : ' no nets', Icons.bed_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.canopy),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    final membersCtrl = TextEditingController(text: '1');
    final childrenCtrl = TextEditingController(text: '0');
    final pregnantCtrl = TextEditingController(text: '0');
    final elderlyCtrl = TextEditingController(text: '0');
    final chronicCtrl = TextEditingController(text: '0');
    bool hasNets = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Register Household', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                _field('Household Name', nameCtrl),
                const SizedBox(height: 10),
                _field('Village', villageCtrl),
                const SizedBox(height: 10),
                _field('Total Members', membersCtrl, TextInputType.number),
                const SizedBox(height: 10),
                _field('Children Under 5', childrenCtrl, TextInputType.number),
                const SizedBox(height: 10),
                _field('Pregnant Women', pregnantCtrl, TextInputType.number),
                const SizedBox(height: 10),
                _field('Elderly Members', elderlyCtrl, TextInputType.number),
                const SizedBox(height: 10),
                _field('Chronically Ill', chronicCtrl, TextInputType.number),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Has Mosquito Nets', style: TextStyle(fontSize: 14)),
                  value: hasNets,
                  onChanged: (v) => setSheetState(() => hasNets = v),
                  activeColor: AppColors.canopy,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: nameCtrl.text.trim().isEmpty ? null : () async {
                      final chvId = _supabase.auth.currentUser?.id;
                      if (chvId == null) return;

                      try {
                        await _supabase.from('households').insert({
                          'id': const Uuid().v4(),
                          'chv_id': chvId,
                          'household_name': nameCtrl.text.trim(),
                          'village': villageCtrl.text.trim(),
                          'total_members': int.tryParse(membersCtrl.text) ?? 1,
                          'children_under_5': int.tryParse(childrenCtrl.text) ?? 0,
                          'pregnant_women': int.tryParse(pregnantCtrl.text) ?? 0,
                          'elderly_members': int.tryParse(elderlyCtrl.text) ?? 0,
                          'chronically_ill': int.tryParse(chronicCtrl.text) ?? 0,
                          'has_mosquito_nets': hasNets,
                          'created_at': DateTime.now().toIso8601String(),
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadHouseholds();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving household: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.canopy, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Household', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, [TextInputType type = TextInputType.text]) {
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
}
