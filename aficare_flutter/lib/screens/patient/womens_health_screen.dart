import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/womens_health_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../theme/patient_tokens.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// Women's health: where the patient is in life (trying, pregnant, …),
/// her cycle, and her cervical and breast screening dates.
///
/// Replaces the Maternal and Women's Health tabs of the old full
/// dashboard and reads the same stored record (see [WomensHealthRecord]),
/// so nothing recorded there is lost. Account-holder only: the record
/// lives on the signed-in user, so the page is adult-only in the nav.
class WomensHealthScreen extends StatefulWidget {
  const WomensHealthScreen({super.key});

  @override
  State<WomensHealthScreen> createState() => _WomensHealthScreenState();
}

enum _SaveState { idle, saving, saved, failed }

class _WomensHealthScreenState extends State<WomensHealthScreen> {
  late WomensHealthRecord _record;
  bool _loaded = false;

  /// Saves run one after another so two quick changes can never write
  /// over each other with stale metadata.
  Future<void> _queue = Future.value();
  int _pending = 0;
  _SaveState _saveState = _SaveState.idle;

  /// The pain slider's position while it is being dragged.
  double? _painDraft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _record = _storedRecord(user.metadata);
    _loaded = true;
  }

  static WomensHealthRecord _storedRecord(Map<String, dynamic>? metadata) {
    final raw = metadata?['maternal_health'];
    return WomensHealthRecord.fromJson(raw is Map ? Map<String, dynamic>.from(raw) : null);
  }

  /// Shows [next] at once and saves it. If the save fails, the page goes
  /// back to what is actually stored, so it never shows unsaved data as
  /// though it were kept.
  Future<bool> _commit(WomensHealthRecord next, {String? confirmation}) {
    setState(() {
      _record = next;
      _pending++;
      _saveState = _SaveState.saving;
    });
    final auth = context.read<AuthProvider>();
    var ok = false;
    _queue = _queue.then((_) async {
      final meta = Map<String, dynamic>.from(auth.currentUser?.metadata ?? const {});
      meta['maternal_health'] = _record.toJson();
      ok = await auth.updateProfile(metadata: meta);
      if (!mounted) return;
      setState(() {
        _pending--;
        if (!ok) {
          _record = _storedRecord(auth.currentUser?.metadata);
          _saveState = _SaveState.failed;
        } else if (_pending == 0 && _saveState != _SaveState.failed) {
          _saveState = _SaveState.saved;
        }
      });
      if (!ok) {
        pToast(context, "We couldn't save that, so nothing was changed. Please check your connection and try again.");
      } else if (confirmation != null) {
        pToast(context, confirmation);
      }
    });
    return _queue.then((_) => ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const PLoadingPage();

    final today = DateUtils.dateOnly(DateTime.now());
    final age = context.watch<PatientProfileProvider>().profile?.age;

    return PDetailScaffold(
      eyebrow: 'Your health, your pace',
      title: "Women's health",
      subtitle: 'Your cycle, your screenings and where you are in life, kept together in your record.',
      action: _SaveStatus(state: _saveState),
      children: [
        _Summary(record: _record, today: today, age: age),
        const SizedBox(height: 16),
        PGrid(
          columns: 2,
          children: [
            _CycleCard(
              record: _record,
              today: today,
              painDraft: _painDraft,
              onLogPeriod: _logPeriod,
              onEditCycle: _editCycle,
              onPainDrag: (v) => setState(() => _painDraft = v),
              onPainSet: (v) {
                setState(() => _painDraft = null);
                _commit(_record.copyWith(periodPain: v.round()));
              },
            ),
            _ScreeningsCard(
              record: _record,
              today: today,
              age: age,
              onEdit: _editScreening,
            ),
            _LifeStageCard(
              record: _record,
              onStage: (stage) => _commit(_record.copyWith(lifeStage: stage)),
              onCheck: (key, value) =>
                  _commit(_record.copyWith(checklist: {..._record.checklist, key: value})),
            ),
            const _WorthKnowingCard(),
          ],
        ),
        const SizedBox(height: 16),
        const PCallout(
          title: 'Who can see this',
          body: 'This is part of your AfiCare record. You and the clinicians caring for you can see it, '
              'so they can give you the right advice. Anyone you have given caregiver access can see '
              'it too, depending on the access you chose.',
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _logPeriod({required bool today}) async {
    final now = DateUtils.dateOnly(DateTime.now());
    DateTime? start = now;
    if (!today) {
      start = await showDatePicker(
        context: context,
        helpText: 'When did your period start?',
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 90)),
        lastDate: now,
      );
    }
    if (start == null || !mounted) return;
    final next = _record.copyWith(lastPeriodStart: start);
    final expected = next.expectedNextPeriod(now);
    _commit(
      next,
      confirmation: expected == null
          ? 'Logged.'
          : 'Logged. Your next period is expected around ${DateFormat('EEE d MMM').format(expected)}.',
    );
  }

  Future<void> _editCycle() async {
    final result = await showPModal<(int, int)>(
      context: context,
      title: 'Your cycle',
      builder: (ctx) => _CycleForm(record: _record),
    );
    if (result == null) return;
    _commit(_record.copyWith(cycleLength: result.$1, periodLength: result.$2), confirmation: 'Saved.');
  }

  Future<void> _editScreening(Screening s) async {
    final current = s == Screening.cervical ? _record.lastCervicalScreening : _record.lastMammogram;
    final result = await showPModal<({DateTime? date})>(
      context: context,
      title: s == Screening.cervical ? 'Cervical screening' : 'Breast screening',
      builder: (ctx) => _ScreeningForm(screening: s, current: current),
    );
    if (result == null) return;
    final d = result.date;
    _commit(
      s == Screening.cervical
          ? _record.copyWith(lastCervicalScreening: d, clearCervicalScreening: d == null)
          : _record.copyWith(lastMammogram: d, clearMammogram: d == null),
      confirmation: 'Saved.',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Save status — beside the title, so every change is visibly kept.
// ═══════════════════════════════════════════════════════════════════════

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (state) {
      _SaveState.idle => ('Changes save as you go', PT.muted),
      _SaveState.saving => ('Saving…', PT.muted),
      _SaveState.saved => ('✓ Saved', PT.green),
      _SaveState.failed => ('Not saved, please try again', PT.danger),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: PT.label().copyWith(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Summary — three numbers at a glance
// ═══════════════════════════════════════════════════════════════════════

class _Summary extends StatelessWidget {
  const _Summary({required this.record, required this.today, required this.age});

  final WomensHealthRecord record;
  final DateTime today;
  final int? age;

  @override
  Widget build(BuildContext context) {
    final next = record.expectedNextPeriod(today);
    final days = record.daysUntilNextPeriod(today);
    final dayOfPeriod = record.lastPeriodStart == null
        ? null
        : today.difference(DateUtils.dateOnly(record.lastPeriodStart!)).inDays + 1;

    final String periodLabel;
    final String periodValue;
    final String? periodNote;
    if (record.onPeriod(today)) {
      periodLabel = 'Your period';
      periodValue = 'Day $dayOfPeriod';
      periodNote = next == null ? null : 'Next one around ${DateFormat('d MMM').format(next)}';
    } else if (days == null) {
      periodLabel = 'Next period';
      periodValue = 'Not logged';
      periodNote = 'Log your next period to see a prediction';
    } else {
      periodLabel = 'Next period';
      periodValue = switch (days) {
        0 => 'Today',
        1 => 'Tomorrow',
        > 1 => 'In $days days',
        -1 => '1 day late',
        _ => '${-days} days late',
      };
      periodNote = days < 0
          ? 'Cycles vary. Log it when it starts'
          : 'Around ${DateFormat('EEE d MMM').format(next!)}';
    }

    // The screening due soonest, of those that apply at this age.
    final statuses = [
      record.cervicalStatus(today, age: age),
      record.breastStatus(today, age: age),
    ].where((s) => s.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final soonest = statuses.isEmpty ? null : statuses.first;
    final screeningValue = soonest == null
        ? 'Not recorded'
        : soonest.state == ScreeningState.overdue
            ? 'Overdue'
            : DateFormat('MMM yyyy').format(soonest.dueDate!);
    final screeningNote = soonest == null
        ? 'Add your last screening dates below'
        : soonest.state == ScreeningState.overdue
            ? 'Since ${DateFormat('MMM yyyy').format(soonest.dueDate!)}'
            : null;

    return PGrid(
      columns: 3,
      children: [
        PMetric(label: periodLabel, value: periodValue, note: periodNote),
        PMetric(
          label: 'Cycle length',
          value: '${record.cycleLength} days',
          note: 'Period lasts about ${record.periodLength} '
              '${record.periodLength == 1 ? 'day' : 'days'}',
        ),
        PMetric(label: 'Next screening due', value: screeningValue, note: screeningNote),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Cycle
// ═══════════════════════════════════════════════════════════════════════

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.record,
    required this.today,
    required this.painDraft,
    required this.onLogPeriod,
    required this.onEditCycle,
    required this.onPainDrag,
    required this.onPainSet,
  });

  final WomensHealthRecord record;
  final DateTime today;
  final double? painDraft;
  final Future<void> Function({required bool today}) onLogPeriod;
  final VoidCallback onEditCycle;
  final ValueChanged<double> onPainDrag;
  final ValueChanged<double> onPainSet;

  @override
  Widget build(BuildContext context) {
    final loggedToday = record.lastPeriodStart != null &&
        DateUtils.isSameDay(record.lastPeriodStart, today);
    final pain = painDraft ?? record.periodPain?.toDouble();

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            'Your cycle',
            trailing: PButton('Edit', kind: PButtonKind.alt, dense: true, onPressed: onEditCycle),
          ),
          Text(
            record.lastPeriodStart == null
                ? "Log the day your period starts and we'll estimate the next one."
                : 'Last period started ${DateFormat('EEE d MMMM').format(record.lastPeriodStart!)}.',
            style: PT.sub(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!loggedToday)
                PButton('My period started today',
                    icon: Icons.water_drop_outlined, onPressed: () => onLogPeriod(today: true)),
              PButton(loggedToday ? 'Started on a different day?' : 'Another day',
                  kind: PButtonKind.alt, onPressed: () => onLogPeriod(today: false)),
            ],
          ),
          if (record.cycleOutsideTypicalRange) ...[
            const SizedBox(height: 12),
            const PCallout(
              tone: PTone.warn,
              body: 'Most cycles are 21 to 35 days. Yours is outside that, which is often nothing, '
                  'but it is worth mentioning at your next visit.',
            ),
          ],
          const SizedBox(height: 18),
          Text('How painful are your periods, usually?', style: PT.rowTitle()),
          const SizedBox(height: 2),
          Text(pain == null ? 'Not answered yet' : '${pain.round()} out of 10: ${_painWord(pain.round())}',
              style: PT.rowSub()),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PT.teal,
              inactiveTrackColor: PT.progressTrack,
              thumbColor: PT.navy,
              overlayColor: PT.teal.withOpacity(.12),
              valueIndicatorColor: PT.navy,
            ),
            child: Slider(
              value: pain ?? 1,
              min: 1,
              max: 10,
              divisions: 9,
              label: pain == null ? null : '${pain.round()}',
              semanticFormatterCallback: (v) => '${v.round()} out of 10, ${_painWord(v.round())}',
              onChanged: onPainDrag,
              onChangeEnd: onPainSet,
            ),
          ),
          Row(
            children: [
              Expanded(child: Text('Barely noticeable', style: PT.label())),
              Expanded(child: Text('Worst imaginable', style: PT.label(), textAlign: TextAlign.end)),
            ],
          ),
          if ((record.periodPain ?? 0) >= 7 && painDraft == null) ...[
            const SizedBox(height: 12),
            PCallout(
              tone: PTone.warn,
              title: "You don't have to put up with this",
              body: 'Period pain this strong is common but not normal. It can be a sign of '
                  'endometriosis or fibroids, and there is treatment that helps.',
              trailing: PButton('Book a visit',
                  kind: PButtonKind.alt, dense: true, onPressed: () => context.go(PatientRoutes.appointments)),
            ),
          ],
        ],
      ),
    );
  }

  static String _painWord(int v) => v <= 3
      ? 'mild'
      : v <= 6
          ? 'moderate'
          : 'severe';
}

class _CycleForm extends StatefulWidget {
  const _CycleForm({required this.record});

  final WomensHealthRecord record;

  @override
  State<_CycleForm> createState() => _CycleFormState();
}

class _CycleFormState extends State<_CycleForm> {
  late final _cycle = TextEditingController(text: '${widget.record.cycleLength}');
  late final _period = TextEditingController(text: '${widget.record.periodLength}');
  String? _error;

  @override
  void dispose() {
    _cycle.dispose();
    _period.dispose();
    super.dispose();
  }

  void _save() {
    final c = int.tryParse(_cycle.text.trim());
    final p = int.tryParse(_period.text.trim());
    if (c == null || c < WomensHealthRecord.minCycleLength || c > WomensHealthRecord.maxCycleLength) {
      setState(() => _error = 'Cycle length should be between ${WomensHealthRecord.minCycleLength} '
          'and ${WomensHealthRecord.maxCycleLength} days.');
      return;
    }
    if (p == null || p < WomensHealthRecord.minPeriodLength || p > WomensHealthRecord.maxPeriodLength) {
      setState(() => _error = 'Period length should be between ${WomensHealthRecord.minPeriodLength} '
          'and ${WomensHealthRecord.maxPeriodLength} days.');
      return;
    }
    if (p >= c) {
      setState(() => _error = 'Your period should be shorter than your whole cycle.');
      return;
    }
    Navigator.pop(context, (c, p));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Count your cycle from the first day of one period to the day before the next. '
          "If you're not sure, 28 days is a fine place to start.",
          style: PT.sub(),
        ),
        const SizedBox(height: 15),
        PFormGrid([
          PField(
            label: 'Cycle length (days)',
            child: TextField(
              controller: _cycle,
              keyboardType: TextInputType.number,
              decoration: pInput(hint: '28'),
              onSubmitted: (_) => _save(),
            ),
          ),
          PField(
            label: 'Period length (days)',
            child: TextField(
              controller: _period,
              keyboardType: TextInputType.number,
              decoration: pInput(hint: '5'),
              onSubmitted: (_) => _save(),
            ),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 18),
        Align(alignment: Alignment.centerRight, child: PButton('Save', onPressed: _save)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Screenings
// ═══════════════════════════════════════════════════════════════════════

class _ScreeningsCard extends StatelessWidget {
  const _ScreeningsCard({required this.record, required this.today, required this.age, required this.onEdit});

  final WomensHealthRecord record;
  final DateTime today;
  final int? age;
  final ValueChanged<Screening> onEdit;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Screenings'),
          Text('Two quick checks that catch problems early, when they are easiest to treat. Tap one to update it.',
              style: PT.sub()),
          const SizedBox(height: 10),
          _row(
            context,
            emoji: '🌸',
            title: 'Cervical screening',
            what: 'Pap smear or VIA, every 3 years from age 25',
            last: record.lastCervicalScreening,
            status: record.cervicalStatus(today, age: age),
            screening: Screening.cervical,
          ),
          _row(
            context,
            emoji: '🎀',
            title: 'Breast screening',
            what: 'Mammogram, every 2 years from age 40',
            last: record.lastMammogram,
            status: record.breastStatus(today, age: age),
            screening: Screening.breast,
          ),
          const SizedBox(height: 8),
          Text(
            'Cervical screening is offered at many public health facilities in Kenya, often free of charge.',
            style: PT.rowSub(),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String emoji,
    required String title,
    required String what,
    required DateTime? last,
    required ScreeningStatus status,
    required Screening screening,
  }) {
    final fmt = DateFormat('d MMM yyyy');
    final (badge, tone) = switch (status.state) {
      ScreeningState.notYet => ('Not needed yet', PTone.gray),
      ScreeningState.notRecorded => ('Not recorded', PTone.gray),
      ScreeningState.upToDate => ('Up to date', PTone.ok),
      ScreeningState.dueSoon => ('Due soon', PTone.warn),
      ScreeningState.overdue => ('Due now', PTone.red),
    };
    final subtitle = last == null
        ? what
        : 'Last: ${fmt.format(last)} · next due ${DateFormat('MMM yyyy').format(status.dueDate!)}';
    return Semantics(
      button: true,
      label: '$title. $badge. $subtitle',
      excludeSemantics: true,
      child: PRow(
        leadingEmoji: emoji,
        title: title,
        subtitle: subtitle,
        trailing: [PBadge(badge, tone: tone)],
        onTap: () => onEdit(screening),
      ),
    );
  }
}

class _ScreeningForm extends StatefulWidget {
  const _ScreeningForm({required this.screening, required this.current});

  final Screening screening;
  final DateTime? current;

  @override
  State<_ScreeningForm> createState() => _ScreeningFormState();
}

class _ScreeningFormState extends State<_ScreeningForm> {
  late DateTime? _date = widget.current;

  Future<void> _pick() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      helpText: 'When was your last one?',
      initialDate: _date ?? now,
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cervical = widget.screening == Screening.cervical;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cervical
              ? 'A quick check of the cervix that finds changes years before they could become cancer. '
                  'Usually every 3 years from age 25, or as your clinic advises.'
              : 'An X-ray of the breast that can find cancer before a lump can be felt. '
                  'Usually every 2 years from age 40, or sooner if breast cancer runs in your family.',
          style: PT.sub(),
        ),
        const SizedBox(height: 15),
        PField(
          label: 'Date of your last one',
          child: PButton(
            _date == null ? 'Choose a date' : DateFormat('d MMMM yyyy').format(_date!),
            kind: PButtonKind.alt,
            icon: Icons.event_outlined,
            onPressed: _pick,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            PButton("I haven't had one",
                kind: PButtonKind.alt, onPressed: () => Navigator.pop(context, (date: null))),
            PButton('Save',
                onPressed: _date == null ? null : () => Navigator.pop(context, (date: _date))),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Life stage, with what helps at each one
// ═══════════════════════════════════════════════════════════════════════

class _LifeStageCard extends StatelessWidget {
  const _LifeStageCard({required this.record, required this.onStage, required this.onCheck});

  final WomensHealthRecord record;
  final ValueChanged<String> onStage;
  final void Function(String key, bool value) onCheck;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Where you are right now'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in WomensHealthRecord.lifeStages.entries)
                _StageChip(
                  label: e.value,
                  selected: record.lifeStage == e.key,
                  onTap: () => onStage(e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._forStage(context),
        ],
      ),
    );
  }

  List<Widget> _forStage(BuildContext context) {
    switch (record.lifeStage) {
      case 'trying':
        final total = WomensHealthRecord.preconceptionItems.length;
        final done = record.preconceptionDone;
        return [
          Row(
            children: [
              Expanded(child: Text('Getting ready for pregnancy', style: PT.rowTitle())),
              Text('$done of $total', style: PT.label()),
            ],
          ),
          const SizedBox(height: 8),
          PProgress(done / total, color: PT.green),
          const SizedBox(height: 8),
          for (final e in WomensHealthRecord.preconceptionItems.entries)
            _CheckRow(
              title: e.value.$1,
              subtitle: e.value.$2,
              checked: record.checklist[e.key] ?? false,
              onChanged: (v) => onCheck(e.key, v),
            ),
        ];
      case 'pregnant':
        return [
          PCallout(
            title: 'Congratulations',
            body: 'Your antenatal visits, scans and due date live in Maternal care.',
            trailing: PButton('Open', kind: PButtonKind.alt, dense: true, onPressed: () => context.go('/patient/anc')),
          ),
        ];
      case 'postpartum':
        return [
          PCallout(
            body: 'Check-ups in the first six weeks after birth are for you as well as your baby. '
                'Heavy bleeding, fever, or feeling low for more than two weeks are reasons to be seen sooner.',
            trailing: PButton('Book', kind: PButtonKind.alt, dense: true,
                onPressed: () => context.go(PatientRoutes.appointments)),
          ),
        ];
      case 'breastfeeding':
        return [
          PCallout(
            body: "Whenever you're given a new medicine, mention that you're breastfeeding. "
                'You can also look a medicine up in the Medicine checker.',
            trailing: PButton('Check', kind: PButtonKind.alt, dense: true,
                onPressed: () => context.go('/patient/drug-interactions')),
          ),
        ];
      default:
        return [
          Text("If that changes, choose another stage and we'll show what helps then.", style: PT.rowSub()),
        ];
    }
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? PT.navy : PT.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PT.rPill),
          side: BorderSide(color: selected ? PT.navy : PT.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: PT.body().copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? PT.white : PT.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.title, required this.subtitle, required this.checked, required this.onChanged});

  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: () => onChanged(!checked),
      child: InkWell(
        borderRadius: BorderRadius.circular(PT.rRow),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? PT.green : PT.white,
                  border: Border.all(color: checked ? PT.green : PT.toggleOff, width: 1.5),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: checked ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PT.rowTitle().copyWith(color: checked ? PT.muted : PT.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: PT.rowSub()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Worth knowing — signs to act on, in plain words
// ═══════════════════════════════════════════════════════════════════════

class _WorthKnowingCard extends StatelessWidget {
  const _WorthKnowingCard();

  @override
  Widget build(BuildContext context) {
    return const PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle('Worth knowing'),
          _InfoTile(
            emoji: '🩸',
            title: 'Periods that need a doctor',
            points: [
              'Bleeding between periods, after sex, or after menopause',
              'Periods longer than 7 days, or soaking a pad every hour or two',
              "No period for three months when you're not pregnant or breastfeeding",
              'Pain that stops you working, studying or sleeping',
            ],
          ),
          _InfoTile(
            emoji: '🔄',
            title: 'PCOS',
            points: [
              'Polycystic ovary syndrome is common and treatable',
              'Signs: irregular or missed periods, extra hair on the face or body, acne, weight gain',
              'A simple check with your doctor is the first step',
            ],
          ),
          _InfoTile(
            emoji: '🌿',
            title: 'Endometriosis',
            points: [
              "Period pain that painkillers don't touch, pain during sex, or trouble getting pregnant",
              'It is often missed for years. If this sounds familiar, say so clearly',
            ],
          ),
          _InfoTile(
            emoji: '🤍',
            title: 'Knowing your breasts',
            points: [
              'Get to know how your breasts normally look and feel',
              'See a doctor about a new lump, dimpled skin, a changed nipple or discharge',
              "Most lumps aren't cancer, but every new one should be checked",
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatefulWidget {
  const _InfoTile({required this.emoji, required this.title, required this.points});

  final String emoji;
  final String title;
  final List<String> points;

  @override
  State<_InfoTile> createState() => _InfoTileState();
}

class _InfoTileState extends State<_InfoTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: PT.line),
          borderRadius: BorderRadius.circular(PT.rRow),
        ),
        child: Column(
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                borderRadius: BorderRadius.circular(PT.rRow),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(widget.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 11),
                      Expanded(child: Text(widget.title, style: PT.rowTitle())),
                      AnimatedRotation(
                        turns: _open ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.expand_more, color: PT.muted, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(41, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in widget.points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('•  ', style: PT.rowSub()),
                                  Expanded(child: Text(p, style: PT.rowSub().copyWith(color: PT.ink))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
