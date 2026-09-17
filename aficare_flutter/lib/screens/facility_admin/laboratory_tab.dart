import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clearance_row_model.dart';
import '../../models/facility_model.dart';
import '../../models/lab_order_row_model.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

const _statusLabel = {
  'pending': 'Pending',
  'processing': 'Processing',
  'completed': 'Completed',
};

const _statusColor = {
  'pending': AppColors.marigoldDark,
  'processing': AppColors.steel,
  'completed': AppColors.sage,
};

const _nextStatus = {
  'pending': 'processing',
  'processing': 'completed',
};

const _advanceLabel = {
  'pending': 'Start Processing',
  'processing': 'Mark Complete',
};

const _turnaroundTarget = Duration(hours: 2);

/// Laboratory — step 4 of the facility-admin-as-HMS roadmap. An order is
/// its own record (`visit_lab_orders`, not a `visits` column) since a
/// visit can have multiple concurrent orders. "Overdue" is never stored
/// -- it's computed here from ordered_at vs. a fixed 2h target, the same
/// way OPD Queue computes "waiting X min" without a stored "late" status.
/// See 024_visit_lab_orders.sql and FacilityPatientProvider.loadLabOrders.
class LaboratoryTab extends StatefulWidget {
  const LaboratoryTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<LaboratoryTab> createState() => _LaboratoryTabState();
}

class _LaboratoryTabState extends State<LaboratoryTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Turnaround text ("1h 40m", "— overdue") has no data change to react
    // to on its own -- ordered_at is static -- so a periodic rebuild is
    // what keeps it live, same as OPD Queue's wait-time ticker.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  bool _isOverdue(LabOrderRowModel o) =>
      o.status != 'completed' && DateTime.now().difference(o.orderedAt) > _turnaroundTarget;

  String _formatElapsed(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final orders = provider.labOrders;

    final pending = orders.where((o) => o.status == 'pending').length;
    final processing = orders.where((o) => o.status == 'processing').length;
    final completed = orders.where((o) => o.status == 'completed').length;
    final overdue = orders.where(_isOverdue).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Laboratory', style: Theme.of(context).textTheme.headlineSmall)),
              ElevatedButton.icon(
                onPressed: () => _showNewOrderDialog(context),
                icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                label: Text(
                  'New Order',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.deepNavy, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.marigold,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _tallyCard(context, 'Pending', pending)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Processing', processing)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Completed', completed)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Overdue', overdue, valueColor: overdue > 0 ? AppColors.emergency : null)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: provider.isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? Center(child: Text('No lab orders today', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _orderRow(context, orders[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tallyCard(BuildContext context, String label, int count, {Color? valueColor}) {
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
          Text('$count', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: valueColor)),
        ],
      ),
    );
  }

  Widget _orderRow(BuildContext context, LabOrderRowModel o) {
    final overdue = _isOverdue(o);
    final facilityId = widget.facility.id;

    Widget turnaroundText;
    if (o.status == 'completed') {
      turnaroundText = Text('Completed', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.sage, fontWeight: FontWeight.w600));
    } else {
      final elapsed = DateTime.now().difference(o.orderedAt);
      turnaroundText = Text(
        overdue ? '${_formatElapsed(elapsed)} — overdue' : _formatElapsed(elapsed),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: overdue ? AppColors.emergency : null,
              fontWeight: overdue ? FontWeight.w600 : null,
            ),
      );
    }

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
              _initials(o.patientName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tintNavyFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.testName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${o.patientName} · Ordered by ${o.orderedByName}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          turnaroundText,
          const SizedBox(width: 12),
          overdue
              ? _chip(context, 'Overdue', AppColors.emergency)
              : _chip(context, _statusLabel[o.status] ?? o.status, _statusColor[o.status] ?? AppColors.steel),
          const SizedBox(width: 12),
          if (_nextStatus.containsKey(o.status))
            ElevatedButton(
              onPressed: () async {
                final ok = await context.read<FacilityPatientProvider>().updateLabOrderStatus(
                      labOrderId: o.labOrderId,
                      newStatus: _nextStatus[o.status]!,
                    );
                if (context.mounted) {
                  await context.read<FacilityPatientProvider>().loadLabOrders(facilityId);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${context.read<FacilityPatientProvider>().error}')),
                    );
                  }
                }
              },
              child: Text(_advanceLabel[o.status] ?? 'Advance'),
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

  void _showNewOrderDialog(BuildContext context) {
    final facilityId = widget.facility.id;
    final searchCtl = TextEditingController();
    final testNameCtl = TextEditingController();
    ClearanceRowModel? selectedVisit;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final todaysVisits = ctx.watch<FacilityPatientProvider>().clearanceVisits;
          final query = searchCtl.text.trim().toLowerCase();
          final matches = query.isEmpty
              ? const <ClearanceRowModel>[]
              : todaysVisits.where((v) => v.patientName.toLowerCase().contains(query)).take(6).toList();

          return AlertDialog(
            title: Text(selectedVisit == null ? 'New Lab Order' : 'Order Details'),
            content: SizedBox(
              width: 420,
              child: selectedVisit == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: searchCtl,
                          decoration: const InputDecoration(labelText: 'Search today\'s patients by name', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        if (matches.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView(
                              shrinkWrap: true,
                              children: matches
                                  .map((v) => ListTile(
                                        dense: true,
                                        title: Text(v.patientName),
                                        subtitle: Text(v.patientFileNumber ?? ''),
                                        onTap: () => setState(() => selectedVisit = v),
                                      ))
                                  .toList(),
                            ),
                          )
                        else if (query.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No match among today\'s visits', style: Theme.of(ctx).textTheme.bodySmall),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedVisit!.patientName, style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: testNameCtl,
                          decoration: const InputDecoration(labelText: 'Test Name', isDense: true, hintText: 'e.g. Full haemogram'),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (selectedVisit != null)
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (testNameCtl.text.trim().isEmpty) return;
                          setState(() => submitting = true);
                          final provider = ctx.read<FacilityPatientProvider>();
                          final newId = await provider.placeLabOrder(
                            visitId: selectedVisit!.visitId,
                            testName: testNameCtl.text.trim(),
                          );
                          if (newId != null) await provider.loadLabOrders(facilityId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(newId != null ? 'Lab order placed' : 'Failed: ${provider.error}')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Place Order'),
                ),
            ],
          );
        },
      ),
    );
  }
}
