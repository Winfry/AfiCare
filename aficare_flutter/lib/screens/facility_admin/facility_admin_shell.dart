import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/department_model.dart';
import '../../models/facility_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/facility_admin_provider.dart';
import '../../providers/facility_patient_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/provider_avatar.dart';
import '../../theme/app_colors.dart';
import 'admissions_wards_tab.dart';
import 'billing_clearance_tab.dart';
import 'laboratory_tab.dart';
import 'notifications_tab.dart';
import 'opd_queue_tab.dart';
import 'patients_tab.dart';
import 'pharmacy_stock_tab.dart';
import 'reports_tab.dart';
import 'settings_tab.dart';
import 'verification_tab.dart';

/// Shell for a facility admin — front-desk/office staff scoped to one
/// hospital. Deliberately small: mirrors CHWShell's minimal
/// AppShell + IndexedStack pattern rather than the bigger AdminDashboard,
/// since a facility admin's whole job is roster + departments for one
/// facility, nothing platform-wide.
class FacilityAdminShell extends StatefulWidget {
  const FacilityAdminShell({super.key});

  @override
  State<FacilityAdminShell> createState() => _FacilityAdminShellState();
}

class _FacilityAdminShellState extends State<FacilityAdminShell> {
  int _currentIndex = 0;

  static const _sidebarEntries = [
    SidebarGroupLabel('My Facility'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Overview'),
    SidebarNavItem(icon: Icons.people_outline, label: 'Patients'),
    SidebarNavItem(icon: Icons.checklist_outlined, label: 'OPD Queue'),
    SidebarNavItem(icon: Icons.receipt_long_outlined, label: 'Billing & Clearance'),
    SidebarNavItem(icon: Icons.medical_services_outlined, label: 'Providers'),
    SidebarNavItem(icon: Icons.apartment_outlined, label: 'Departments'),
    SidebarNavItem(icon: Icons.calendar_month_outlined, label: 'Appointments'),
    SidebarNavItem(icon: Icons.biotech_outlined, label: 'Laboratory'),
    SidebarNavItem(icon: Icons.medication_outlined, label: 'Pharmacy & Stock'),
    SidebarNavItem(icon: Icons.local_hotel_outlined, label: 'Admissions & Wards'),
    SidebarNavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
    SidebarNavItem(icon: Icons.notifications_outlined, label: 'Notifications'),
    SidebarNavItem(icon: Icons.settings_outlined, label: 'Settings'),
    SidebarNavItem(icon: Icons.verified_outlined, label: 'Verification'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Overview'),
    BottomNavItem(icon: Icons.people_outline, label: 'Patients'),
    BottomNavItem(icon: Icons.checklist_outlined, label: 'OPD Queue'),
    BottomNavItem(icon: Icons.receipt_long_outlined, label: 'Billing & Clearance'),
    BottomNavItem(icon: Icons.medical_services_outlined, label: 'Providers'),
    BottomNavItem(icon: Icons.apartment_outlined, label: 'Departments'),
    BottomNavItem(icon: Icons.calendar_month_outlined, label: 'Appointments'),
    BottomNavItem(icon: Icons.biotech_outlined, label: 'Laboratory'),
    BottomNavItem(icon: Icons.medication_outlined, label: 'Pharmacy & Stock'),
    BottomNavItem(icon: Icons.local_hotel_outlined, label: 'Admissions & Wards'),
    BottomNavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
    BottomNavItem(icon: Icons.notifications_outlined, label: 'Notifications'),
    BottomNavItem(icon: Icons.settings_outlined, label: 'Settings'),
    BottomNavItem(icon: Icons.verified_outlined, label: 'Verification'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final facilityAdmin = context.read<FacilityAdminProvider>();
      await facilityAdmin.loadMyFacility();
      final facility = facilityAdmin.myFacility;
      if (facility != null && mounted) {
        final admin = context.read<AdminFacilityProvider>();
        admin.loadFacilityProviders(facility.id);
        admin.loadDepartments(facility.id);
        admin.loadFacilityAppointments(facility.id);
        final patientProvider = context.read<FacilityPatientProvider>();
        patientProvider.loadFacilityPatients(facility.id);
        patientProvider.loadActiveVisits(facility.id);
        patientProvider.loadClearanceVisits(facility.id);
        patientProvider.loadLabOrders(facility.id);
        admin.loadDrugStock(facility.id);
        patientProvider.loadPrescriptions(facility.id);
        admin.loadWards(facility.id);
        patientProvider.loadAdmissions(facility.id);
        final now = DateTime.now();
        patientProvider.loadReportsData(facility.id, DateTime(now.year, now.month, 1));
        admin.loadRecentActivity(facility.id);
        admin.loadFacilityAdmins(facility.id);
      }
    });
  }

  void _onSelect(int i) => setState(() => _currentIndex = i);

  void _goToPatients({String? searchTerm}) {
    setState(() => _currentIndex = 1);
    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      final facility = context.read<FacilityAdminProvider>().myFacility;
      if (facility != null) {
        context.read<FacilityPatientProvider>().loadFacilityPatients(facility.id, searchTerm: searchTerm);
      }
    }
  }

  void _goToQueue() => setState(() => _currentIndex = 2);

  void _goToBilling() => setState(() => _currentIndex = 3);

  void _goToLab() => setState(() => _currentIndex = 7);

  void _goToPharmacy() => setState(() => _currentIndex = 8);

  void _goToAdmissions() => setState(() => _currentIndex = 9);

  void _goToNotifications() => setState(() => _currentIndex = 11);

  /// The top bar's search chip had no handler wired at all (AppShell's
  /// `onSearch` was never passed for this shell) -- tapping it did
  /// nothing. This reuses the exact same navigation Overview's own
  /// inline patient search already does, rather than building a whole
  /// new search surface.
  void _openSearchDialog() {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Patients'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name, ID, or file no.'),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            _goToPatients(searchTerm: v);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goToPatients(searchTerm: ctl.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilityAdmin = context.watch<FacilityAdminProvider>();
    final facility = facilityAdmin.myFacility;

    final patientProvider = context.watch<FacilityPatientProvider>();
    final adminProvider = context.watch<AdminFacilityProvider>();
    final occupiedByWard = <String, int>{};
    for (final a in patientProvider.admissions) {
      occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
    }
    final hasActiveAlerts = patientProvider.clearanceVisits.any((v) => v.eligibilityStatus == 'pending') ||
        patientProvider.labOrders.any((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2)) ||
        adminProvider.drugStock.any((d) => d.stockLevelStatus != 'ok') ||
        adminProvider.wards.any((w) => w.totalBeds > 0 && (occupiedByWard[w.id] ?? 0) / w.totalBeds >= 0.9);

    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _currentIndex,
      onSelect: _onSelect,
      onBottomNavSelect: _onSelect,
      searchHint: 'Search patients...',
      avatarLabel: 'FA',
      showNotificationDot: hasActiveAlerts,
      onNotificationTap: _goToNotifications,
      onSearch: _openSearchDialog,
      onLogout: () async {
        await context.read<AuthProvider>().signOut();
        if (context.mounted) context.go('/login');
      },
      body: facilityAdmin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : facility == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You are not yet assigned to a facility. Contact your platform admin.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : IndexedStack(
                  index: _currentIndex,
                  children: [
                    _OverviewTab(
                      facility: facility,
                      onGoToPatients: _goToPatients,
                      onGoToQueue: _goToQueue,
                      onGoToBilling: _goToBilling,
                      onGoToLab: _goToLab,
                      onGoToPharmacy: _goToPharmacy,
                      onGoToAdmissions: _goToAdmissions,
                    ),
                    PatientsTab(facility: facility),
                    OpdQueueTab(facility: facility),
                    BillingClearanceTab(facility: facility),
                    _ProvidersTab(facility: facility),
                    _DepartmentsTab(facility: facility),
                    _AppointmentsTab(facility: facility),
                    LaboratoryTab(facility: facility),
                    PharmacyStockTab(facility: facility),
                    AdmissionsWardsTab(facility: facility),
                    ReportsTab(facility: facility),
                    NotificationsTab(
                      facility: facility,
                      onGoToBilling: _goToBilling,
                      onGoToLab: _goToLab,
                      onGoToPharmacy: _goToPharmacy,
                      onGoToAdmissions: _goToAdmissions,
                    ),
                    SettingsTab(facility: facility),
                    const VerificationTab(),
                  ],
                ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.facility,
    required this.onGoToPatients,
    required this.onGoToQueue,
    required this.onGoToBilling,
    required this.onGoToLab,
    required this.onGoToPharmacy,
    required this.onGoToAdmissions,
  });
  final FacilityModel facility;
  final void Function({String? searchTerm}) onGoToPatients;
  final VoidCallback onGoToQueue;
  final VoidCallback onGoToBilling;
  final VoidCallback onGoToLab;
  final VoidCallback onGoToPharmacy;
  final VoidCallback onGoToAdmissions;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<FacilityPatientProvider>();
    final adminProvider = context.watch<AdminFacilityProvider>();
    final authProvider = context.watch<AuthProvider>();
    final firstName = authProvider.currentUser?.fullName.split(' ').first ?? 'there';
    final now = DateTime.now();
    final registeredToday = patientProvider.patients
        .where((p) => p.createdAt.year == now.year && p.createdAt.month == now.month && p.createdAt.day == now.day)
        .length;
    final searchCtl = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()}, $firstName', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('${_formattedDate()} · ${facility.name}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchCtl,
                  decoration: InputDecoration(
                    hintText: 'Search patient, ID, or file no.',
                    isDense: true,
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      tooltip: 'Search',
                      onPressed: () => onGoToPatients(searchTerm: searchCtl.text),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                  onSubmitted: (v) => onGoToPatients(searchTerm: v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => onGoToPatients(),
                icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                label: Text(
                  'New Patient',
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
          // KPI row -- 5 cards, unchanged since Wards/Admissions landed:
          // the row has no responsive wrap, so bed occupancy surfaces in
          // the Alerts card's 4th row (wards at/near capacity) instead of
          // a 6th KPI card.
          FutureBuilder<Map<String, int>>(
            future: context.read<AdminFacilityProvider>().getFacilityStats(facility.id),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {'providers': 0, 'departments': 0};
              final queueActive = patientProvider.activeVisits.where((v) => v.status != 'completed').length;
              final pendingClearance = patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').length;
              final pendingLab = patientProvider.labOrders.where((o) => o.status != 'completed').length;
              final overdueLab = patientProvider.labOrders
                  .where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2))
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _kpiCard(
                      context,
                      label: 'Patients Today',
                      value: '$registeredToday',
                      delta: 'of ${patientProvider.patients.length} total records',
                      deltaColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _kpiCard(
                      context,
                      label: 'OPD Queue Active',
                      value: '$queueActive',
                      delta: 'waiting, triage or with doctor',
                      deltaColor: AppColors.marigoldDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _kpiCard(
                      context,
                      label: 'Pending Clearance',
                      value: '$pendingClearance',
                      delta: pendingClearance > 0 ? 'SHA / insurance verification' : 'All clear',
                      deltaColor: pendingClearance > 0 ? AppColors.clay : AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _kpiCard(
                      context,
                      label: 'Pending Lab Results',
                      value: '$pendingLab',
                      delta: overdueLab > 0 ? '$overdueLab overdue' : 'On track',
                      deltaColor: overdueLab > 0 ? AppColors.emergency : AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _kpiCard(
                      context,
                      label: 'Providers',
                      value: '${stats['providers']}',
                      delta: '${stats['departments']} departments',
                      deltaColor: AppColors.adminColor,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _overviewCard(
                    context,
                    title: 'OPD Queue — Live',
                    action: GestureDetector(
                      onTap: onGoToQueue,
                      child: Text('View full queue →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                    ),
                    child: () {
                      final queueRows = patientProvider.activeVisits.where((v) => v.status != 'completed').take(3).toList();
                      if (queueRows.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No one in the queue right now', style: Theme.of(context).textTheme.bodySmall),
                        );
                      }
                      return Column(
                        children: queueRows.map((v) {
                          final stageColor = switch (v.status) {
                            'waiting' => AppColors.marigoldDark,
                            'triage' => AppColors.steel,
                            'in_consultation' => AppColors.adminColor,
                            _ => AppColors.steel,
                          };
                          final stageLabel = switch (v.status) {
                            'waiting' => 'Waiting',
                            'triage' => 'Triage',
                            'in_consultation' => 'With Doctor',
                            _ => v.status,
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(v.patientName, style: Theme.of(context).textTheme.titleSmall),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: stageColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    stageLabel,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: stageColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _overviewCard(
                    context,
                    title: 'Alerts',
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.receipt_long_outlined,
                                size: 18,
                                color: patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').isEmpty ? AppColors.sage : AppColors.clay,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').isEmpty
                                      ? 'No visits pending clearance'
                                      : '${patientProvider.clearanceVisits.where((v) => v.eligibilityStatus == 'pending').length} visits pending SHA/insurance clearance',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              GestureDetector(
                                onTap: onGoToBilling,
                                child: Text('View →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                patientProvider.labOrders.where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2)).isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.biotech_outlined,
                                size: 18,
                                color: patientProvider.labOrders.where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2)).isEmpty
                                    ? AppColors.sage
                                    : AppColors.clay,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Builder(builder: (context) {
                                  final overdueLabCount = patientProvider.labOrders
                                      .where((o) => o.status != 'completed' && DateTime.now().difference(o.orderedAt) > const Duration(hours: 2))
                                      .length;
                                  return Text(
                                    overdueLabCount == 0 ? 'No lab orders overdue' : '$overdueLabCount lab orders overdue (>2h)',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  );
                                }),
                              ),
                              GestureDetector(
                                onTap: onGoToLab,
                                child: Text('View →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                adminProvider.drugStock.where((d) => d.quantityOnHand <= d.reorderThreshold).isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.medication_outlined,
                                size: 18,
                                color: adminProvider.drugStock.where((d) => d.quantityOnHand <= d.reorderThreshold).isEmpty ? AppColors.sage : AppColors.clay,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Builder(builder: (context) {
                                  final lowStockCount = adminProvider.drugStock.where((d) => d.quantityOnHand <= d.reorderThreshold).length;
                                  return Text(
                                    lowStockCount == 0 ? 'No low stock items' : '$lowStockCount drugs low or out of stock',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  );
                                }),
                              ),
                              GestureDetector(
                                onTap: onGoToPharmacy,
                                child: Text('View →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Builder(builder: (context) {
                            final occupiedByWard = <String, int>{};
                            for (final a in patientProvider.admissions) {
                              occupiedByWard[a.wardId] = (occupiedByWard[a.wardId] ?? 0) + 1;
                            }
                            final nearCapacityCount = adminProvider.wards
                                .where((w) => w.totalBeds > 0 && (occupiedByWard[w.id] ?? 0) / w.totalBeds >= 0.9)
                                .length;
                            return Row(
                              children: [
                                Icon(
                                  nearCapacityCount == 0 ? Icons.check_circle_outline : Icons.local_hotel_outlined,
                                  size: 18,
                                  color: nearCapacityCount == 0 ? AppColors.sage : AppColors.clay,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    nearCapacityCount == 0 ? 'No wards at or near capacity' : '$nearCapacityCount wards at or near capacity',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: onGoToAdmissions,
                                  child: Text('View →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _overviewCard(
            context,
            title: 'Facility Details',
            action: OutlinedButton.icon(
              onPressed: () => _showEditFacilityForm(context, facility),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, 'Address', facility.address ?? '-'),
                  _row(context, 'Phone', facility.phone ?? '-'),
                  _row(context, 'License', facility.licenseNo ?? '-'),
                  _row(context, 'Status', facility.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _cardShadow = [
    BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
  ];

  Widget _kpiCard(BuildContext context, {required String label, required String value, String? delta, Color? deltaColor}) {
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
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              delta,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: deltaColor, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _overviewCard(BuildContext context, {required String title, required Widget child, Widget? action}) {
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
                if (action != null) action,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          child,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );

  void _showEditFacilityForm(BuildContext context, FacilityModel facility) {
    final nameCtl = TextEditingController(text: facility.name);
    final countyCtl = TextEditingController(text: facility.county ?? '');
    final subCountyCtl = TextEditingController(text: facility.subCounty ?? '');
    final addressCtl = TextEditingController(text: facility.address ?? '');
    final phoneCtl = TextEditingController(text: facility.phone ?? '');
    final emailCtl = TextEditingController(text: facility.email ?? '');
    final licenseCtl = TextEditingController(text: facility.licenseNo ?? '');
    var selectedType = facility.type;
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Facility Profile'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Facility Name', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Facility Type', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                      DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                      DropdownMenuItem(value: 'lab', child: Text('Lab')),
                      DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
                    ],
                    onChanged: (v) => setState(() => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: countyCtl,
                    decoration: const InputDecoration(labelText: 'County', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCountyCtl,
                    decoration: const InputDecoration(labelText: 'Sub-County', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtl,
                    decoration: const InputDecoration(labelText: 'Physical Address', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtl,
                    decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtl,
                    decoration: const InputDecoration(labelText: 'Email', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: licenseCtl,
                    decoration: const InputDecoration(labelText: 'License Number', isDense: true),
                  ),
                ],
              ),
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
                      if (nameCtl.text.trim().isEmpty) return;
                      setState(() => submitting = true);
                      final provider = context.read<FacilityAdminProvider>();
                      final ok = await provider.updateMyFacility(
                        name: nameCtl.text.trim(),
                        type: selectedType,
                        county: countyCtl.text.trim(),
                        subCounty: subCountyCtl.text.trim(),
                        address: addressCtl.text.trim(),
                        phone: phoneCtl.text.trim(),
                        email: emailCtl.text.trim(),
                        licenseNo: licenseCtl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Facility profile updated' : 'Failed: ${provider.error}')),
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
        ),
      ),
    );
  }
}

class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({required this.facility});
  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFacilityProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Providers', style: Theme.of(context).textTheme.headlineSmall),
              ElevatedButton.icon(
                onPressed: () => _showAddProviderDialog(context, provider),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add Provider'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: provider.facilityProviders.isEmpty
                ? Center(child: Text('No providers linked yet', style: Theme.of(context).textTheme.bodySmall))
                : ListView(
                    children: provider.facilityProviders
                        .map((p) => Card(
                              child: ListTile(
                                leading: ProviderAvatarSmall(
                                  name: p.providerName ?? 'Unknown',
                                  gender: p.providerGender,
                                  photoUrl: p.providerPhotoUrl,
                                  radius: 18,
                                ),
                                title: Text(p.providerName ?? 'Unknown'),
                                subtitle: Text([
                                  if (p.specialty != null && p.specialty!.isNotEmpty) p.specialty!,
                                  if (p.isPrimary) 'Primary facility',
                                ].join(' - ')),
                                trailing: IconButton(
                                  icon: const Icon(Icons.link_off, size: 20),
                                  tooltip: 'Remove from facility',
                                  onPressed: () async {
                                    final ok = await provider.unlinkProviderFromFacility(p.providerId, facility.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(ok ? 'Provider removed' : 'Failed: ${provider.error}')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddProviderDialog(BuildContext context, AdminFacilityProvider provider) {
    final searchCtl = TextEditingController();
    provider.searchVerifiedProviders('');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Provider'),
        content: SizedBox(
          width: 400,
          child: Consumer<AdminFacilityProvider>(
            builder: (ctx, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: searchCtl,
                  decoration: const InputDecoration(labelText: 'Search verified providers by name', isDense: true),
                  onChanged: (v) => p.searchVerifiedProviders(v),
                ),
                const SizedBox(height: 12),
                if (p.providerSearchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Type a name to search verified providers', style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: p.providerSearchResults.map((u) => ListTile(
                        dense: true,
                        title: Text(u['full_name'] as String? ?? ''),
                        subtitle: Text((u['specialty'] as String?) ?? (u['email'] as String?) ?? ''),
                        onTap: () async {
                          final ok = await p.linkProviderToFacility(
                            u['id'] as String,
                            facility.id,
                            specialty: u['specialty'] as String?,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Provider linked' : 'Failed: ${p.error}')),
                            );
                          }
                        },
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _DepartmentsTab extends StatelessWidget {
  const _DepartmentsTab({required this.facility});
  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFacilityProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Departments', style: Theme.of(context).textTheme.headlineSmall),
              ElevatedButton.icon(
                onPressed: () => _showDepartmentForm(context, provider),
                icon: const Icon(Icons.add),
                label: const Text('Add Department'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: provider.departments.isEmpty
                ? Center(child: Text('No departments yet', style: Theme.of(context).textTheme.bodySmall))
                : ListView(
                    children: provider.departments
                        .map((d) => Card(
                              child: ListTile(
                                title: Text(d.name),
                                subtitle: d.description != null && d.description!.isNotEmpty ? Text(d.description!) : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showDepartmentForm(context, provider, department: d),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDepartmentForm(BuildContext context, AdminFacilityProvider provider, {DepartmentModel? department}) {
    final nameCtl = TextEditingController(text: department?.name ?? '');
    final descCtl = TextEditingController(text: department?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(department == null ? 'Add Department' : 'Edit Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Department Name', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.trim().isEmpty) return;
              final ok = department == null
                  ? await provider.addDepartment({
                      'facility_id': facility.id,
                      'name': nameCtl.text.trim(),
                      'description': descCtl.text.trim(),
                    })
                  : await provider.updateDepartment(department.id, facility.id, nameCtl.text.trim(), descCtl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Saved' : 'Failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({required this.facility});
  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFacilityProvider>();
    final appointments = provider.facilityAppointments;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appointments', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Who is booked, when, and with which provider. Not the clinical reason for the visit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: appointments.isEmpty
                ? Center(child: Text('No appointments yet', style: Theme.of(context).textTheme.bodySmall))
                : ListView(
                    children: appointments.map((a) => Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: Icon(
                                a['type'] == 'telehealth' ? Icons.videocam_outlined : Icons.person_outline,
                              ),
                              title: Text(a['patient_name'] as String? ?? 'Unknown'),
                              subtitle: Text(
                                '${_formatDateTime(a['scheduled_at'] as String?)} with ${a['provider_name'] ?? 'Unknown'}',
                              ),
                              trailing: _statusChip(context, a['status'] as String? ?? 'pending'),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                              child: _actionsFor(context, a),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionsFor(BuildContext context, Map<String, dynamic> a) {
    final id = a['id'] as String;
    final status = a['status'] as String? ?? 'pending';

    Future<void> refresh() =>
        context.read<AdminFacilityProvider>().loadFacilityAppointments(facility.id);

    final buttons = <Widget>[];

    if (status == 'pending') {
      buttons.add(TextButton(
        onPressed: () async {
          final aptProvider = context.read<AppointmentProvider>();
          final ok = await aptProvider.confirmAppointment(id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? 'Confirmed' : 'Failed: ${aptProvider.error}')),
            );
          }
          if (ok) await refresh();
        },
        child: const Text('Confirm'),
      ));
    }

    if (status == 'pending' || status == 'confirmed') {
      buttons.add(TextButton(
        onPressed: () => _showRescheduleDialog(context, id, refresh),
        child: const Text('Reschedule'),
      ));
      buttons.add(TextButton(
        onPressed: () => _showCancelDialog(context, id, refresh),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Cancel'),
      ));
    }

    return buttons.isEmpty ? const SizedBox.shrink() : Wrap(spacing: 4, children: buttons);
  }

  Future<void> _showRescheduleDialog(
      BuildContext context, String id, Future<void> Function() onDone) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !context.mounted) return;

    final newDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final aptProvider = context.read<AppointmentProvider>();
    final ok = await aptProvider.rescheduleAppointment(id, newDt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Rescheduled' : 'Failed: ${aptProvider.error}')),
      );
    }
    if (ok) await onDone();
  }

  Future<void> _showCancelDialog(
      BuildContext context, String id, Future<void> Function() onDone) async {
    final reasonCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: TextField(
          controller: reasonCtl,
          decoration: const InputDecoration(labelText: 'Reason (optional)', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel appointment')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final aptProvider = context.read<AppointmentProvider>();
    final reason = reasonCtl.text.trim();
    final ok = await aptProvider.cancelAppointment(id, reason: reason.isEmpty ? null : reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Cancelled' : 'Failed: ${aptProvider.error}')),
      );
    }
    if (ok) await onDone();
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(BuildContext context, String status) {
    final color = switch (status) {
      'confirmed' => const Color(0xFF43A047),
      'completed' => const Color(0xFF1D3557),
      'cancelled' => const Color(0xFFE53935),
      _ => const Color(0xFFFB8C00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
