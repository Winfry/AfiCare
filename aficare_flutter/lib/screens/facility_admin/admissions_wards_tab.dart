import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admission_row_model.dart';
import '../../models/clearance_row_model.dart';
import '../../models/facility_model.dart';
import '../../models/ward_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

// Reused verbatim from billing_clearance_tab.dart's own local consts, per
// this codebase's established per-screen-const convention.
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

/// Admissions & Wards — final subsystem of the facility-admin-as-HMS
/// roadmap. Wards (facility-wide catalog, AdminFacilityProvider) and
/// current inpatients (visit-derived, FacilityPatientProvider) are
/// deliberately separate providers, combined only here in the screen --
/// same split as Pharmacy & Stock's Prescriptions/Stock panels. See
/// 026_admissions_wards.sql.
class AdmissionsWardsTab extends StatefulWidget {
  const AdmissionsWardsTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<AdmissionsWardsTab> createState() => _AdmissionsWardsTabState();
}

class _AdmissionsWardsTabState extends State<AdmissionsWardsTab> {
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Color _occupancyColor(int occupied, int total) {
    if (total <= 0) return AppColors.steel;
    final ratio = occupied / total;
    if (ratio >= 1.0) return AppColors.emergency;
    if (ratio >= 0.8) return AppColors.marigoldDark;
    return AppColors.sage;
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

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminFacilityProvider>();
    final patientProvider = context.watch<FacilityPatientProvider>();
    final wards = admin.wards;
    final admissions = patientProvider.admissions;

    final occupiedByWard = <String, int>{};
    for (final a in admissions) {
      occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
    }
    final totalBeds = wards.fold<int>(0, (sum, w) => sum + w.totalBeds);
    final totalOccupied = admissions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admissions & Wards', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      totalBeds == 0 ? 'No wards set up yet' : '$totalOccupied of $totalBeds beds occupied',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showWardDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ward'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: wards.isEmpty ? null : () => _showAdmitPatientDialog(context),
                icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                label: Text(
                  'Admit Patient',
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
          wards.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No wards yet — add one to begin admitting patients.', style: Theme.of(context).textTheme.bodySmall),
                )
              : SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wards.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _wardCard(context, wards[i], occupiedByWard[wards[i].id] ?? 0),
                  ),
                ),
          const SizedBox(height: 20),
          Text('Current Inpatients', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: patientProvider.isLoading && admissions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : admissions.isEmpty
                    ? Center(child: Text('No patients currently admitted', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: admissions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _admissionRow(context, admissions[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _wardCard(BuildContext context, WardModel ward, int occupied) {
    final color = _occupancyColor(occupied, ward.totalBeds);
    final fraction = ward.totalBeds <= 0 ? 0.0 : (occupied / ward.totalBeds).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showWardDialog(context, ward: ward),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: _cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ward.name, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Occupied $occupied/${ward.totalBeds}', style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _admissionRow(BuildContext context, AdmissionRowModel a) {
    final eligibility = a.eligibilityStatus ?? 'pending';
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
              _initials(a.patientName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tintNavyFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.patientName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${a.wardName} — Bed ${a.bedNumber} · Attending ${a.attendingProviderName ?? 'Unassigned'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Admitted ${a.admittedAt.year}-${a.admittedAt.month.toString().padLeft(2, '0')}-${a.admittedAt.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _chip(context, _eligibilityLabel[eligibility] ?? eligibility, _eligibilityColor[eligibility] ?? AppColors.steel),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _dischargePatient(context, a),
            child: const Text('Discharge'),
          ),
        ],
      ),
    );
  }

  Future<void> _dischargePatient(BuildContext context, AdmissionRowModel a) async {
    final facilityId = widget.facility.id;
    final provider = context.read<FacilityPatientProvider>();
    final ok = await provider.dischargePatient(a.admissionId);
    if (ok) await provider.loadAdmissions(facilityId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Patient discharged' : 'Failed: ${provider.error}')),
      );
    }
  }

  void _showWardDialog(BuildContext context, {WardModel? ward}) {
    final facilityId = widget.facility.id;
    final nameCtl = TextEditingController(text: ward?.name ?? '');
    final bedsCtl = TextEditingController(text: ward?.totalBeds.toString() ?? '');
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ward == null ? 'Add Ward' : 'Edit Ward'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Ward Name', isDense: true, hintText: 'e.g. Ward A — Maternity'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bedsCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Beds', isDense: true),
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
                      final beds = int.tryParse(bedsCtl.text.trim());
                      if (name.isEmpty || beds == null || beds <= 0) return;
                      setState(() => submitting = true);
                      final admin = ctx.read<AdminFacilityProvider>();
                      final ok = ward == null
                          ? await admin.addWard(facilityId: facilityId, name: name, totalBeds: beds)
                          : await admin.updateWard(wardId: ward.id, name: name, totalBeds: beds);
                      if (ok) await admin.loadWards(facilityId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? (ward == null ? 'Ward added' : 'Ward updated') : 'Failed: ${admin.error}')),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ward == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdmitPatientDialog(BuildContext context) {
    final facilityId = widget.facility.id;
    final patientSearchCtl = TextEditingController();
    final bedCtl = TextEditingController();
    ClearanceRowModel? selectedVisit;
    WardModel? selectedWard;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final todaysVisits = ctx.watch<FacilityPatientProvider>().clearanceVisits;
          final wards = ctx.watch<AdminFacilityProvider>().wards;
          final admissions = ctx.watch<FacilityPatientProvider>().admissions;
          final occupiedByWard = <String, int>{};
          for (final a in admissions) {
            occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
          }
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
          } else if (selectedWard == null) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedVisit!.patientName, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Select a ward', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: wards.map((w) {
                      final occupied = occupiedByWard[w.id] ?? 0;
                      final full = occupied >= w.totalBeds;
                      return ListTile(
                        dense: true,
                        title: Text(w.name),
                        subtitle: Text('$occupied/${w.totalBeds} beds occupied${full ? ' — full' : ''}'),
                        enabled: !full,
                        onTap: full ? null : () => setState(() => selectedWard = w),
                      );
                    }).toList(),
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
                Text(selectedWard!.name, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  controller: bedCtl,
                  decoration: const InputDecoration(labelText: 'Bed Number', isDense: true, hintText: 'e.g. Bed 4'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Admit Patient'),
            content: SizedBox(width: 420, child: content),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (selectedVisit != null && selectedWard != null)
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (bedCtl.text.trim().isEmpty) return;
                          setState(() => submitting = true);
                          final provider = ctx.read<FacilityPatientProvider>();
                          final newId = await provider.admitPatient(
                            visitId: selectedVisit!.visitId,
                            wardId: selectedWard!.id,
                            bedNumber: bedCtl.text.trim(),
                          );
                          if (newId != null) await provider.loadAdmissions(facilityId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(newId != null ? 'Patient admitted' : 'Failed: ${provider.error}')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Admit'),
                ),
            ],
          );
        },
      ),
    );
  }
}
