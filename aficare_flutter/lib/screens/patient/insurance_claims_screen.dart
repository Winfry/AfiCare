import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/insurance_claim_model.dart';

class InsuranceClaimsScreen extends StatefulWidget {
  const InsuranceClaimsScreen({super.key});

  @override
  State<InsuranceClaimsScreen> createState() => _InsuranceClaimsScreenState();
}

class _InsuranceClaimsScreenState extends State<InsuranceClaimsScreen> {
  final _supabase = Supabase.instance.client;
  List<InsuranceClaim> _claims = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      final data = await _supabase
          .from('insurance_claims')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(50);
      _claims = (data as List).map((j) => InsuranceClaim.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading claims: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<InsuranceClaim> get _filteredClaims {
    if (_selectedTab == 0) return _claims;
    final statuses = ['draft', 'submitted', 'in_review', 'approved', 'rejected', 'paid'];
    if (_selectedTab <= statuses.length) return _claims.where((c) => c.claimStatus == statuses[_selectedTab - 1]).toList();
    return _claims;
  }

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
            title: const Text('Insurance Claims', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: _showNewClaimSheet,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('New Claim', style: TextStyle(color: Colors.white, fontSize: 13)),
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
                      _stat('${_claims.length}', 'Total', Icons.receipt_long_rounded, AppColors.canopy),
                      const SizedBox(width: 10),
                      _stat('${_claims.where((c) => c.claimStatus == 'approved' || c.claimStatus == 'paid').length}', 'Approved', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      _stat('KES ${_formatNum(_claims.where((c) => c.claimStatus == 'paid').fold(0.0, (s, c) => s + (c.approvedAmount ?? 0)))}', 'Paid', Icons.payments_rounded, const Color(0xFF1565C0)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tabs
                  _buildTabs(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_filteredClaims.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No claims found.', style: TextStyle(color: Colors.grey.shade400))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _claimCard(_filteredClaims[i]),
                ),
                childCount: _filteredClaims.length,
              ),
            ),
          // NHIF Directory link
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
                      const SizedBox(width: 8),
                      const Text('NHIF Information', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                    ]),
                    const SizedBox(height: 8),
                    Text('Submit claims through the NHIF portal or your facility. Pre-authorization is required for surgeries and specialized procedures.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text('NHIF Call Centre: 0800 723 200 | nhif.or.ke', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['All', 'Draft', 'Submitted', 'Review', 'Approved', 'Rejected', 'Paid'];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final sel = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? AppColors.canopy : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sel ? AppColors.canopy : AppColors.borderSubtle),
              ),
              child: Center(child: Text(tabs[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey.shade700))),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _claimCard(InsuranceClaim claim) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor(claim.claimStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(InsuranceClaim.statusLabel(claim.claimStatus),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(claim.claimStatus))),
              ),
              const SizedBox(width: 8),
              Text(InsuranceClaim.insuranceTypeLabel(claim.insuranceType),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const Spacer(),
              Text('${claim.dateOfService.day}/${claim.dateOfService.month}/${claim.dateOfService.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 10),
          if (claim.diagnosis != null)
            Text(claim.diagnosis!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('KES ${_formatNum(claim.claimedAmount)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (claim.approvedAmount != null) ...[
                const SizedBox(width: 8),
                Text('→ KES ${_formatNum(claim.approvedAmount!)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF2E7D32))),
              ],
            ],
          ),
          if (claim.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
              child: Text('Reason: ${claim.rejectionReason}', style: const TextStyle(fontSize: 12, color: Color(0xFFF57F17))),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'submitted': return const Color(0xFF1565C0);
      case 'in_review': return const Color(0xFFF57F17);
      case 'approved': return const Color(0xFF2E7D32);
      case 'rejected': return const Color(0xFFC62828);
      case 'paid': return const Color(0xFF1565C0);
      default: return Colors.grey;
    }
  }

  void _showNewClaimSheet() {
    final diagnosisCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    String insuranceType = 'nhif';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Insurance Claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                const Text('Insurance Type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _typeChoice('NHIF', 'nhif', insuranceType, (v) => setSheetState(() => insuranceType = v)),
                  _typeChoice('Private', 'private', insuranceType, (v) => setSheetState(() => insuranceType = v)),
                  _typeChoice('Community', 'community', insuranceType, (v) => setSheetState(() => insuranceType = v)),
                ]),
                const SizedBox(height: 14),
                _field('Insurance Number', numberCtrl),
                const SizedBox(height: 10),
                _field('Diagnosis', diagnosisCtrl),
                const SizedBox(height: 10),
                _field('Claimed Amount (KES)', amountCtrl, TextInputType.number),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: diagnosisCtrl.text.trim().isEmpty ? null : () async {
                        final patientId = _supabase.auth.currentUser?.id;
                        if (patientId == null) return;
                        await _supabase.from('insurance_claims').insert({
                          'id': const Uuid().v4(),
                          'patient_id': patientId,
                          'insurance_type': insuranceType,
                          'insurance_number': numberCtrl.text.trim(),
                          'claim_status': 'draft',
                          'claimed_amount': double.tryParse(amountCtrl.text) ?? 0,
                          'diagnosis': diagnosisCtrl.text.trim(),
                          'date_of_service': DateTime.now().toIso8601String(),
                          'created_at': DateTime.now().toIso8601String(),
                        });
                        if (mounted) { Navigator.pop(ctx); _loadClaims(); }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Create Claim', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChoice(String label, String value, String groupValue, ValueChanged<String> onChanged) {
    final sel = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  String _formatNum(double n) => n.toStringAsFixed(0);
}
