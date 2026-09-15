import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/facility_model.dart';
import '../../models/facility_patient_model.dart';
import '../../models/queue_row_model.dart';
import '../../providers/facility_patient_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/register_patient_dialog.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

const _stageLabel = {
  'waiting': 'Waiting',
  'triage': 'Triage',
  'in_consultation': 'With Doctor',
  'completed': 'Completed',
};

const _nextStage = {
  'waiting': 'triage',
  'triage': 'in_consultation',
  'in_consultation': 'completed',
};

const _advanceLabel = {
  'waiting': 'Send to Triage',
  'triage': 'Send to Doctor',
  'in_consultation': 'Complete',
};

const _stageColor = {
  'waiting': AppColors.marigoldDark,
  'triage': AppColors.steel,
  'in_consultation': AppColors.adminColor,
  'completed': AppColors.primaryNavy,
};

const _priorityColor = {
  'routine': AppColors.sage,
  'priority': AppColors.marigoldDark,
  'urgent': AppColors.clay,
};

/// OPD Queue — step 2 of the facility-admin-as-HMS roadmap. A queue
/// "entry" is not its own record: it's a `visits` row (from the Patients
/// feature, step 1) whose status is waiting/triage/in_consultation. This
/// screen only tracks and advances that status -- see
/// 021_opd_queue.sql and FacilityPatientProvider.loadActiveVisits.
class OpdQueueTab extends StatefulWidget {
  const OpdQueueTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  State<OpdQueueTab> createState() => _OpdQueueTabState();
}

class _OpdQueueTabState extends State<OpdQueueTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Wait-time text ("34 min") has no data change to react to on its
    // own -- status_changed_at is static between actions -- so a
    // periodic rebuild is what keeps it live.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String _formatWait(DateTime statusChangedAt) {
    final d = DateTime.now().difference(statusChangedAt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityPatientProvider>();
    final visits = provider.activeVisits;

    final waiting = visits.where((v) => v.status == 'waiting').length;
    final triage = visits.where((v) => v.status == 'triage').length;
    final withDoctor = visits.where((v) => v.status == 'in_consultation').length;
    final completed = visits.where((v) => v.status == 'completed').length;

    final queueList = visits.where((v) => v.status != 'completed').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('OPD Queue', style: Theme.of(context).textTheme.headlineSmall)),
              ElevatedButton.icon(
                onPressed: () => _showAddToQueueDialog(context),
                icon: Icon(Icons.add, size: 18, color: AppColors.deepNavy),
                label: Text(
                  'Add to Queue',
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
              Expanded(child: _tallyCard(context, 'Waiting', waiting)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Triage', triage)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'With Doctor', withDoctor)),
              const SizedBox(width: 12),
              Expanded(child: _tallyCard(context, 'Completed', completed)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: provider.isLoading && visits.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : queueList.isEmpty
                    ? Center(child: Text('No one in the queue right now', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: queueList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _queueRow(context, queueList[i]),
                      ),
          ),
        ],
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

  Widget _queueRow(BuildContext context, QueueRowModel v) {
    final status = v.status;
    final priority = v.priority;
    final name = v.patientName;
    final fileNumber = v.patientFileNumber;
    final complaint = v.chiefComplaint;
    final statusChangedAt = v.statusChangedAt;
    final visitId = v.visitId;
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
              _initials(name),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tintNavyFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (fileNumber != null && fileNumber.isNotEmpty) fileNumber,
                    if (complaint != null && complaint.isNotEmpty) complaint,
                    '${_formatWait(statusChangedAt)} in stage',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _chip(context, _stageLabel[status] ?? status, _stageColor[status] ?? AppColors.steel),
          const SizedBox(width: 6),
          _chip(context, priority, _priorityColor[priority] ?? AppColors.steel),
          const SizedBox(width: 12),
          if (_nextStage.containsKey(status))
            ElevatedButton(
              onPressed: () async {
                final ok = await context.read<FacilityPatientProvider>().updateVisitStatus(
                      visitId: visitId,
                      newStatus: _nextStage[status]!,
                    );
                if (context.mounted) {
                  await context.read<FacilityPatientProvider>().loadActiveVisits(facilityId);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${context.read<FacilityPatientProvider>().error}')),
                    );
                  }
                }
              },
              child: Text(_advanceLabel[status] ?? 'Advance'),
            ),
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

  void _showAddToQueueDialog(BuildContext context) {
    final facilityId = widget.facility.id;
    final searchCtl = TextEditingController();
    final complaintCtl = TextEditingController();
    String? selectedPatientId;
    String? selectedPatientName;
    var priority = 'routine';
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final allPatients = ctx.watch<FacilityPatientProvider>().patients;
          final query = searchCtl.text.trim().toLowerCase();
          final matches = query.isEmpty
              ? const <FacilityPatientModel>[]
              : allPatients.where((p) => p.fullName.toLowerCase().contains(query)).take(6).toList();

          return AlertDialog(
            title: Text(selectedPatientId == null ? 'Add to Queue' : 'Queue Details'),
            content: SizedBox(
              width: 420,
              child: selectedPatientId == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: searchCtl,
                          decoration: const InputDecoration(labelText: 'Search existing patients by name', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        if (matches.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView(
                              shrinkWrap: true,
                              children: matches
                                  .map((p) => ListTile(
                                        dense: true,
                                        title: Text(p.fullName),
                                        onTap: () => setState(() {
                                          selectedPatientId = p.id;
                                          selectedPatientName = p.fullName;
                                        }),
                                      ))
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final newId = await showRegisterPatientDialog(ctx, facilityId: facilityId);
                            if (newId != null) {
                              setState(() {
                                selectedPatientId = newId;
                                selectedPatientName = 'New patient';
                              });
                            }
                          },
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Register New Walk-in'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedPatientName ?? '', style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: complaintCtl,
                          decoration: const InputDecoration(labelText: 'Chief Complaint', isDense: true),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: ['routine', 'priority', 'urgent'].map((p) {
                            final selected = priority == p;
                            return ChoiceChip(
                              label: Text(p[0].toUpperCase() + p.substring(1)),
                              selected: selected,
                              onSelected: (_) => setState(() => priority = p),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (selectedPatientId != null)
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setState(() => submitting = true);
                          final provider = ctx.read<FacilityPatientProvider>();
                          final ok = await provider.registerVisit(
                            facilityPatientId: selectedPatientId!,
                            chiefComplaint: complaintCtl.text.trim().isEmpty ? null : complaintCtl.text.trim(),
                            status: 'waiting',
                            priority: priority,
                          );
                          if (ok) await provider.loadActiveVisits(facilityId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Added to queue' : 'Failed: ${provider.error}')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add to Queue'),
                ),
            ],
          );
        },
      ),
    );
  }
}
