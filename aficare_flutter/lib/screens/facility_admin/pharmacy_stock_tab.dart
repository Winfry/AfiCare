import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clearance_row_model.dart';
import '../../models/drug_stock_model.dart';
import '../../models/facility_model.dart';
import '../../models/prescription_row_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

const _rxStatusLabel = {
  'pending': 'Pending',
  'dispensed': 'Dispensed',
};

const _rxStatusColor = {
  'pending': AppColors.marigoldDark,
  'dispensed': AppColors.sage,
};

const _stockStatusLabel = {
  'critical': 'Reorder now',
  'warning': 'Low',
  'ok': 'In stock',
};

const _stockStatusColor = {
  'critical': AppColors.emergency,
  'warning': AppColors.marigoldDark,
  'ok': AppColors.sage,
};

enum _PharmacySubTab { prescriptions, stock }

/// Pharmacy & Stock — step 5 of the facility-admin-as-HMS roadmap. Two
/// sub-panels: Prescriptions (a visit-derived ledger like Laboratory,
/// living on FacilityPatientProvider) and Stock (a facility-wide catalog
/// like Departments, living on AdminFacilityProvider) -- they're
/// deliberately different providers since stock has no patient/visit
/// dimension at all. Dispensing touches both, so this screen reloads
/// both providers itself after a successful dispense; neither provider
/// reaches into the other's state. See 025_pharmacy_stock.sql.
class PharmacyStockTab extends StatefulWidget {
  const PharmacyStockTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<PharmacyStockTab> createState() => _PharmacyStockTabState();
}

class _PharmacyStockTabState extends State<PharmacyStockTab> {
  _PharmacySubTab _tab = _PharmacySubTab.prescriptions;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pharmacy & Stock', style: Theme.of(context).textTheme.headlineSmall)),
              if (_tab == _PharmacySubTab.prescriptions)
                ElevatedButton.icon(
                  onPressed: () => _showNewPrescriptionDialog(context),
                  icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                  label: Text(
                    'New Prescription',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.deepNavy, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.marigold,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showReceiveStockDialog(context),
                  icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                  label: Text(
                    'Receive Stock',
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
              _tabButton(context, 'Prescriptions', _PharmacySubTab.prescriptions),
              const SizedBox(width: 8),
              _tabButton(context, 'Stock', _PharmacySubTab.stock),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tab == _PharmacySubTab.prescriptions ? _prescriptionsPanel(context) : _stockPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(BuildContext context, String label, _PharmacySubTab value) {
    final selected = _tab == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tintNavyBg : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.tintNavyFg : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
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

  // ---------------------------------------------------------------
  // Prescriptions sub-tab
  // ---------------------------------------------------------------

  Widget _prescriptionsPanel(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final prescriptions = provider.prescriptions;

    final pending = prescriptions.where((p) => p.status == 'pending').length;
    final dispensed = prescriptions.where((p) => p.status == 'dispensed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _tallyCard(context, 'Pending', pending)),
            const SizedBox(width: 12),
            Expanded(child: _tallyCard(context, 'Dispensed', dispensed)),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: provider.isLoading && prescriptions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : prescriptions.isEmpty
                  ? Center(child: Text('No prescriptions today', style: Theme.of(context).textTheme.bodySmall))
                  : ListView.separated(
                      itemCount: prescriptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _prescriptionRow(context, prescriptions[i]),
                    ),
        ),
      ],
    );
  }

  Widget _prescriptionRow(BuildContext context, PrescriptionRowModel p) {
    final facilityId = widget.facility.id;
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
              _initials(p.patientName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tintNavyFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.medicationLabel, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${p.patientName} · Prescribed by ${p.prescribedByName}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _chip(context, _rxStatusLabel[p.status] ?? p.status, _rxStatusColor[p.status] ?? AppColors.steel),
          const SizedBox(width: 12),
          if (p.status == 'pending')
            ElevatedButton(
              onPressed: () async {
                final admin = context.read<AdminFacilityProvider>();
                final ok = await admin.dispensePrescription(prescriptionId: p.prescriptionId);
                if (ok) {
                  await admin.loadDrugStock(facilityId);
                  if (context.mounted) {
                    await context.read<FacilityPatientProvider>().loadPrescriptions(facilityId);
                  }
                }
                if (context.mounted && !ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${admin.error}')),
                  );
                }
              },
              child: const Text('Dispense'),
            ),
        ],
      ),
    );
  }

  void _showNewPrescriptionDialog(BuildContext context) {
    final facilityId = widget.facility.id;
    final patientSearchCtl = TextEditingController();
    final labelCtl = TextEditingController();
    ClearanceRowModel? selectedVisit;
    DrugStockModel? selectedDrug;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final todaysVisits = ctx.watch<FacilityPatientProvider>().clearanceVisits;
          final drugStock = ctx.watch<AdminFacilityProvider>().drugStock;
          final patientQuery = patientSearchCtl.text.trim().toLowerCase();
          final patientMatches = patientQuery.isEmpty
              ? const <ClearanceRowModel>[]
              : todaysVisits.where((v) => v.patientName.toLowerCase().contains(patientQuery)).take(6).toList();

          Widget content;
          if (selectedVisit == null) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: patientSearchCtl,
                  decoration: const InputDecoration(labelText: 'Search today\'s patients by name', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (patientMatches.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: patientMatches
                          .map((v) => ListTile(
                                dense: true,
                                title: Text(v.patientName),
                                subtitle: Text(v.patientFileNumber ?? ''),
                                onTap: () => setState(() => selectedVisit = v),
                              ))
                          .toList(),
                    ),
                  )
                else if (patientQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No match among today\'s visits', style: Theme.of(ctx).textTheme.bodySmall),
                  ),
              ],
            );
          } else if (selectedDrug == null) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedVisit!.patientName, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Select a drug from stock', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                drugStock.isEmpty
                    ? Text('No drugs in stock yet — receive stock first.', style: Theme.of(ctx).textTheme.bodySmall)
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView(
                          shrinkWrap: true,
                          children: drugStock
                              .map((d) => ListTile(
                                    dense: true,
                                    title: Text(d.drugName),
                                    subtitle: Text('${d.quantityOnHand} units on hand'),
                                    enabled: d.quantityOnHand > 0,
                                    onTap: d.quantityOnHand > 0 ? () => setState(() => selectedDrug = d) : null,
                                  ))
                              .toList(),
                        ),
                      ),
              ],
            );
          } else {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedVisit!.patientName, style: Theme.of(ctx).textTheme.titleMedium),
                Text(selectedDrug!.drugName, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtl,
                  decoration: const InputDecoration(labelText: 'Medication (dose & frequency)', isDense: true, hintText: 'e.g. Metformin 1000mg BD'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('New Prescription'),
            content: SizedBox(width: 420, child: content),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (selectedVisit != null && selectedDrug != null)
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (labelCtl.text.trim().isEmpty) return;
                          setState(() => submitting = true);
                          final provider = ctx.read<FacilityPatientProvider>();
                          final newId = await provider.placePrescription(
                            visitId: selectedVisit!.visitId,
                            drugStockId: selectedDrug!.id,
                            medicationLabel: labelCtl.text.trim(),
                          );
                          if (newId != null) await provider.loadPrescriptions(facilityId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(newId != null ? 'Prescription placed' : 'Failed: ${provider.error}')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Place Prescription'),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // Stock sub-tab
  // ---------------------------------------------------------------

  Widget _stockPanel(BuildContext context) {
    final admin = context.watch<AdminFacilityProvider>();
    final stock = admin.drugStock;

    return stock.isEmpty
        ? Center(child: Text('No drugs in stock yet', style: Theme.of(context).textTheme.bodySmall))
        : ListView.separated(
            itemCount: stock.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _stockRow(context, stock[i]),
          );
  }

  Widget _stockRow(BuildContext context, DrugStockModel d) {
    final status = d.stockLevelStatus;
    final color = _stockStatusColor[status] ?? AppColors.steel;
    final batchExpiry = [
      if (d.batchNumber != null && d.batchNumber!.isNotEmpty) 'Batch ${d.batchNumber}',
      if (d.expiryDate != null) 'Exp ${d.expiryDate!.month.toString().padLeft(2, '0')}/${d.expiryDate!.year}',
    ].join(' · ');

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
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.drugName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(batchExpiry.isEmpty ? 'No batch on file' : batchExpiry, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: d.stockLevelFraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text('${d.quantityOnHand} units', style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          _chip(context, _stockStatusLabel[status] ?? status, color),
        ],
      ),
    );
  }

  void _showReceiveStockDialog(BuildContext context) {
    final facilityId = widget.facility.id;
    final nameCtl = TextEditingController();
    final quantityCtl = TextEditingController();
    final batchCtl = TextEditingController();
    DateTime? expiryDate;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Receive Stock'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Drug Name', isDense: true, hintText: 'e.g. Amoxicillin 250mg'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity Received', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: batchCtl,
                  decoration: const InputDecoration(labelText: 'Batch Number (optional)', isDense: true),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expiryDate == null
                            ? 'No expiry date set'
                            : 'Expiry: ${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => expiryDate = picked);
                      },
                      child: const Text('Pick Expiry'),
                    ),
                  ],
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
                      final name = nameCtl.text.trim();
                      final quantity = int.tryParse(quantityCtl.text.trim());
                      if (name.isEmpty || quantity == null || quantity <= 0) return;
                      setState(() => submitting = true);
                      final admin = ctx.read<AdminFacilityProvider>();
                      final id = await admin.receiveStock(
                        facilityId: facilityId,
                        drugName: name,
                        quantity: quantity,
                        batchNumber: batchCtl.text.trim().isEmpty ? null : batchCtl.text.trim(),
                        expiryDate: expiryDate,
                      );
                      if (id != null) await admin.loadDrugStock(facilityId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(id != null ? 'Stock received' : 'Failed: ${admin.error}')),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Receive'),
            ),
          ],
        ),
      ),
    );
  }
}
