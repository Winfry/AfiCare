import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/medication_cost_model.dart';

class MedicationCostScreen extends StatefulWidget {
  const MedicationCostScreen({super.key});

  @override
  State<MedicationCostScreen> createState() => _MedicationCostScreenState();
}

class _MedicationCostScreenState extends State<MedicationCostScreen> {
  final _supabase = Supabase.instance.client;
  List<MedicationCost> _costs = [];
  bool _isLoading = true;
  double _monthlyBudget = 5000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      // Load budget from preferences
      try {
        final pref = await _supabase
            .from('user_preferences')
            .select('preferences')
            .eq('user_id', patientId)
            .maybeSingle();
        if (pref != null && pref['preferences'] != null) {
          final prefs = pref['preferences'] as Map<String, dynamic>;
          _monthlyBudget = (prefs['monthly_med_budget'] as num?)?.toDouble() ?? 5000;
        }
      } catch (_) {}

      final data = await _supabase
          .from('medication_costs')
          .select()
          .eq('patient_id', patientId)
          .order('purchase_date', ascending: false)
          .limit(100);
      _costs = (data as List).map((j) => MedicationCost.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading medication costs: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  double get _thisMonthSpent {
    final now = DateTime.now();
    return _costs
        .where((c) => c.purchaseDate.year == now.year && c.purchaseDate.month == now.month)
        .fold(0.0, (sum, c) => sum + c.totalCost);
  }

  double get _thisMonthBudget => _monthlyBudget;
  double get _budgetRemaining => _thisMonthBudget - _thisMonthSpent;
  bool get _isOverBudget => _thisMonthSpent > _thisMonthBudget;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.canopy)));
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/patient'),
            ),
            title: const Text('Medication Costs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: _showAddSheet,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget card
                  _buildBudgetCard(),
                  const SizedBox(height: 16),
                  // Stats
                  Row(
                    children: [
                      _stat('KES ${_formatNum(_totalSpent)}', 'Total Spent', Icons.receipt_long_rounded, const Color(0xFF5C6BC0)),
                      const SizedBox(width: 10),
                      _stat('${_costs.length}', 'Purchases', Icons.shopping_bag_rounded, AppColors.canopy),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Purchase History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (_costs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No purchases recorded.', style: TextStyle(color: Colors.grey.shade400))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _costCard(_costs[i]),
                ),
                childCount: _costs.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final usage = _thisMonthBudget > 0 ? (_thisMonthSpent / _thisMonthBudget).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOverBudget
              ? [const Color(0xFFC62828), const Color(0xFFE53935)]
              : [AppColors.canopy, AppColors.canopyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Monthly Budget', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              IconButton(
                onPressed: _showBudgetEditSheet,
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('KES ${_formatNum(_thisMonthSpent)} / ${_formatNum(_thisMonthBudget)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usage,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(_isOverBudget ? Colors.white : Colors.white70),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isOverBudget
                ? 'Over budget by KES ${_formatNum(-_budgetRemaining)}'
                : 'KES ${_formatNum(_budgetRemaining)} remaining',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _costCard(MedicationCost c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.canopy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.medication_rounded, color: AppColors.canopy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.medicationName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${c.dosage} x ${c.quantity} • ${MedicationCost.paymentMethodLabel(c.paymentMethod)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text('KES ${_formatNum(c.totalCost)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  double get _totalSpent => _costs.fold(0.0, (sum, c) => sum + c.totalCost);
  String _formatNum(double n) => n.toStringAsFixed(0);

  void _showAddSheet() {
    final medCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    final pharmacyCtrl = TextEditingController();
    String paymentMethod = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Purchase', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                _field('Medication Name', medCtrl),
                const SizedBox(height: 10),
                _field('Dosage', dosageCtrl),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Quantity', qtyCtrl, TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Total Cost (KES)', costCtrl, TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                _field('Pharmacy', pharmacyCtrl),
                const SizedBox(height: 12),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _paymentChoice('Cash', 'cash', paymentMethod, (v) => setSheetState(() => paymentMethod = v)),
                  _paymentChoice('NHIF', 'nhif', paymentMethod, (v) => setSheetState(() => paymentMethod = v)),
                  _paymentChoice('Insurance', 'insurance', paymentMethod, (v) => setSheetState(() => paymentMethod = v)),
                  _paymentChoice('M-Pesa', 'mhealth', paymentMethod, (v) => setSheetState(() => paymentMethod = v)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: medCtrl.text.trim().isEmpty ? null : () async {
                      final patientId = _supabase.auth.currentUser?.id;
                      if (patientId == null) return;
                      final qty = int.tryParse(qtyCtrl.text) ?? 1;
                      final total = double.tryParse(costCtrl.text) ?? 0;

                      await _supabase.from('medication_costs').insert({
                        'id': const Uuid().v4(),
                        'patient_id': patientId,
                        'medication_name': medCtrl.text.trim(),
                        'dosage': dosageCtrl.text.trim(),
                        'quantity': qty,
                        'unit_cost': qty > 0 ? total / qty : total,
                        'total_cost': total,
                        'pharmacy_name': pharmacyCtrl.text.trim().isNotEmpty ? pharmacyCtrl.text.trim() : null,
                        'payment_method': paymentMethod,
                        'purchase_date': DateTime.now().toIso8601String(),
                      });
                      if (mounted) { Navigator.pop(ctx); _loadData(); }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBudgetEditSheet() {
    final budgetCtrl = TextEditingController(text: _monthlyBudget.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Monthly Budget (KES)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            _field('Budget Amount', budgetCtrl, TextInputType.number),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final patientId = _supabase.auth.currentUser?.id;
                  if (patientId == null) return;
                  final budget = double.tryParse(budgetCtrl.text) ?? 5000;
                  try {
                    await _supabase.from('user_preferences').upsert({
                      'user_id': patientId,
                      'preferences': {'monthly_med_budget': budget},
                    });
                  } catch (_) {}
                  if (mounted) { setState(() => _monthlyBudget = budget); Navigator.pop(ctx); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChoice(String label, String value, String groupValue, ValueChanged<String> onChanged) {
    final sel = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.canopy.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.canopy : AppColors.borderSubtle),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.canopy : Colors.grey.shade700)),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, [TextInputType type = TextInputType.text]) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.canopy, width: 1.5)),
      ),
    );
  }
}
