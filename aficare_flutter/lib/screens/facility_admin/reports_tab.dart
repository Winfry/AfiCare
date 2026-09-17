import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/facility_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/csv_export/csv_export.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

enum _ReportPeriod { week, month, quarter }

/// Reports — final subsystem of the facility-admin-as-HMS roadmap.
/// Recaps every prior subsystem (Patient Flow, Billing & Clearance,
/// Laboratory, Pharmacy & Stock, Admissions & Wards) as counts/trends/
/// breakdowns over a selected period. Deliberately introduces no new
/// operational concept and no new SQL: every read here already has an
/// RLS SELECT policy in place, so this is a pure aggregation screen over
/// FacilityPatientProvider's new `report*` fields (period-bounded,
/// separate from the live "today only"/"current only" boards) plus
/// AdminFacilityProvider's already-loaded wards/drugStock catalogs.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  _ReportPeriod _period = _ReportPeriod.month;

  DateTime get _periodStart {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.week:
        final startOfToday = DateTime(now.year, now.month, now.day);
        return startOfToday.subtract(Duration(days: now.weekday - 1));
      case _ReportPeriod.month:
        return DateTime(now.year, now.month, 1);
      case _ReportPeriod.quarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterStartMonth, 1);
    }
  }

  void _onPeriodChanged(_ReportPeriod? value) {
    if (value == null) return;
    setState(() => _period = value);
    context.read<FacilityPatientProvider>().loadReportsData(widget.facility.id, _periodStart);
  }

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<FacilityPatientProvider>();
    final adminProvider = context.watch<AdminFacilityProvider>();
    final loading = patientProvider.isLoading &&
        patientProvider.reportVisits.isEmpty &&
        patientProvider.reportPatients.isEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Reports', style: Theme.of(context).textTheme.headlineSmall)),
              DropdownButton<_ReportPeriod>(
                value: _period,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: _ReportPeriod.week, child: Text('This Week')),
                  DropdownMenuItem(value: _ReportPeriod.month, child: Text('This Month')),
                  DropdownMenuItem(value: _ReportPeriod.quarter, child: Text('This Quarter')),
                ],
                onChanged: _onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _patientFlowSection(context, patientProvider),
                        const SizedBox(height: 16),
                        _billingSection(context, patientProvider),
                        const SizedBox(height: 16),
                        _laboratorySection(context, patientProvider),
                        const SizedBox(height: 16),
                        _pharmacySection(context, patientProvider, adminProvider),
                        const SizedBox(height: 16),
                        _admissionsSection(context, patientProvider, adminProvider),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------

  Widget _patientFlowSection(BuildContext context, FacilityPatientProvider provider) {
    final visits = provider.reportVisits;
    final patients = provider.reportPatients;
    final completed = visits.where((v) => v.status == 'completed').length;
    final cancelled = visits.where((v) => v.status == 'cancelled').length;
    final routine = visits.where((v) => v.priority == 'routine').length;
    final priority = visits.where((v) => v.priority == 'priority').length;
    final urgent = visits.where((v) => v.priority == 'urgent').length;

    return _sectionCard(
      context,
      title: 'Patient Flow',
      onExport: () => _exportDailyCsv(context, 'patient_flow', visits.map((v) => v.occurredAt).toList()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard(context, 'New Patients', '${patients.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Total Visits', '${visits.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Completed', '$completed')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Cancelled', '$cancelled')),
              ],
            ),
            const SizedBox(height: 16),
            _trendChart(visits.map((v) => v.occurredAt).toList(), AppColors.adminColor),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Routine: $routine', AppColors.steel),
                _chip(context, 'Priority: $priority', AppColors.marigoldDark),
                _chip(context, 'Urgent: $urgent', AppColors.emergency),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _billingSection(BuildContext context, FacilityPatientProvider provider) {
    final visits = provider.reportVisits;
    final pending = visits.where((v) => v.eligibilityStatus == 'pending').length;
    final verified = visits.where((v) => v.eligibilityStatus == 'verified').length;
    final rejected = visits.where((v) => v.eligibilityStatus == 'rejected').length;
    final sha = visits.where((v) => v.payerType == 'sha').length;
    final insurance = visits.where((v) => v.payerType == 'insurance').length;
    final cash = visits.where((v) => v.payerType == 'cash').length;
    final notSet = visits.where((v) => v.payerType == null).length;

    return _sectionCard(
      context,
      title: 'Billing & Clearance',
      onExport: () => _exportBreakdownCsv(context, 'billing_clearance', {
        'Pending': pending,
        'Verified': verified,
        'Rejected': rejected,
        'SHA': sha,
        'Insurance': insurance,
        'Cash': cash,
        'Not set': notSet,
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard(context, 'Pending', '$pending')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Verified', '$verified')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Rejected', '$rejected')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'SHA: $sha', AppColors.adminColor),
                _chip(context, 'Insurance: $insurance', AppColors.steel),
                _chip(context, 'Cash: $cash', AppColors.sage),
                if (notSet > 0) _chip(context, 'Not set: $notSet', AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _laboratorySection(BuildContext context, FacilityPatientProvider provider) {
    final orders = provider.reportLabOrders;
    // "Currently overdue" is inherently a live, not-period-bound concept
    // (same >2h pending/processing formula as the live Laboratory tab),
    // so it reads the live `labOrders` field, not the period-scoped one.
    final liveOrders = provider.labOrders;
    final completed = orders.where((o) => o.status == 'completed').length;
    final overdue = liveOrders
        .where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2))
        .length;
    final completedOrders = orders.where((o) => o.status == 'completed').toList();
    final avgTurnaroundHours = completedOrders.isEmpty
        ? 0.0
        : completedOrders.map((o) => o.statusChangedAt.difference(o.orderedAt).inMinutes).reduce((a, b) => a + b) /
            completedOrders.length /
            60.0;

    return _sectionCard(
      context,
      title: 'Laboratory',
      onExport: () => _exportDailyCsv(context, 'laboratory', orders.map((o) => o.orderedAt).toList()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard(context, 'Orders Placed', '${orders.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Completed', '$completed')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Overdue Now', '$overdue')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Avg Turnaround', '${avgTurnaroundHours.toStringAsFixed(1)}h')),
              ],
            ),
            const SizedBox(height: 16),
            _trendChart(orders.map((o) => o.orderedAt).toList(), AppColors.marigoldDark),
          ],
        ),
      ),
    );
  }

  Widget _pharmacySection(BuildContext context, FacilityPatientProvider provider, AdminFacilityProvider admin) {
    final rx = provider.reportPrescriptions;
    final dispensed = rx.where((r) => r.status == 'dispensed').length;
    final pending = rx.where((r) => r.status == 'pending').length;

    final countByDrug = <String, int>{};
    for (final r in rx) {
      countByDrug[r.drugStockId] = (countByDrug[r.drugStockId] ?? 0) + 1;
    }
    final nameById = {for (final d in admin.drugStock) d.id: d.drugName};
    final topDrugs = countByDrug.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topDrugs.take(5).toList();

    final lowStock = admin.drugStock.where((d) => d.stockLevelStatus != 'ok').length;
    final now = DateTime.now();
    final expiringSoon = admin.drugStock
        .where((d) => d.expiryDate != null && d.expiryDate!.isAfter(now) && d.expiryDate!.difference(now).inDays <= 30)
        .length;

    return _sectionCard(
      context,
      title: 'Pharmacy & Stock',
      onExport: () => _exportDailyCsv(context, 'pharmacy', rx.map((r) => r.prescribedAt).toList()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard(context, 'Prescriptions', '${rx.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Dispensed', '$dispensed')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Pending', '$pending')),
              ],
            ),
            const SizedBox(height: 16),
            _trendChart(rx.map((r) => r.prescribedAt).toList(), AppColors.sage),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Prescribed Drugs', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (top5.isEmpty)
                        Text('No prescriptions this period', style: Theme.of(context).textTheme.bodySmall)
                      else
                        ...top5.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(nameById[e.key] ?? 'Unknown', style: Theme.of(context).textTheme.bodySmall),
                                  ),
                                  Text('${e.value}', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock Alerts (current)', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _chip(context, 'Low/Reorder: $lowStock', lowStock > 0 ? AppColors.emergency : AppColors.sage),
                      const SizedBox(height: 6),
                      _chip(context, 'Expiring soon: $expiringSoon', expiringSoon > 0 ? AppColors.marigoldDark : AppColors.sage),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _admissionsSection(BuildContext context, FacilityPatientProvider provider, AdminFacilityProvider admin) {
    final admissions = provider.reportAdmissions;
    final discharged = admissions.where((a) => a.isDischarged).toList();
    final avgLos = discharged.isEmpty
        ? 0.0
        : discharged.map((a) => a.dischargedAt!.difference(a.admittedAt).inHours).reduce((a, b) => a + b) /
            discharged.length /
            24.0;

    // Ward occupancy is a live, not-period-bound snapshot -- reuses the
    // already-loaded current-only `admissions` field and `wards` catalog,
    // exactly as computed in admissions_wards_tab.dart.
    final currentAdmissions = provider.admissions;
    final wards = admin.wards;
    final occupiedByWard = <String, int>{};
    for (final a in currentAdmissions) {
      occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
    }

    return _sectionCard(
      context,
      title: 'Admissions & Wards',
      onExport: () => _exportDailyCsv(context, 'admissions', admissions.map((a) => a.admittedAt).toList()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard(context, 'Admissions', '${admissions.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Discharges', '${discharged.length}')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(context, 'Avg Length of Stay', '${avgLos.toStringAsFixed(1)}d')),
              ],
            ),
            const SizedBox(height: 16),
            _trendChart(admissions.map((a) => a.admittedAt).toList(), AppColors.clay),
            const SizedBox(height: 16),
            Text('Ward Occupancy (current)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (wards.isEmpty)
              Text('No wards set up yet', style: Theme.of(context).textTheme.bodySmall)
            else
              ...wards.map((w) {
                final occ = occupiedByWard[w.id] ?? 0;
                final fraction = w.totalBeds <= 0 ? 0.0 : (occ / w.totalBeds).clamp(0.0, 1.0);
                final color = fraction >= 1.0
                    ? AppColors.emergency
                    : fraction >= 0.8
                        ? AppColors.marigoldDark
                        : AppColors.sage;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(w.name, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        child: Stack(
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
                      ),
                      const SizedBox(width: 8),
                      Text('$occ/${w.totalBeds}', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------

  Widget _sectionCard(BuildContext context, {required String title, required Widget child, VoidCallback? onExport}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (onExport != null)
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 20),
                    tooltip: 'Export CSV',
                    onPressed: onExport,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          child,
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.mistBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
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

  /// Buckets [timestamps] into one count per calendar day from the
  /// current period start through today, and renders it as a single
  /// fl_chart line -- the real charting library already used elsewhere
  /// in the app (patient vitals trends), not the platform-admin Reports
  /// screen's custom-painter approach.
  Widget _trendChart(List<DateTime> timestamps, Color color) {
    final start = DateTime(_periodStart.year, _periodStart.month, _periodStart.day);
    final end = DateTime.now();
    final totalDays = end.difference(start).inDays + 1;
    final counts = List<int>.filled(totalDays, 0);
    for (final t in timestamps) {
      final day = DateTime(t.year, t.month, t.day);
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < totalDays) counts[idx]++;
    }
    final spots = [for (var i = 0; i < totalDays; i++) FlSpot(i.toDouble(), counts[i].toDouble())];
    final labelSkip = (totalDays / 6).ceil().clamp(1, totalDays);

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 9)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= totalDays || i % labelSkip != 0) return const Text('');
                  final d = start.add(Duration(days: i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2, dotData: const FlDotData(show: false)),
          ],
          minY: 0,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // CSV export
  // ---------------------------------------------------------------

  String get _periodFileTag {
    final d = DateTime.now();
    return '${_period.name}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  String _isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _exportDailyCsv(BuildContext context, String sectionKey, List<DateTime> timestamps) async {
    final start = DateTime(_periodStart.year, _periodStart.month, _periodStart.day);
    final end = DateTime.now();
    final totalDays = end.difference(start).inDays + 1;
    final counts = List<int>.filled(totalDays, 0);
    for (final t in timestamps) {
      final day = DateTime(t.year, t.month, t.day);
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < totalDays) counts[idx]++;
    }
    final rows = <List<dynamic>>[
      ['Date', 'Count'],
      for (var i = 0; i < totalDays; i++) [_isoDate(start.add(Duration(days: i))), counts[i]],
    ];
    await _writeCsv(context, '${sectionKey}_$_periodFileTag.csv', rows);
  }

  Future<void> _exportBreakdownCsv(BuildContext context, String sectionKey, Map<String, int> breakdown) async {
    final rows = <List<dynamic>>[
      ['Category', 'Count'],
      for (final e in breakdown.entries) [e.key, e.value],
    ];
    await _writeCsv(context, '${sectionKey}_$_periodFileTag.csv', rows);
  }

  Future<void> _writeCsv(BuildContext context, String filename, List<List<dynamic>> rows) async {
    final csvContent = const ListToCsvConverter().convert(rows);
    await exportCsv(filename, csvContent);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported')));
    }
  }
}
