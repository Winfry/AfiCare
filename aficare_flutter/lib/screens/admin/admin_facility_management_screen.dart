import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_facility_provider.dart';
import '../../models/facility_model.dart';
import '../../models/provider_facility_model.dart';
import '../../utils/theme.dart';

class AdminFacilityManagementScreen extends StatefulWidget {
  const AdminFacilityManagementScreen({super.key});

  @override
  State<AdminFacilityManagementScreen> createState() => _AdminFacilityManagementScreenState();
}

class _AdminFacilityManagementScreenState extends State<AdminFacilityManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminFacilityProvider>().loadFacilities();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFacilityProvider>();
    final filtered = provider.filteredFacilities;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Management'),
        backgroundColor: AfiCareTheme.adminColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Add Facility',
            onPressed: () => _showFacilityForm(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadFacilities(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search facilities...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) => provider.setSearchQuery(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTypeFilter(provider),
                    ],
                  );
                }
                return Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => provider.setSearchQuery(v),
                    ),
                    const SizedBox(height: 8),
                    _buildTypeFilter(provider),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
                    : filtered.isEmpty
                        ? const Center(child: Text('No facilities found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => isWide
                                ? _buildWideCard(ctx, filtered[i], provider)
                                : _buildNarrowCard(ctx, filtered[i], provider),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter(AdminFacilityProvider provider) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: provider.typeFilter,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Type', isDense: true),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Types')),
          DropdownMenuItem(value: 'hospital', child: Text('Hospitals')),
          DropdownMenuItem(value: 'clinic', child: Text('Clinics')),
          DropdownMenuItem(value: 'lab', child: Text('Labs')),
          DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacies')),
        ],
        onChanged: (v) => provider.setTypeFilter(v ?? 'all'),
      ),
    );
  }

  Widget _buildWideCard(BuildContext context, FacilityModel facility, AdminFacilityProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFacilityDetail(context, provider, facility),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _facilityIcon(facility.type),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facility.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${facility.type[0].toUpperCase()}${facility.type.substring(1)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (facility.county != null) Text(facility.county!, style: const TextStyle(fontSize: 13)),
                    if (facility.phone != null) Text(facility.phone!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(facility.licenseNo ?? '-', style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                flex: 1,
                child: _facilityStatusChip(facility.status),
              ),
              if (facility.status == 'pending')
                TextButton.icon(
                  onPressed: () => _verifyFacility(context, provider, facility),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Verify'),
                ),
              PopupMenuButton(
                onSelected: (v) {
                  switch (v) {
                    case 'edit': _showFacilityForm(context, provider, facility: facility);
                    case 'delete': _confirmDelete(context, provider, facility);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowCard(BuildContext context, FacilityModel facility, AdminFacilityProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFacilityDetail(context, provider, facility),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _facilityIcon(facility.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(facility.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${facility.type[0].toUpperCase()}${facility.type.substring(1)} · ${facility.county ?? ''}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _facilityStatusChip(facility.status),
                ],
              ),
              if (facility.phone != null) ...[
                const SizedBox(height: 4),
                Text('📞 ${facility.phone}', style: const TextStyle(fontSize: 12)),
              ],
              if (facility.status == 'pending') ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _verifyFacility(context, provider, facility),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Verify'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _facilityIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'hospital': icon = Icons.local_hospital; color = Colors.red; break;
      case 'clinic': icon = Icons.medical_services; color = Colors.blue; break;
      case 'lab': icon = Icons.science; color = Colors.purple; break;
      case 'pharmacy': icon = Icons.medication; color = Colors.green; break;
      default: icon = Icons.business; color = Colors.grey;
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color),
    );
  }

  Widget _facilityStatusChip(String status) {
    final s = status == 'verified'
        ? const Color(0xFF43A047)
        : status == 'pending'
            ? const Color(0xFFFB8C00)
            : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 12, color: s, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _verifyFacility(BuildContext context, AdminFacilityProvider provider, FacilityModel facility) async {
    final ok = await provider.updateFacility(facility.id, {'status': 'verified'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '${facility.name} marked verified' : 'Failed: ${provider.error}')),
      );
    }
  }

  void _showFacilityDetail(BuildContext context, AdminFacilityProvider provider, FacilityModel facility) {
    provider.loadDepartments(facility.id);
    provider.loadFacilityProviders(facility.id);
    provider.loadFacilityAdmins(facility.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Consumer<AdminFacilityProvider>(
          builder: (ctx, provider, _) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _facilityIcon(facility.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(facility.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(facility.type, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _detailRow('Address', facility.address ?? '-'),
                _detailRow('County', facility.county ?? '-'),
                _detailRow('Phone', facility.phone ?? '-'),
                _detailRow('Email', facility.email ?? '-'),
                _detailRow('License', facility.licenseNo ?? '-'),
                _detailRow('Status', facility.status),
                if (facility.status == 'pending')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _verifyFacility(context, provider, facility),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Verified'),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Departments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (provider.departments.isEmpty)
                  const Text('No departments yet', style: TextStyle(color: Colors.grey))
                else
                  ...provider.departments.map((d) => ListTile(
                    dense: true,
                    title: Text(d.name),
                    subtitle: d.headProviderId != null ? Text('Head: ${d.headProviderId}') : null,
                  )),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddDepartmentDialog(context, provider, facility.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Department'),
                ),
                const SizedBox(height: 16),
                const Text('Providers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (provider.facilityProviders.isEmpty)
                  const Text('No providers linked yet', style: TextStyle(color: Colors.grey))
                else
                  ...provider.facilityProviders.map((p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.medical_services_outlined),
                    title: Text(p.providerName ?? 'Unknown'),
                    subtitle: Text([
                      if (p.specialty != null && p.specialty!.isNotEmpty) p.specialty!,
                      if (p.isPrimary) 'Primary facility',
                    ].join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, size: 20),
                      tooltip: 'Remove from facility',
                      onPressed: () => _confirmUnlinkProvider(context, provider, p, facility.name),
                    ),
                  )),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddProviderDialog(context, provider, facility.id),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add Provider'),
                ),
                const SizedBox(height: 16),
                const Text('Facility Admins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Front-desk/office staff who manage this facility\'s roster. Not a clinician.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                if (provider.facilityAdmins.isEmpty)
                  const Text('No facility admins yet', style: TextStyle(color: Colors.grey))
                else
                  ...provider.facilityAdmins.map((a) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(a['full_name'] as String? ?? 'Unknown'),
                    subtitle: Text(a['email'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, size: 20),
                      tooltip: 'Revoke facility admin access',
                      onPressed: () => _confirmRevokeFacilityAdmin(context, provider, a, facility),
                    ),
                  )),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddFacilityAdminDialog(context, provider, facility.id),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Facility Admin'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
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

  void _showFacilityForm(BuildContext context, AdminFacilityProvider provider, {FacilityModel? facility}) {
    final nameCtl = TextEditingController(text: facility?.name ?? '');
    final typeCtl = TextEditingController(text: facility?.type ?? 'clinic');
    final countyCtl = TextEditingController(text: facility?.county ?? '');
    final phoneCtl = TextEditingController(text: facility?.phone ?? '');
    final emailCtl = TextEditingController(text: facility?.email ?? '');
    final licenseCtl = TextEditingController(text: facility?.licenseNo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(facility == null ? 'Add Facility' : 'Edit Facility'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: typeCtl.text,
                decoration: const InputDecoration(labelText: 'Type', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                  DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                  DropdownMenuItem(value: 'lab', child: Text('Lab')),
                  DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
                ],
                onChanged: (v) => typeCtl.text = v ?? 'clinic',
              ),
              const SizedBox(height: 8),
              TextField(controller: countyCtl, decoration: const InputDecoration(labelText: 'County', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: licenseCtl, decoration: const InputDecoration(labelText: 'License #', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameCtl.text,
                'type': typeCtl.text,
                'county': countyCtl.text,
                'phone': phoneCtl.text,
                'email': emailCtl.text,
                'license_no': licenseCtl.text,
              };
              bool ok;
              if (facility == null) {
                ok = await provider.addFacility(data);
              } else {
                ok = await provider.updateFacility(facility.id, data);
              }
              if (ok && context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog(BuildContext context, AdminFacilityProvider provider, String facilityId) {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Department'),
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
              if (nameCtl.text.isEmpty) return;
              await provider.addDepartment({
                'facility_id': facilityId,
                'name': nameCtl.text,
                'description': descCtl.text,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddProviderDialog(BuildContext context, AdminFacilityProvider provider, String facilityId) {
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
                            facilityId,
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

  void _showAddFacilityAdminDialog(BuildContext context, AdminFacilityProvider provider, String facilityId) {
    final searchCtl = TextEditingController();
    provider.searchPatientsForFacilityAdmin('');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Facility Admin'),
        content: SizedBox(
          width: 400,
          child: Consumer<AdminFacilityProvider>(
            builder: (ctx, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB8C00).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'This changes the account\'s role. Only pick someone who registered '
                    'specifically to manage this facility\'s front desk -- never a real '
                    'patient using AfiCare for their own healthcare. They will lose patient '
                    'access once granted.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A5300)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtl,
                  decoration: const InputDecoration(labelText: 'Search unassigned accounts by name', isDense: true),
                  onChanged: (v) => p.searchPatientsForFacilityAdmin(v),
                ),
                const SizedBox(height: 12),
                if (p.patientSearchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Type a name to search', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: p.patientSearchResults.map((u) => ListTile(
                        dense: true,
                        title: Text(u['full_name'] as String? ?? ''),
                        subtitle: Text(u['email'] as String? ?? ''),
                        onTap: () async {
                          final ok = await p.grantFacilityAdmin(u['id'] as String, facilityId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Facility admin granted' : 'Failed: ${p.error}')),
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

  void _confirmRevokeFacilityAdmin(
    BuildContext context,
    AdminFacilityProvider provider,
    Map<String, dynamic> admin,
    FacilityModel facility,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke facility admin access'),
        content: Text('Revoke ${admin['full_name'] ?? 'this person'}\'s admin access to ${facility.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await provider.revokeFacilityAdmin(admin['user_id'] as String, facility.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Access revoked' : 'Failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  void _confirmUnlinkProvider(
    BuildContext context,
    AdminFacilityProvider provider,
    ProviderFacilityModel link,
    String facilityName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove provider'),
        content: Text('Remove ${link.providerName ?? 'this provider'} from $facilityName\'s staff list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await provider.unlinkProviderFromFacility(link.providerId, link.facilityId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Provider removed' : 'Failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminFacilityProvider provider, FacilityModel facility) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Facility'),
        content: Text('Delete ${facility.name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteFacility(facility.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}