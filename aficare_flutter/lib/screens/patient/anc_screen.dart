import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
        if (pregnancies.error != null && pregnancies.pregnancies.isEmpty)
          PLoadError(what: 'your pregnancy record', onRetry: _load)
        else if (current == null)
          _StartCard(onStart: _start)
        else ...[
          _ProgressHero(pregnancy: current, visitsDone: pregnancies.visitsOf(current).length, today: today),
          const _SeekCareCallout(),
          const SizedBox(height: 22),
          const PHeading('Antenatal visits'),
          _VisitList(visits: pregnancies.visitsOf(current), onAdd: () => _addVisit(current)),
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
    final dangerSigns = await showPModal<List<String>>(
      context: context,
      title: 'Add a visit',
      builder: (_) => _VisitForm(pregnancy: p),
    );
    if (dangerSigns == null || !mounted) return;
    pToast(
      context,
      dangerSigns.isEmpty
          ? 'Visit saved.'
          : 'Visit saved. You noted danger signs: if you have not been seen for them yet, get care today.',
    );
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
  const _VisitList({required this.visits, required this.onAdd});

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
      child: Column(children: [for (final v in visits) _VisitRow(visit: v)]),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final AncVisit visit;

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
      title: 'Visit ${visit.visitNumber} · ${visit.gestationalWeeks} weeks',
      subtitle: checks.isEmpty ? 'No measurements recorded' : checks.join(' · '),
      extraSubtitle: visit.facility.trim().isEmpty ? null : visit.facility.trim(),
      trailing: [if (visit.dangerSigns.isNotEmpty) const PBadge('Danger signs', tone: PTone.red)],
      below: visit.dangerSigns.isEmpty
          ? null
          : Text('Noted: ${visit.dangerSigns.join(', ')}', style: PT.rowSub().copyWith(color: PT.danger)),
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
  void dispose() {
    for (final c in [_sys, _dia, _weight, _hb, _fhr, _fundal, _facility, _notes]) {
      c.dispose();
    }
    super.dispose();
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
    if (_error != null) {
      setState(() {});
      return;
    }

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
      Navigator.pop(context, _signs.toList());
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
        if (_signs.isNotEmpty) ...[
          const SizedBox(height: 12),
          const PCallout(
            tone: PTone.red,
            body: 'If you have not been seen for these yet, please get care today. Call 999 or go to the '
                'nearest facility if it is severe.',
          ),
        ],
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
