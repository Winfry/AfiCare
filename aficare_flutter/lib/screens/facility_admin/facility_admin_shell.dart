import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/department_model.dart';
import '../../models/facility_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/facility_admin_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/stat_card.dart';
import '../../utils/theme.dart';

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
    SidebarNavItem(icon: Icons.medical_services_outlined, label: 'Providers'),
    SidebarNavItem(icon: Icons.apartment_outlined, label: 'Departments'),
    SidebarNavItem(icon: Icons.calendar_month_outlined, label: 'Appointments'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Overview'),
    BottomNavItem(icon: Icons.medical_services_outlined, label: 'Providers'),
    BottomNavItem(icon: Icons.apartment_outlined, label: 'Departments'),
    BottomNavItem(icon: Icons.calendar_month_outlined, label: 'Appointments'),
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
      }
    });
  }

  void _onSelect(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) {
    final facilityAdmin = context.watch<FacilityAdminProvider>();
    final facility = facilityAdmin.myFacility;

    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _currentIndex,
      onSelect: _onSelect,
      onBottomNavSelect: _onSelect,
      searchHint: 'Search...',
      avatarLabel: 'FA',
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
                    _OverviewTab(facility: facility),
                    _ProvidersTab(facility: facility),
                    _DepartmentsTab(facility: facility),
                    const _AppointmentsTab(),
                  ],
                ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.facility});
  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facility.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(
            [facility.type, facility.county].where((s) => s != null && s.isNotEmpty).join(' - '),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, int>>(
            future: context.read<AdminFacilityProvider>().getFacilityStats(facility.id),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {'providers': 0, 'departments': 0};
              return Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Providers',
                      value: '${stats['providers']}',
                      icon: Icons.medical_services_outlined,
                      iconColor: AfiCareTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Departments',
                      value: '${stats['departments']}',
                      icon: Icons.apartment_outlined,
                      iconColor: AfiCareTheme.adminColor,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Address', facility.address ?? '-'),
                  _row('Phone', facility.phone ?? '-'),
                  _row('License', facility.licenseNo ?? '-'),
                  _row('Status', facility.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
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
              const Text('Providers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                ? const Center(child: Text('No providers linked yet', style: TextStyle(color: Colors.grey)))
                : ListView(
                    children: provider.facilityProviders
                        .map((p) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.medical_services_outlined),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Type a name to search verified providers', style: TextStyle(color: Colors.grey)),
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
              const Text('Departments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                ? const Center(child: Text('No departments yet', style: TextStyle(color: Colors.grey)))
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
  const _AppointmentsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFacilityProvider>();
    final appointments = provider.facilityAppointments;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Who is booked, when, and with which provider. Not the clinical reason for the visit.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: appointments.isEmpty
                ? const Center(child: Text('No appointments yet', style: TextStyle(color: Colors.grey)))
                : ListView(
                    children: appointments.map((a) => Card(
                      child: ListTile(
                        leading: Icon(
                          a['type'] == 'telehealth' ? Icons.videocam_outlined : Icons.person_outline,
                        ),
                        title: Text(a['patient_name'] as String? ?? 'Unknown'),
                        subtitle: Text(
                          '${_formatDateTime(a['scheduled_at'] as String?)} with ${a['provider_name'] ?? 'Unknown'}',
                        ),
                        trailing: _statusChip(a['status'] as String? ?? 'pending'),
                      ),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(String status) {
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
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
