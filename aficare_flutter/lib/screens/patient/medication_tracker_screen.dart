import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../theme/patient_tokens.dart';
import 'adherence_log_screen.dart';
import 'widgets/patient_ui.dart';

/// Medications — what you take, when you take it, and what needs
/// attention. Rendered inside the patient shell, so it carries no app
/// bar of its own.
class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  State<MedicationTrackerScreen> createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  bool _isLoading = true;
  int _tab = 0; // 0 = Active, 1 = Past

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _patientId {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    return dep.activePatientId ?? auth.currentUser?.id ?? '';
  }

  Future<void> _load() async {
    if (!mounted) return;
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    final id = _patientId;
    if (id.isNotEmpty) {
      await ad.ensureTodayDoses(id);
      await ad.loadToday(id);
      await ad.loadHistory(id, days: 7);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _mark(AdherenceLogModel dose, AdherenceStatus status) async {
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    await ad.markStatus(dose.id, status);
    if (mounted) {
      pToast(context, status == AdherenceStatus.taken ? 'Dose marked as taken' : 'Dose skipped');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PScreenHead(
            eyebrow: 'Clinical',
            title: 'Medications',
            subtitle: 'Know what you take, when you take it, and what needs attention.',
            action: PButton('+ Add', onPressed: _openAddMedication),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: PT.teal)),
            )
          else
            Consumer<AdherenceProvider>(
              builder: (context, ad, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _todayCard(ad),
                    const SizedBox(height: 16),
                    PTabs(
                      tabs: const ['Active', 'Past'],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                    _tab == 0 ? _activeList(ad) : _pastList(ad),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Today's progress ──────────────────────────────────────────────────

  Widget _todayCard(AdherenceProvider ad) {
    final total = ad.todayDoses.length;
    final remaining = ad.todayRemaining;
    final done = total - remaining;

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            'Today',
            trailing: PButton(
              'View history',
              kind: PButtonKind.alt,
              dense: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdherenceLogScreen()),
              ),
            ),
          ),
          if (total == 0)
            Text('Nothing scheduled for today.', style: PT.sub())
          else ...[
            Row(
              children: [
                Expanded(child: PProgress(total == 0 ? 0 : done / total)),
                const SizedBox(width: 12),
                Text('$done of $total taken',
                    style: PT.rowSub().copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                PBadge(
                  remaining > 0
                      ? '$remaining dose${remaining == 1 ? '' : 's'} remaining'
                      : 'All doses taken',
                  tone: remaining > 0 ? PTone.warn : PTone.ok,
                ),
                if (ad.streak > 0) ...[
                  const SizedBox(width: 8),
                  PBadge('${ad.streak} day streak 🔥', tone: PTone.blue),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Active (today's doses) ────────────────────────────────────────────

  Widget _activeList(AdherenceProvider ad) {
    final doses = List<AdherenceLogModel>.from(ad.todayDoses)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    if (doses.isEmpty) {
      return PCard(
        child: PEmpty(
          emoji: '💊',
          title: 'No medications yet',
          body: 'Add a medication to start tracking your daily doses.',
          action: PButton('+ Add medication', onPressed: _openAddMedication),
        ),
      );
    }

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final d in doses) _doseRow(d)],
      ),
    );
  }

  Widget _doseRow(AdherenceLogModel d) {
    final pending = d.status == AdherenceStatus.pending;
    final taken = d.status == AdherenceStatus.taken;
    final overdue = pending && d.scheduledTime.isBefore(DateTime.now());

    final subtitle = [
      if ((d.dosage ?? '').isNotEmpty) d.dosage!,
      DateFormat('HH:mm').format(d.scheduledTime),
    ].join(' · ');

    return PRow(
      leadingEmoji: '💊',
      title: d.medicationName ?? 'Medication',
      subtitle: subtitle,
      trailing: [
        if (!pending)
          PBadge(taken ? 'Taken' : 'Skipped', tone: taken ? PTone.ok : PTone.warn)
        else if (overdue)
          const PBadge('Overdue', tone: PTone.red)
        else
          const PBadge('Due', tone: PTone.gray),
      ],
      below: !pending
          ? null
          : Row(
              children: [
                PButton(
                  'Mark taken',
                  dense: true,
                  icon: Icons.check_rounded,
                  onPressed: () => _mark(d, AdherenceStatus.taken),
                ),
                const SizedBox(width: 10),
                PButton(
                  'Skip',
                  kind: PButtonKind.alt,
                  dense: true,
                  onPressed: () => _mark(d, AdherenceStatus.skipped),
                ),
              ],
            ),
    );
  }

  // ── Past ──────────────────────────────────────────────────────────────

  Widget _pastList(AdherenceProvider ad) {
    final today = DateUtils.dateOnly(DateTime.now());
    final past = ad.history
        .where((d) =>
            d.status != AdherenceStatus.pending &&
            DateUtils.dateOnly(d.scheduledTime) != today)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

    if (past.isEmpty) {
      return const PCard(
        child: PEmpty(
          emoji: '🗓️',
          title: 'No past doses yet',
          body: 'Doses you mark as taken or skipped will be listed here.',
        ),
      );
    }

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in past.take(30))
            PRow(
              leadingEmoji: d.status == AdherenceStatus.taken ? '✓' : '–',
              title: d.medicationName ?? 'Medication',
              subtitle: DateFormat('EEE d MMM · HH:mm').format(d.scheduledTime),
              trailing: [
                PBadge(
                  d.status == AdherenceStatus.taken ? 'Taken' : 'Skipped',
                  tone: d.status == AdherenceStatus.taken ? PTone.ok : PTone.warn,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Add medication ────────────────────────────────────────────────────

  Future<void> _openAddMedication() async {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final instructionsCtrl = TextEditingController();
    var timesPerDay = 1;
    var submitting = false;

    await showPModal<void>(
      context: context,
      title: 'Add a medication',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is added as a self-tracked medication so AfiCare can remind you and '
              'record each dose.',
              style: PT.sub(),
            ),
            const SizedBox(height: 16),
            PFormGrid([
              PField(
                label: 'Medication name',
                child: TextField(
                  controller: nameCtrl,
                  decoration: pInput(hint: 'e.g. Amoxicillin'),
                ),
              ),
              PField(
                label: 'Dosage',
                child: TextField(
                  controller: dosageCtrl,
                  decoration: pInput(hint: 'e.g. 250 mg, 1 tablet'),
                ),
              ),
              PField(
                label: 'Times per day',
                child: DropdownButtonFormField<int>(
                  value: timesPerDay,
                  decoration: pInput(),
                  items: [
                    for (int i = 1; i <= 6; i++)
                      DropdownMenuItem(value: i, child: Text('$i time${i == 1 ? '' : 's'} a day')),
                  ],
                  onChanged: (v) => setSheetState(() => timesPerDay = v ?? 1),
                ),
              ),
              PField(
                label: 'Instructions (optional)',
                child: TextField(
                  controller: instructionsCtrl,
                  decoration: pInput(hint: 'e.g. after food'),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            PButton(
              submitting ? 'Saving…' : 'Save medication',
              expand: true,
              onPressed: submitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        pToast(ctx, 'Please enter a medication name.');
                        return;
                      }
                      if (dosageCtrl.text.trim().isEmpty) {
                        pToast(ctx, 'Please enter a dosage, e.g. 500 mg.');
                        return;
                      }
                      setSheetState(() => submitting = true);

                      final ad = Provider.of<AdherenceProvider>(context, listen: false);
                      final ok = await ad.addMedication(
                        patientId: _patientId,
                        medicationName: nameCtrl.text.trim(),
                        dosage: dosageCtrl.text.trim(),
                        timesPerDay: timesPerDay,
                        instructions: instructionsCtrl.text.trim().isEmpty
                            ? null
                            : instructionsCtrl.text.trim(),
                      );

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      pToast(context, ok ? 'Medication added' : 'Could not add that medication');
                      if (ok) _load();
                    },
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    dosageCtrl.dispose();
    instructionsCtrl.dispose();
  }
}
