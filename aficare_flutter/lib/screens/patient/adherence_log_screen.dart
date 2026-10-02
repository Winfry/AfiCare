import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// Adherence Log — which doses were taken, skipped or missed.
///
/// The centrepiece is the week grid from the spec: one row per
/// medication, one column per day. A dose left unmarked past its
/// scheduled time counts as missed, which is the same rule
/// [AdherenceProvider.missedDoses] already applies.
class AdherenceLogScreen extends StatefulWidget {
  const AdherenceLogScreen({super.key});

  @override
  State<AdherenceLogScreen> createState() => _AdherenceLogScreenState();
}

enum _Cell { taken, partial, due, skipped, missed, none }

class _AdherenceLogScreenState extends State<AdherenceLogScreen> {
  bool _isLoading = true;
  int _range = 7; // 7 or 30

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id != null) await ad.loadHistory(id, days: _range);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PDetailScaffold(
      eyebrow: 'Clinical',
      title: 'Adherence Log',
      subtitle: 'See which doses were taken, skipped or missed.',
      children: [
        PTabs(
          tabs: const ['Last 7 days', 'Last 30 days'],
          selected: _range == 7 ? 0 : 1,
          onSelect: (i) {
            setState(() => _range = i == 0 ? 7 : 30);
            _load();
          },
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator(color: PT.teal)),
          )
        else
          Consumer<AdherenceProvider>(
            builder: (context, ad, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PGrid(
                    columns: 3,
                    children: [
                      PMetric(
                        label: 'Adherence',
                        value: '${ad.historyRate}%',
                        note: _range == 7 ? 'over the last 7 days' : 'over the last 30 days',
                      ),
                      PMetric(
                        label: 'Doses taken',
                        value: '${ad.historyTaken}/${ad.historyTotal}',
                        note: 'in this period',
                      ),
                      PMetric(
                        label: 'Active streak',
                        value: '${ad.streak}',
                        note: ad.streak > 0 ? 'days in a row 🔥' : 'start one today',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _weekGrid(ad),
                  const SizedBox(height: 20),
                  _missedSection(ad),
                ],
              );
            },
          ),
      ],
    );
  }

  // ── Week grid ─────────────────────────────────────────────────────────

  Widget _weekGrid(AdherenceProvider ad) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    final meds = <String>{
      for (final d in ad.history) d.medicationName ?? 'Medication',
    }.toList()
      ..sort();

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Last 7 days'),
          if (meds.isEmpty)
            const PEmpty(
              emoji: '💊',
              title: 'Nothing scheduled yet',
              body: 'Once you have medications with a schedule, your week shows up here.',
            )
          else ...[
            Row(
              children: [
                const SizedBox(width: 112),
                for (final d in days)
                  Expanded(
                    child: Column(
                      children: [
                        Text(DateFormat('EEE').format(d),
                            style: PT.rowSub().copyWith(
                                fontSize: 11, fontWeight: FontWeight.w800, height: 1.2)),
                        if (d == today)
                          Text('today',
                              style: PT.rowSub().copyWith(fontSize: 10, color: PT.teal)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in meds) _gridRow(ad, m, days),
            const SizedBox(height: 12),
            Text(
              '✓ all taken · ◐ some still due · ○ due · – skipped · ✕ missed',
              style: PT.rowSub().copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gridRow(AdherenceProvider ad, String med, List<DateTime> days) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(med,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.rowTitle()),
          ),
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _cell(_stateFor(ad, med, d)),
              ),
            ),
        ],
      ),
    );
  }

  _Cell _stateFor(AdherenceProvider ad, String med, DateTime day) {
    final now = DateTime.now();
    final doses = ad.history.where((d) =>
        (d.medicationName ?? 'Medication') == med &&
        DateUtils.isSameDay(d.scheduledTime, day));

    if (doses.isEmpty) return _Cell.none;

    var taken = 0, skipped = 0, due = 0, missed = 0;
    for (final d in doses) {
      switch (d.status) {
        case AdherenceStatus.taken:
          taken++;
        case AdherenceStatus.skipped:
          skipped++;
        case AdherenceStatus.pending:
          // Unmarked past its scheduled time counts as missed.
          if (d.scheduledTime.isBefore(now)) {
            missed++;
          } else {
            due++;
          }
      }
    }

    if (missed > 0) return _Cell.missed;
    if (skipped > 0) return _Cell.skipped;
    if (due > 0 && taken > 0) return _Cell.partial;
    if (due > 0) return _Cell.due;
    if (taken > 0) return _Cell.taken;
    return _Cell.none;
  }

  Widget _cell(_Cell state) {
    final (bg, fg, glyph, tip) = switch (state) {
      _Cell.taken => (const Color(0xFFE4F5EC), const Color(0xFF2D8A5C), '✓', 'All taken'),
      _Cell.partial => (const Color(0xFFEAF4FB), const Color(0xFF2C7299), '◐', 'Some doses still due'),
      _Cell.due => (PT.white, PT.muted, '○', 'Due'),
      _Cell.skipped => (const Color(0xFFFFF7E8), const Color(0xFF9A6A16), '–', 'Skipped'),
      _Cell.missed => (const Color(0xFFFFF0F1), const Color(0xFFB43A43), '✕', 'Missed'),
      _Cell.none => (const Color(0xFFF0F4F4), PT.muted, '·', 'Nothing scheduled'),
    };

    return Tooltip(
      message: tip,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: state == _Cell.due ? Border.all(color: const Color(0xFFCFDADD)) : null,
        ),
        child: Text(glyph,
            style: PT.body().copyWith(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
      ),
    );
  }

  // ── Missed doses ──────────────────────────────────────────────────────

  Widget _missedSection(AdherenceProvider ad) {
    final missed = ad.missedDoses;

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            'Missed doses',
            trailing: missed.isEmpty
                ? const PBadge('All caught up', tone: PTone.ok)
                : PBadge('${missed.length}', tone: PTone.red),
          ),
          if (missed.isEmpty)
            const PEmpty(
              emoji: '🎉',
              title: 'No missed doses',
              body: 'Everything scheduled in this period was marked.',
            )
          else
            for (final d in missed)
              PRow(
                leadingEmoji: '✕',
                title: d.medicationName ?? 'Medication',
                subtitle: DateFormat('EEEE, d MMM · HH:mm').format(d.scheduledTime),
                trailing: const [PBadge('Missed', tone: PTone.red)],
              ),
        ],
      ),
    );
  }
}
