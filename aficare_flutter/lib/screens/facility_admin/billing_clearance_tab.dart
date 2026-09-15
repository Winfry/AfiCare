import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clearance_row_model.dart';
import '../../models/facility_model.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D0D1B2A), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F0D1B2A), blurRadius: 18, offset: Offset(0, 6)),
];

const _eligibilityLabel = {
  'pending': 'Pending',
  'verified': 'Verified',
  'rejected': 'Rejected',
};

const _eligibilityColor = {
  'pending': AppColors.marigoldDark,
  'verified': AppColors.tintSuccessFg,
  'rejected': AppColors.tintUrgentFg,
};

const _payerLabel = {
  'sha': 'SHA',
  'insurance': 'Insurance',
  'cash': 'Cash',
};

const _payerColor = {
  'sha': AppColors.adminColor,
  'insurance': AppColors.primaryNavy,
  'cash': AppColors.steel,
};

/// Billing & Clearance — step 3 of the facility-admin-as-HMS roadmap. A
/// clearance "row" is not its own record: it's a `visits` row (from the
/// Patients feature, step 1) carrying payer_type/eligibility_status. This
/// screen only tracks and updates that state -- see
/// 022_billing_clearance.sql and FacilityPatientProvider.loadClearanceVisits.
class BillingClearanceTab extends StatelessWidget {
  const BillingClearanceTab({super.key, required this.facility});
  final FacilityModel facility;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final visits = provider.clearanceVisits;

    final pending = visits.where((v) => v.eligibilityStatus == 'pending').length;
    final verified = visits.where((v) => v.eligibilityStatus == 'verified').length;
    final rejected = visits.where((v) => v.eligibilityStatus == 'rejected').length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing & Clearance', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _tallyCard(context, 'Pending', pending)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Verified', verified)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Rejected', rejected)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: provider.isLoading && visits.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : visits.isEmpty
                    ? Center(child: Text('No visits today', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _clearanceRow(context, visits[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tallyCard(BuildContext context, String label, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('$count', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _clearanceRow(BuildContext context, ClearanceRowModel v) {
    final payer = v.payerType;
    final eligibility = v.eligibilityStatus;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.tintNavyBg,
            child: Text(
              _initials(v.patientName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tintNavyFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.patientName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (v.patientFileNumber != null && v.patientFileNumber!.isNotEmpty) v.patientFileNumber!,
                    v.visitStatus,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _chip(context, payer != null ? _payerLabel[payer] ?? payer : 'No payer', payer != null ? _payerColor[payer] ?? AppColors.steel : AppColors.steel),
          const SizedBox(width: 6),
          _chip(context, _eligibilityLabel[eligibility] ?? eligibility, _eligibilityColor[eligibility] ?? AppColors.steel),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _showSetClearanceDialog(context, v),
            child: const Text('Set Clearance'),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showSetClearanceDialog(BuildContext context, ClearanceRowModel v) {
    var payerType = v.payerType;
    var eligibilityStatus = v.eligibilityStatus;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(v.patientName),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payer', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _payerLabel.entries.map((e) {
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: payerType == e.key,
                        onSelected: (_) => setState(() => payerType = e.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Eligibility', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _eligibilityLabel.entries.map((e) {
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: eligibilityStatus == e.key,
                        onSelected: (_) => setState(() => eligibilityStatus = e.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setState(() => submitting = true);
                        final provider = ctx.read<FacilityPatientProvider>();
                        final ok = await provider.updateVisitClearance(
                          visitId: v.visitId,
                          newPayerType: payerType,
                          newEligibilityStatus: eligibilityStatus,
                        );
                        if (ok) await provider.loadClearanceVisits(facility.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Clearance updated' : 'Failed: ${provider.error}')),
                          );
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
