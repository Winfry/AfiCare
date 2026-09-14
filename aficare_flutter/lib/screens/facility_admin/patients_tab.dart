import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/facility_model.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';

/// Facility-local patient register + visit history — step 1 of the
/// facility-admin-as-HMS roadmap (OPD Queue and Billing/Clearance build on
/// the same `visits` table next). Master-detail layout: a search + list on
/// the left, the selected patient's details and recent visits on the
/// right. A separate file (not another inline tab in facility_admin_shell)
/// since this is realistically as big as the whole Appointments tab, and
/// this is the natural seam for OPD Queue to reuse later.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

enum _PatientFilter { all, today, recent }

class _PatientsTabState extends State<PatientsTab> {
  String? _selectedPatientId;
  _PatientFilter _filter = _PatientFilter.all;
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _selectPatient(String id) {
    setState(() => _selectedPatientId = id);
    context.read<FacilityPatientProvider>().loadPatientDetail(id);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final now = DateTime.now();
    final registeredToday = provider.patients.where((p) {
      return p.createdAt.year == now.year && p.createdAt.month == now.month && p.createdAt.day == now.day;
    }).length;

    final visiblePatients = switch (_filter) {
      _PatientFilter.all => provider.patients,
      _PatientFilter.today => provider.patients.where((p) {
          return p.createdAt.year == now.year && p.createdAt.month == now.month && p.createdAt.day == now.day;
        }).toList(),
      _PatientFilter.recent => provider.patients.where((p) => now.difference(p.createdAt).inDays <= 7).toList(),
    };

    return Padding(
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
                    Text('Patients', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${provider.patients.length} record${provider.patients.length == 1 ? '' : 's'}'
                      '${registeredToday > 0 ? ' · $registeredToday registered today' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID or phone',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
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
                  onChanged: (v) => context.read<FacilityPatientProvider>().loadFacilityPatients(widget.facility.id, searchTerm: v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showRegisterPatientDialog(context),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _filterChip(context, 'All Patients', _PatientFilter.all),
              const SizedBox(width: 8),
              _filterChip(context, "Today's Patients", _PatientFilter.today),
              const SizedBox(width: 8),
              _filterChip(context, 'Recent Patients', _PatientFilter.recent),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Text('All patients', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Divider(height: 1, color: AppColors.borderSubtle),
                        Expanded(
                          child: provider.isLoading && provider.patients.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : visiblePatients.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        provider.patients.isEmpty ? 'No patients registered yet' : 'No patients in this filter',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: visiblePatients.length,
                                      itemBuilder: (context, i) {
                                        final p = visiblePatients[i];
                                        final selected = p.id == _selectedPatientId;
                                        return Material(
                                          color: selected ? AppColors.tintNavyBg : Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _selectPatient(p.id),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: AppColors.tintNavyBg,
                                                    child: Text(
                                                      _initials(p.fullName),
                                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppColors.tintNavyFg,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(p.fullName, style: Theme.of(context).textTheme.titleSmall),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          [
                                                            if (p.fileNumber != null && p.fileNumber!.isNotEmpty) p.fileNumber!,
                                                            if (p.age != null)
                                                              '${p.age}${p.gender != null ? ' · ${p.gender![0].toUpperCase()}' : ''}',
                                                          ].join(' · '),
                                                          style: Theme.of(context).textTheme.labelSmall,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _selectedPatientId == null
                      ? Center(child: Text('Select a patient', style: Theme.of(context).textTheme.bodyMedium))
                      : _PatientDetail(facilityPatientId: _selectedPatientId!, initials: _initials),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, _PatientFilter value) {
    final selected = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = value),
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

  void _showRegisterPatientDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final fileNumberCtl = TextEditingController();
    final allergiesCtl = TextEditingController();
    DateTime? dob;
    String? gender;
    var shaStatus = 'unknown';
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Register Patient'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime(2000),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => dob = picked);
                          },
                          child: Text(dob == null
                              ? 'Date of Birth'
                              : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: gender,
                          isDense: true,
                          decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => gender = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtl,
                    decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fileNumberCtl,
                    decoration: const InputDecoration(labelText: 'File / OP Number', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: shaStatus,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'SHA Status', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                      DropdownMenuItem(value: 'not_registered', child: Text('Not Registered')),
                      DropdownMenuItem(value: 'registered', child: Text('Registered')),
                    ],
                    onChanged: (v) => setState(() => shaStatus = v ?? shaStatus),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: allergiesCtl,
                    decoration: const InputDecoration(labelText: 'Allergies (comma-separated)', isDense: true),
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
                      final provider = context.read<FacilityPatientProvider>();
                      final newId = await provider.registerPatient(
                        facilityId: widget.facility.id,
                        fullName: nameCtl.text.trim(),
                        dateOfBirth: dob,
                        gender: gender,
                        phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
                        fileNumber: fileNumberCtl.text.trim().isEmpty ? null : fileNumberCtl.text.trim(),
                        shaStatus: shaStatus,
                        allergies: allergiesCtl.text
                            .split(',')
                            .map((a) => a.trim())
                            .where((a) => a.isNotEmpty)
                            .toList(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(newId != null ? 'Patient registered' : 'Failed: ${provider.error}')),
                        );
                        if (newId != null) _selectPatient(newId);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientDetail extends StatelessWidget {
  const _PatientDetail({required this.facilityPatientId, required this.initials});
  final String facilityPatientId;
  final String Function(String) initials;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final patient = provider.selectedPatient;

    if (patient == null || patient.id != facilityPatientId) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.tintNavyBg,
                  child: Text(
                    initials(patient.fullName),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tintNavyFg,
                        ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (patient.fileNumber != null && patient.fileNumber!.isNotEmpty) 'File: ${patient.fileNumber}',
                          if (patient.age != null) '${patient.age} yrs',
                          if (patient.gender != null) patient.gender!,
                          'SHA: ${patient.shaStatus.replaceAll('_', ' ')}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (patient.allergies.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: patient.allergies
                              .map((a) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.clayBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      a,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.clay,
                                          ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(context, Icons.phone_outlined, 'Phone', patient.phone ?? '-'),
                if (patient.linkedUserId != null) _infoRow(context, Icons.link, 'Linked account', 'AfiCare user'),
                if (patient.linkedDependentId != null) _infoRow(context, Icons.link, 'Linked account', 'Dependent profile'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Visits', style: Theme.of(context).textTheme.titleLarge),
              OutlinedButton.icon(
                onPressed: () => _showRegisterVisitDialog(context, facilityPatientId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Register Visit'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          provider.selectedPatientVisits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No visits recorded yet', style: Theme.of(context).textTheme.bodySmall),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: provider.selectedPatientVisits.asMap().entries.map((entry) {
                      final isLast = entry.key == provider.selectedPatientVisits.length - 1;
                      final v = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.primaryNavy, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.chiefComplaint?.isNotEmpty == true ? v.chiefComplaint! : 'Visit',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_formatDateTime(v.occurredAt), style: Theme.of(context).textTheme.labelSmall),
                                ],
                              ),
                            ),
                            _statusChip(context, v.status),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _statusChip(BuildContext context, String status) {
    final color = switch (status) {
      'waiting' => AppColors.marigoldDark,
      'in_consultation' => AppColors.adminColor,
      'completed' => AppColors.primaryNavy,
      'cancelled' => AppColors.clay,
      _ => AppColors.steel,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showRegisterVisitDialog(BuildContext context, String facilityPatientId) {
    final complaintCtl = TextEditingController();
    final notesCtl = TextEditingController();
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Register Visit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: complaintCtl,
                decoration: const InputDecoration(labelText: 'Chief Complaint', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtl,
                decoration: const InputDecoration(labelText: 'Notes', isDense: true),
                maxLines: 2,
              ),
            ],
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
                      final provider = context.read<FacilityPatientProvider>();
                      final ok = await provider.registerVisit(
                        facilityPatientId: facilityPatientId,
                        chiefComplaint: complaintCtl.text.trim().isEmpty ? null : complaintCtl.text.trim(),
                        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Visit registered' : 'Failed: ${provider.error}')),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
