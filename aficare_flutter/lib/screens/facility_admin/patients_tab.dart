import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/facility_model.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/register_patient_dialog.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

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
                onPressed: () async {
                  final newId = await showRegisterPatientDialog(context, facilityId: widget.facility.id);
                  if (newId != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Patient registered')),
                    );
                    _selectPatient(newId);
                  }
                },
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
                      boxShadow: _cardShadow,
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
                      : _PatientDetail(
                          key: ValueKey(_selectedPatientId),
                          facilityPatientId: _selectedPatientId!,
                          initials: _initials,
                          facilityId: widget.facility.id,
                        ),
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

}

const _payerLabel = {
  'sha': 'SHA',
  'insurance': 'Insurance',
  'cash': 'Cash',
};

const _payerColor = {
  'sha': AppColors.adminColor,
  'insurance': AppColors.primaryNavy,
  'cash': AppColors.steel,
};

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

enum _DetailTab { overview, appointments, billing }

class _PatientDetail extends StatefulWidget {
  const _PatientDetail({super.key, required this.facilityPatientId, required this.initials, required this.facilityId});
  final String facilityPatientId;
  final String Function(String) initials;
  final String facilityId;

  @override
  State<_PatientDetail> createState() => _PatientDetailState();
}

class _PatientDetailState extends State<_PatientDetail> {
  _DetailTab _tab = _DetailTab.overview;
  bool _appointmentsLoaded = false;

  void _selectTab(_DetailTab tab) {
    setState(() => _tab = tab);
    if (tab == _DetailTab.appointments && !_appointmentsLoaded) {
      _appointmentsLoaded = true;
      final provider = context.read<FacilityPatientProvider>();
      provider.loadPatientAppointments(widget.facilityId, provider.selectedPatient?.linkedUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final patient = provider.selectedPatient;

    if (patient == null || patient.id != widget.facilityPatientId) {
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
              boxShadow: _cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.tintNavyBg,
                  child: Text(
                    widget.initials(patient.fullName),
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
              boxShadow: _cardShadow,
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
          const SizedBox(height: 20),
          Row(
            children: [
              _tabButton(context, 'Overview', _DetailTab.overview),
              const SizedBox(width: 8),
              _tabButton(context, 'Appointments', _DetailTab.appointments),
              const SizedBox(width: 8),
              _tabButton(context, 'Billing & Clearance', _DetailTab.billing),
            ],
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            _DetailTab.overview => _overviewPanel(context, provider),
            _DetailTab.appointments => _appointmentsPanel(context, provider),
            _DetailTab.billing => _billingPanel(context, provider),
          },
        ],
      ),
    );
  }

  Widget _tabButton(BuildContext context, String label, _DetailTab value) {
    final selected = _tab == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _selectTab(value),
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

  Widget _overviewPanel(BuildContext context, FacilityPatientProvider provider) {
    final visits = provider.selectedPatientVisits;
    final latest = visits.isNotEmpty ? visits.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _vitalBox(
                context,
                'Blood pressure',
                latest == null || latest.bpSystolic == null || latest.bpDiastolic == null
                    ? '—'
                    : '${latest.bpSystolic}/${latest.bpDiastolic}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vitalBox(context, 'Weight', latest?.weightKg == null ? '—' : '${latest!.weightKg} kg'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vitalBox(context, 'Temp', latest?.temperatureC == null ? '—' : '${latest!.temperatureC}°C'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vitalBox(context, 'Last visit', latest == null ? '—' : _formatDate(latest.occurredAt)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Visits', style: Theme.of(context).textTheme.titleLarge),
            OutlinedButton.icon(
              onPressed: () => _showRegisterVisitDialog(context, widget.facilityPatientId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register Visit'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        visits.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No visits recorded yet', style: Theme.of(context).textTheme.bodySmall),
              )
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: _cardShadow,
                ),
                child: Column(
                  children: visits.asMap().entries.map((entry) {
                    final isLast = entry.key == visits.length - 1;
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
        const SizedBox(height: 10),
        Text(
          'Full clinical detail (diagnosis, prescriptions, lab orders) lives in the provider\'s EMR view, not here.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _vitalBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _appointmentsPanel(BuildContext context, FacilityPatientProvider provider) {
    final linkedUserId = provider.selectedPatient?.linkedUserId;
    final appointments = provider.selectedPatientAppointments;

    if (linkedUserId == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No linked AfiCare account — appointments booked through the app aren\'t available for this patient yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    if (appointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('No appointments booked yet.', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: appointments.asMap().entries.map((entry) {
          final isLast = entry.key == appointments.length - 1;
          final a = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(a.scheduledAt), style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text('with ${a.providerName}', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                _appointmentStatusChip(context, a.status),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _appointmentStatusChip(BuildContext context, String status) {
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
        status.isEmpty ? status : status[0].toUpperCase() + status.substring(1),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _billingPanel(BuildContext context, FacilityPatientProvider provider) {
    final visits = provider.selectedPatientVisits;

    if (visits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('No visits recorded yet', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: visits.asMap().entries.map((entry) {
          final isLast = entry.key == visits.length - 1;
          final v = entry.value;
          final payer = v.payerType;
          final eligibility = v.eligibilityStatus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
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
                _chip(context, payer != null ? _payerLabel[payer] ?? payer : 'No payer', payer != null ? _payerColor[payer] ?? AppColors.steel : AppColors.steel),
                const SizedBox(width: 6),
                _chip(context, _eligibilityLabel[eligibility] ?? eligibility, _eligibilityColor[eligibility] ?? AppColors.steel),
              ],
            ),
          );
        }).toList(),
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

  String _formatDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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
    final systolicCtl = TextEditingController();
    final diastolicCtl = TextEditingController();
    final weightCtl = TextEditingController();
    final tempCtl = TextEditingController();
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Register Visit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Text('Vitals (optional)', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: systolicCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'BP Systolic', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: diastolicCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'BP Diastolic', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: tempCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Temp (°C)', isDense: true),
                      ),
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
                      setState(() => submitting = true);
                      final provider = context.read<FacilityPatientProvider>();
                      final ok = await provider.registerVisit(
                        facilityPatientId: facilityPatientId,
                        chiefComplaint: complaintCtl.text.trim().isEmpty ? null : complaintCtl.text.trim(),
                        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
                        bpSystolic: int.tryParse(systolicCtl.text.trim()),
                        bpDiastolic: int.tryParse(diastolicCtl.text.trim()),
                        weightKg: double.tryParse(weightCtl.text.trim()),
                        temperatureC: double.tryParse(tempCtl.text.trim()),
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
