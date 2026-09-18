import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_log_entry_model.dart';
import '../../models/facility_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

// Humanized labels for the audit_log `action` strings this codebase's
// facility-admin RPCs actually write -- a different vocabulary than the
// platform-admin AuditLogProvider's own map (user_created, referral_*,
// etc.), which belongs to a different role/screen entirely.
const _actionLabel = {
  'facility_patient_registered': 'New patient registered',
  'visit_registered': 'Visit registered',
  'visit_status_updated': 'Visit status updated',
  'visit_clearance_updated': 'Billing clearance updated',
  'lab_order_placed': 'Lab order placed',
  'lab_order_status_updated': 'Lab order status updated',
  'drug_stock_received': 'Stock received',
  'prescription_placed': 'Prescription placed',
  'prescription_dispensed': 'Prescription dispensed',
  'ward_added': 'Ward added',
  'ward_updated': 'Ward updated',
  'patient_admitted': 'Patient admitted',
  'patient_discharged': 'Patient discharged',
  'department_added': 'Department added',
  'department_updated': 'Department updated',
  'facility_profile_updated': 'Facility profile updated',
};

const _actionIcon = {
  'facility_patient_registered': Icons.person_add_alt_outlined,
  'visit_registered': Icons.assignment_outlined,
  'visit_status_updated': Icons.checklist_outlined,
  'visit_clearance_updated': Icons.receipt_long_outlined,
  'lab_order_placed': Icons.biotech_outlined,
  'lab_order_status_updated': Icons.biotech_outlined,
  'drug_stock_received': Icons.inventory_2_outlined,
  'prescription_placed': Icons.medication_outlined,
  'prescription_dispensed': Icons.medication_outlined,
  'ward_added': Icons.local_hotel_outlined,
  'ward_updated': Icons.local_hotel_outlined,
  'patient_admitted': Icons.local_hotel_outlined,
  'patient_discharged': Icons.local_hotel_outlined,
  'department_added': Icons.apartment_outlined,
  'department_updated': Icons.apartment_outlined,
  'facility_profile_updated': Icons.edit_outlined,
};

/// Notifications — makes the previously-decorative AppShell bell real for
/// facility admins. Two sections: live Alerts (the exact same 4 checks
/// already computed on Overview's Alerts card, centralized here) and a
/// real Recent Activity feed built from the existing audit_log table
/// (027_facility_audit_notifications.sql). Deliberately shows only the
/// humanized action + whatever plain-text fields (name/new_status) each
/// action's own `details` JSON already happens to carry -- no per-entry
/// ID-to-name join queries; see the plan's stated v1 scope cut.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({
    super.key,
    required this.facility,
    required this.onGoToBilling,
    required this.onGoToLab,
    required this.onGoToPharmacy,
    required this.onGoToAdmissions,
  });

  final FacilityModel facility;
  final VoidCallback onGoToBilling;
  final VoidCallback onGoToLab;
  final VoidCallback onGoToPharmacy;
  final VoidCallback onGoToAdmissions;

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<FacilityPatientProvider>();
    final adminProvider = context.watch<AdminFacilityProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _alertsCard(context, patientProvider, adminProvider),
                  const SizedBox(height: 16),
                  _activityCard(context, adminProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
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
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          child,
        ],
      ),
    );
  }

  Widget _alertsCard(BuildContext context, FacilityPatientProvider patientProvider, AdminFacilityProvider adminProvider) {
    final pendingClearance = patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').length;
    final overdueLab = patientProvider.labOrders
        .where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2))
        .length;
    final lowStock = adminProvider.drugStock.where((d) => d.stockLevelStatus != 'ok').length;

    final occupiedByWard = <String, int>{};
    for (final a in patientProvider.admissions) {
      occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
    }
    final nearCapacity = adminProvider.wards
        .where((w) => w.totalBeds > 0 && (occupiedByWard[w.id] ?? 0) / w.totalBeds >= 0.9)
        .length;

    return _sectionCard(
      context,
      title: 'Alerts',
      child: Column(
        children: [
          _alertRow(
            context,
            icon: Icons.receipt_long_outlined,
            message: pendingClearance == 0 ? 'No visits pending clearance' : '$pendingClearance visits pending SHA/insurance clearance',
            active: pendingClearance > 0,
            onView: onGoToBilling,
          ),
          _alertRow(
            context,
            icon: Icons.biotech_outlined,
            message: overdueLab == 0 ? 'No lab orders overdue' : '$overdueLab lab orders overdue (>2h)',
            active: overdueLab > 0,
            onView: onGoToLab,
          ),
          _alertRow(
            context,
            icon: Icons.medication_outlined,
            message: lowStock == 0 ? 'No low stock items' : '$lowStock drugs low or out of stock',
            active: lowStock > 0,
            onView: onGoToPharmacy,
          ),
          _alertRow(
            context,
            icon: Icons.local_hotel_outlined,
            message: nearCapacity == 0 ? 'No wards at or near capacity' : '$nearCapacity wards at or near capacity',
            active: nearCapacity > 0,
            onView: onGoToAdmissions,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _alertRow(
    BuildContext context, {
    required IconData icon,
    required String message,
    required bool active,
    required VoidCallback onView,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            active ? icon : Icons.check_circle_outline,
            size: 18,
            color: active ? AppColors.clay : AppColors.sage,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
          GestureDetector(
            onTap: onView,
            child: Text('View →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(BuildContext context, AdminFacilityProvider adminProvider) {
    final entries = adminProvider.recentActivity;

    return _sectionCard(
      context,
      title: 'Recent Activity',
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No recent activity', style: Theme.of(context).textTheme.bodySmall),
            )
          : Column(
              children: entries.map((e) => _activityRow(context, e)).toList(),
            ),
    );
  }

  Widget _activityRow(BuildContext context, AuditLogEntryModel entry) {
    final label = _actionLabel[entry.action] ?? entry.action;
    final icon = _actionIcon[entry.action] ?? Icons.history;
    final extra = entry.details['name'] as String? ?? entry.details['new_status'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.steel),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                if (extra != null && extra.isNotEmpty)
                  Text(extra, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Text(_relativeTime(entry.timestamp), style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
