import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/anc_reading_checks.dart';
import '../../models/anc_visit_model.dart';
import '../../models/pregnancy_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pregnancy_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';
import 'widgets/pregnancy_forms.dart';

/// Maternal care: the ongoing pregnancy week by week, its antenatal (ANC)
/// visits, and past pregnancies. Built on [PregnancyProvider], the same
/// record Women's health uses. Account-holder only (adult-only in the nav).
class AncScreen extends StatefulWidget {
  const AncScreen({super.key});

  @override
  State<AncScreen> createState() => _AncScreenState();
}

class _AncScreenState extends State<AncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) context.read<PregnancyProvider>().load(userId);
  }

  @override
  Widget build(BuildContext context) {
    final pregnancies = context.watch<PregnancyProvider>();
    if (!pregnancies.loaded) return const PLoadingPage();

    final current = pregnancies.current;
    final today = DateUtils.dateOnly(DateTime.now());

    return PDetailScaffold(
      eyebrow: 'You and your baby',
      title: 'Maternal care',
      subtitle: 'Your pregnancy, week by week, and the visits that go with it.',
      action: current == null ? null : PButton('Add a visit', icon: Icons.add, onPressed: () => _addVisit(current)),
      children: [
        if (pregnancies.loadFailed && pregnancies.pregnancies.isEmpty)
          PLoadError(what: 'your pregnancy record', onRetry: _load)
        else if (current == null)
          _StartCard(onStart: _start)
        else ...[
          _ProgressHero(pregnancy: current, visitsDone: pregnancies.visitsOf(current).length, today: today),
          _StandingAlerts(visits: pregnancies.visitsOf(current)),
          const _SeekCareCallout(),
          const SizedBox(height: 22),
          const PHeading('Antenatal visits'),
          _VisitList(pregnancy: current, visits: pregnancies.visitsOf(current), onAdd: () => _addVisit(current)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PButton('Change dates', kind: PButtonKind.alt, icon: Icons.edit_calendar_outlined,
                  onPressed: () => _changeDates(current)),
              PButton('This pregnancy has ended', kind: PButtonKind.alt, onPressed: () => _end(current)),
            ],
          ),
        ],
        if (pregnancies.past.isNotEmpty) ...[
          const SizedBox(height: 26),
          const PHeading('Past pregnancies'),
          PCard(
            child: Column(
              children: [
                for (final p in pregnancies.past)
                  _PastRow(pregnancy: p, visits: pregnancies.visitsOf(p).length),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const PCallout(
          title: 'Who can see this',
          body: 'You, and the doctors and nurses caring for you: your care team, and anyone you have '
              'an appointment or consultation with. They can read it but not change it.',
        ),
      ],
    );
  }

  Future<void> _start() async {
    if (await showPregnancyDatesForm(context) && mounted) {
      pToast(context, 'Saved. Congratulations!');
    }
  }

  Future<void> _changeDates(Pregnancy p) async {
    if (await showPregnancyDatesForm(context, editing: p) && mounted) {
      pToast(context, 'Your dates are updated.');
    }
  }

  Future<void> _end(Pregnancy p) async {
    if (await showEndPregnancyForm(context, p) && mounted) {
      pToast(context, 'Saved. Your visits stay in your history.');
    }
  }

  Future<void> _addVisit(Pregnancy p) async {
    final alerts = await showPModal<List<AncAlert>>(
      context: context,
      title: 'Add a visit',
      builder: (_) => _VisitForm(pregnancy: p),
    );
    if (alerts == null || !mounted) return;
    if (alerts.isEmpty) {
      pToast(context, 'Visit saved.');
      return;
    }
    // Anything the readings call for is said again once saved, in full,
    // rather than in a toast that disappears.
    await showPModal<void>(
      context: context,
      title: 'Visit saved',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alerts.length == 1
                ? 'One thing from this visit needs your attention:'
                : '${alerts.length} things from this visit need your attention:',
            style: PT.sub(),
          ),
          const SizedBox(height: 12),
          AncAlertList(alerts: alerts),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: PButton('I understand', onPressed: () => Navigator.pop(ctx)),
          ),
        ],
      ),
    );
  }
}

/// [alerts] as callouts, most urgent first, each with a call button when
/// it is an emergency.
class AncAlertList extends StatelessWidget {
  const AncAlertList({super.key, required this.alerts});

  final List<AncAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, a) in alerts.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          AncAlertCallout(title: a.title, body: a.body, level: a.level),
        ],
      ],
    );
  }
}

class AncAlertCallout extends StatelessWidget {
  const AncAlertCallout({super.key, required this.title, required this.body, required this.level});

  final String title;
  final String body;
  final AncLevel level;

  static PTone toneOf(AncLevel level) => switch (level) {
        AncLevel.urgent => PTone.red,
        AncLevel.soon => PTone.warn,
        AncLevel.ask => PTone.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PCallout(tone: toneOf(level), title: title, body: body),
        if (level == AncLevel.urgent) ...[
          const SizedBox(height: 8),
          const EmergencyCallButton(),
        ],
      ],
    );
  }
}

/// Dials 999 (112 works too). If the phone can't start a call, says so.
class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({super.key});

  Future<void> _call(BuildContext context) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '999'))) return;
    } catch (e) {
      debugPrint('Could not start a call: $e');
    }
    if (context.mounted) pToast(context, 'Could not start a call. Dial 999 or 112 yourself.');
  }

  @override
  Widget build(BuildContext context) {
    return PButton('Call 999', kind: PButtonKind.red, icon: Icons.phone_rounded, onPressed: () => _call(context));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// No pregnancy yet
// ═══════════════════════════════════════════════════════════════════════

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: PEmpty(
        emoji: '🤰',
        title: 'Tell us about your pregnancy',
        body: "Add the first day of your last period, or your due date from a scan, and we'll show "
            'how far along you are, when your baby is due, and which antenatal visits are next.',
        action: PButton('Get started', onPressed: onStart),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Progress — the hero
// ═══════════════════════════════════════════════════════════════════════

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.pregnancy, required this.visitsDone, required this.today});

  final Pregnancy pregnancy;
  final int visitsDone;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final weeks = pregnancy.weeksOn(today);
    final daysToDue = pregnancy.daysToDueOn(today);
    final title = daysToDue < 0
        ? 'Week $weeks · past your due date'
        : 'Week $weeks · ${Pregnancy.trimesterName(pregnancy.trimesterOn(today))}';

    return PHero(
      chip: 'PREGNANCY PROGRESS',
      title: title,
      body: _visitsLine(weeks, daysToDue),
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PT.rPill),
            child: LinearProgressIndicator(
              value: pregnancy.progressOn(today),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              semanticsLabel: 'Pregnancy progress',
              semanticsValue: 'Week $weeks of 40',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 34,
            runSpacing: 12,
            children: [
              _HeroStat(
                label: 'DUE DATE',
                value: DateFormat('d MMMM yyyy').format(pregnancy.dueDate),
                note: pregnancy.dueDateSource == 'lmp' ? null : 'From ${pregnancy.dueDateSource == 'scan' ? 'a scan' : 'your clinic'}',
              ),
              _HeroStat(
                label: daysToDue < 0 ? 'DAYS PAST' : 'DAYS TO GO',
                value: '${daysToDue.abs()}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _visitsLine(int weeks, int daysToDue) {
    if (daysToDue < 0) {
      return 'Your due date has passed, which is common. Keep going to your clinic as they advise: '
          'most babies arrive by 42 weeks.';
    }
    final toGo = Pregnancy.contactsToGo(visitsDone);
    final next = Pregnancy.nextContactWeekAfter(weeks);
    final nextLine = next == null ? '' : ' Next one is usually around week $next.';
    if (visitsDone == 0) {
      return 'No antenatal visits recorded yet. Eight are recommended, the first by week 12.$nextLine';
    }
    final done = '$visitsDone antenatal ${visitsDone == 1 ? 'visit' : 'visits'} done';
    if (toGo == 0) return '$done. That covers the eight recommended visits.';
    return '$done, $toGo to go.$nextLine';
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PT.label().copyWith(color: Colors.white70, letterSpacing: .5, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: PT.body().copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        if (note != null) Text(note!, style: PT.label().copyWith(color: Colors.white70)),
      ],
    );
  }
}

/// Readings from her visits that still need attention: the latest of
/// each kind, until a newer normal one replaces it.
class _StandingAlerts extends StatelessWidget {
  const _StandingAlerts({required this.visits});

  final List<AncVisit> visits;

  @override
  Widget build(BuildContext context) {
    final standing = AncReadingChecks.standing(visits);
    if (standing.isEmpty) return const SizedBox(height: 0);
    final fmt = DateFormat('d MMMM');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          for (final (i, s) in standing.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            AncAlertCallout(
              title: '${s.alert.badge} · visit on ${fmt.format(s.visit.visitDate.toLocal())}',
              body: s.alert.later,
              level: s.alert.level,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeekCareCallout extends StatelessWidget {
  const _SeekCareCallout();

  @override
  Widget build(BuildContext context) {
    return const PCallout(
      tone: PTone.red,
      title: 'When to seek care straight away',
      body: 'Severe headache or blurred vision, bleeding, severe abdominal pain, your baby moving less, '
          'fits, or difficulty breathing.',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Visits
// ═══════════════════════════════════════════════════════════════════════

class _VisitList extends StatelessWidget {
  const _VisitList({required this.pregnancy, required this.visits, required this.onAdd});

  final Pregnancy pregnancy;

  /// Newest first.
  final List<AncVisit> visits;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return PCard(
        child: PEmpty(
          emoji: '🩺',
          title: 'No visits recorded yet',
          body: 'After each antenatal visit, add what was checked so it is all in one place.',
          action: PButton('Add a visit', kind: PButtonKind.alt, onPressed: onAdd),
        ),
      );
    }
    return PCard(
      child: Column(children: [
        // Numbered and dated from today's facts, not what was stored when
        // each visit was saved: a visit added late (with an earlier date)
        // used to take the next number, and changing the pregnancy dates
        // left every old visit at its old week.
        for (final (i, v) in visits.indexed)
          _VisitRow(
            visit: v,
            number: visits.length - i,
            weeks: pregnancy.weeksOn(v.visitDate.toLocal()),
            alerts: AncReadingChecks.forVisit(v, previous: AncReadingChecks.previousOf(v, visits)),
          ),
      ]),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.number, required this.weeks, required this.alerts});

  final AncVisit visit;
  final int number;
  final int weeks;

  /// What this visit's readings called for, so a worrying reading never
  /// looks like a normal one.
  final List<AncAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final when = visit.visitDate.toLocal();
    final checks = [
      if (visit.systolicBP != null && visit.diastolicBP != null) 'BP ${visit.systolicBP}/${visit.diastolicBP}',
      if (visit.weight != null) 'Weight ${_num(visit.weight!)} kg',
      if (visit.hemoglobin != null) 'Hb ${_num(visit.hemoglobin!)}',
      if (visit.fetalHeartRate != null) 'Baby\'s heart ${visit.fetalHeartRate}',
      if (visit.fundalHeight != null) 'Fundal height ${_num(visit.fundalHeight!)} cm',
    ];
    return PRow(
      leading: _DateBox(date: when),
      title: 'Visit $number · $weeks weeks',
      subtitle: checks.isEmpty ? 'No measurements recorded' : checks.join(' · '),
      extraSubtitle: visit.facility.trim().isEmpty ? null : visit.facility.trim(),
      below: alerts.isEmpty && visit.dangerSigns.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in alerts) PBadge(a.badge, tone: AncAlertCallout.toneOf(a.level)),
                      ],
                    ),
                  ),
                if (visit.dangerSigns.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Noted: ${visit.dangerSigns.join(', ')}', style: PT.rowSub().copyWith(color: PT.danger)),
                ],
              ],
            ),
    );
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: PT.badgeWarnBg, borderRadius: BorderRadius.circular(13)),
      child: Column(
        children: [
          Text('${date.day}', style: PT.serif(fontSize: 22, color: PT.badgeWarnFg, height: 1)),
          const SizedBox(height: 3),
          Text(DateFormat('MMM').format(date).toUpperCase(),
              style: PT.badge().copyWith(color: PT.badgeWarnFg, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.pregnancy, required this.visits});

  final Pregnancy pregnancy;
  final int visits;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final ended = pregnancy.endedOn == null ? null : 'Ended ${fmt.format(pregnancy.endedOn!)}';
    final how = pregnancy.outcome == null || pregnancy.outcome == 'not_said'
        ? null
        : Pregnancy.outcomes[pregnancy.outcome];
    return PRow(
      leadingEmoji: '🤍',
      title: 'Due ${fmt.format(pregnancy.dueDate)}',
      subtitle: [ended, how, '$visits ${visits == 1 ? 'visit' : 'visits'}'].whereType<String>().join(' · '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Add a visit
// ═══════════════════════════════════════════════════════════════════════

/// Pops the danger signs noted (possibly empty) once saved.
class _VisitForm extends StatefulWidget {
  const _VisitForm({required this.pregnancy});

  final Pregnancy pregnancy;

  @override
  State<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<_VisitForm> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _weight = TextEditingController();
  final _hb = TextEditingController();
  final _fhr = TextEditingController();
  final _fundal = TextEditingController();
  final _facility = TextEditingController();
  final _notes = TextEditingController();
  final Set<String> _signs = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The warnings follow the readings as they are typed.
    for (final c in [_sys, _dia, _weight, _hb, _fhr, _fundal]) {
      c.addListener(_readingsChanged);
    }
  }

  void _readingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_sys, _dia, _weight, _hb, _fhr, _fundal, _facility, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The number in [c] if it is a sensible one, else null. Used for the
  /// live warnings, which say nothing about half-typed or mistyped numbers
  /// (saving explains those).
  double? _peek(TextEditingController c, double min, double max) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v < min || v > max ? null : v;
  }

  /// Her visit before [date] in this pregnancy, for the weight check.
  AncVisit? _previousVisit(DateTime date) {
    AncVisit? best;
    for (final v in context.read<PregnancyProvider>().visitsOf(widget.pregnancy)) {
      if (!DateUtils.dateOnly(v.visitDate.toLocal()).isBefore(date)) continue;
      if (best == null || v.visitDate.isAfter(best.visitDate)) best = v;
    }
    return best;
  }

  List<AncAlert> _alerts() {
    final sys = _peek(_sys, 60, 250)?.round();
    final dia = _peek(_dia, 30, 150)?.round();
    final bpOk = sys != null && dia != null && sys > dia;
    return AncReadingChecks.check(
      weeks: widget.pregnancy.weeksOn(_date),
      systolic: bpOk ? sys : null,
      diastolic: bpOk ? dia : null,
      hb: _peek(_hb, 3, 25),
      babyHeartRate: _peek(_fhr, 60, 220)?.round(),
      fundalHeight: _peek(_fundal, 5, 50),
      weight: _peek(_weight, 25, 250),
      date: _date,
      previous: _previousVisit(_date),
      dangerSigns: AncVisit.dangerSignsList.where(_signs.contains).toList(),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = widget.pregnancy.datingStart;
    final picked = await showDatePicker(
      context: context,
      helpText: 'Date of the visit',
      initialDate: _date,
      firstDate: start.isAfter(today) ? today : start,
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// The number typed into [c], or null when empty. Sets [_error] and
  /// returns double.nan when it is not a number in [min]..[max].
  double? _read(TextEditingController c, String what, double min, double max) {
    final text = c.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    if (v == null || v < min || v > max) {
      _error ??= '$what should be a number between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
      return double.nan;
    }
    return v;
  }

  Future<void> _save() async {
    _error = null;
    final sys = _read(_sys, 'Top blood pressure number', 60, 250);
    final dia = _read(_dia, 'Bottom blood pressure number', 30, 150);
    final weight = _read(_weight, 'Weight', 25, 250);
    final hb = _read(_hb, 'Hb', 3, 25);
    final fhr = _read(_fhr, "Baby's heart rate", 60, 220);
    final fundal = _read(_fundal, 'Fundal height', 5, 50);
    if (_error == null && (sys == null) != (dia == null)) {
      _error = 'Enter both blood pressure numbers, or neither.';
    }
    if (_error == null && sys != null && dia != null && sys <= dia) {
      _error = 'The top blood pressure number should be bigger than the bottom one. '
          'Check you have not swapped them.';
    }
    if (_error != null) {
      setState(() {});
      return;
    }

    // Worked out before saving: the visit is then one of "her visits",
    // and would otherwise be compared with itself.
    final alerts = _alerts();
    setState(() => _saving = true);
    final pregnancies = context.read<PregnancyProvider>();
    // A visit today is stamped with the current time; an earlier one at
    // midday, so the calendar day survives any time-zone conversion.
    final now = DateTime.now();
    final when = DateUtils.isSameDay(_date, now) ? now : DateTime(_date.year, _date.month, _date.day, 12);
    final ok = await pregnancies.addVisit(
      visitDate: when,
      systolicBP: sys?.round(),
      diastolicBP: dia?.round(),
      weight: weight,
      hemoglobin: hb,
      fetalHeartRate: fhr?.round(),
      fundalHeight: fundal,
      facility: _facility.text.trim(),
      dangerSigns: AncVisit.dangerSignsList.where(_signs.contains).toList(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, alerts);
    } else {
      setState(() {
        _saving = false;
        _error = pregnancies.error;
      });
    }
  }

  Widget _number(String label, TextEditingController c, {String? hint}) {
    return PField(
      label: label,
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: pInput(hint: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeks = widget.pregnancy.weeksOn(_date);
    final alerts = _alerts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add what was checked. Leave out anything that wasn\'t.', style: PT.sub()),
        const SizedBox(height: 15),
        PField(
          label: 'Date of the visit',
          child: PButton(
            '${DateFormat('d MMMM yyyy').format(_date)} · $weeks weeks',
            kind: PButtonKind.alt,
            icon: Icons.event_outlined,
            onPressed: _saving ? null : _pickDate,
          ),
        ),
        const SizedBox(height: 11),
        PFormGrid([
          _number('Blood pressure, top number', _sys, hint: '110'),
          _number('Blood pressure, bottom number', _dia, hint: '70'),
          _number('Weight (kg)', _weight, hint: '66'),
          _number('Hb (g/dL)', _hb, hint: '11.5'),
          _number("Baby's heart rate (per minute)", _fhr, hint: '145'),
          _number('Fundal height (cm)', _fundal, hint: '24'),
        ]),
        const SizedBox(height: 11),
        PField(
          label: 'Clinic or hospital',
          child: TextField(controller: _facility, decoration: pInput(hint: 'Where you were seen')),
        ),
        const SizedBox(height: 15),
        Text('Any danger signs since your last visit?', style: PT.rowTitle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sign in AncVisit.dangerSignsList)
              PChoicePill(
                label: sign,
                selected: _signs.contains(sign),
                onTap: () => setState(() => _signs.contains(sign) ? _signs.remove(sign) : _signs.add(sign)),
              ),
          ],
        ),
        const SizedBox(height: 15),
        PField(
          label: 'Notes',
          child: TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: pInput(hint: 'Anything your clinic told you'),
          ),
        ),
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 15),
          AncAlertList(alerts: alerts),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Saving…' : 'Save visit', onPressed: _saving ? null : _save),
        ),
      ],
    );
  }
}
