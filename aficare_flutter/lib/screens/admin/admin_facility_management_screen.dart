import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_facility_provider.dart';
import '../../models/facility_model.dart';
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
                flex: 1.5,
                child: Text(facility.licenseNo ?? '-', style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                flex: 1,
                child: _facilityStatusChip(facility.status),
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

  void _showFacilityDetail(BuildContext context, AdminFacilityProvider provider, FacilityModel facility) {
    provider.loadDepartments(facility.id);
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
        builder: (ctx, scrollController) => SingleChildScrollView(
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
            ],
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