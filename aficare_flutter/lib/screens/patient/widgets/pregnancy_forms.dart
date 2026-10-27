import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/pregnancy_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pregnancy_provider.dart';
import '../../../theme/patient_tokens.dart';
import 'patient_ui.dart';

/// Starting (or correcting the dates of) a pregnancy, and closing one.
/// Shared by Maternal care and Women's health, which both work on the
/// same record (see [PregnancyProvider]).

/// Asks when the pregnancy started and saves it. With [editing], changes
/// that pregnancy's dates instead. Returns true when saved.
Future<bool> showPregnancyDatesForm(BuildContext context, {Pregnancy? editing}) async {
  final saved = await showPModal<bool>(
    context: context,
    title: editing == null ? 'Tell us about your pregnancy' : 'Change your dates',
    builder: (_) => _DatesForm(editing: editing),
  );
  return saved ?? false;
}

/// Closes [pregnancy]. [outcome] skips the question (a birth, when she
/// has just said she had her baby). Returns true when saved.
Future<bool> showEndPregnancyForm(BuildContext context, Pregnancy pregnancy, {String? outcome}) async {
  final saved = await showPModal<bool>(
    context: context,
    title: outcome == 'birth' ? 'Congratulations' : 'Your pregnancy has ended',
    builder: (_) => _EndForm(pregnancy: pregnancy, presetOutcome: outcome),
  );
  return saved ?? false;
}

// ── Dates ──────────────────────────────────────────────────────────────

class _DatesForm extends StatefulWidget {
  const _DatesForm({this.editing});

  final Pregnancy? editing;

  @override
  State<_DatesForm> createState() => _DatesFormState();
}

class _DatesFormState extends State<_DatesForm> {
  /// true: she knows the first day of her last period; false: she has a
  /// due date from a scan or her clinic.
  late bool _fromLmp = widget.editing == null || widget.editing!.dueDateSource == 'lmp';
  late DateTime? _lmp = widget.editing?.lmpDate;
  late DateTime? _due = widget.editing?.dueDateSource == 'lmp' ? null : widget.editing?.dueDate;
  late String _source = widget.editing?.dueDateSource == 'clinician' ? 'clinician' : 'scan';
  bool _saving = false;
  String? _error;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  Future<void> _pick() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      helpText: _fromLmp ? 'First day of your last period' : 'Your due date',
      initialDate: _fromLmp
          ? (_lmp ?? today.subtract(const Duration(days: 56)))
          : (_due ?? today.add(const Duration(days: 180))),
      firstDate: _fromLmp ? today.subtract(const Duration(days: 44 * 7)) : today.subtract(const Duration(days: 28)),
      lastDate: _fromLmp ? today : today.add(const Duration(days: 42 * 7)),
    );
    if (picked == null) return;
    setState(() {
      if (_fromLmp) {
        _lmp = picked;
      } else {
        _due = picked;
      }
      _error = null;
    });
  }

  /// What the chosen date works out to, or null when none is chosen.
  Pregnancy? get _preview {
    if (_fromLmp && _lmp != null) {
      return Pregnancy(id: '', patientId: '', lmpDate: _lmp, dueDate: Pregnancy.dueDateFromLmp(_lmp!));
    }
    if (!_fromLmp && _due != null) {
      return Pregnancy(id: '', patientId: '', dueDate: _due!, dueDateSource: _source);
    }
    return null;
  }

  Future<void> _save() async {
    final today = _today;
    final problem = _fromLmp
        ? (_lmp == null ? 'Choose the first day of your last period.' : Pregnancy.checkLmp(_lmp!, today))
        : (_due == null ? 'Choose your due date.' : Pregnancy.checkDueDate(_due!, today));
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final pregnancies = context.read<PregnancyProvider>();
    final userId = context.read<AuthProvider>().currentUser?.id;
    final bool ok;
    if (widget.editing != null) {
      ok = await pregnancies.updateDates(
        widget.editing!,
        lmp: _fromLmp ? _lmp : null,
        dueDate: _fromLmp ? null : _due,
        dueDateSource: _source,
      );
    } else if (userId == null) {
      ok = false;
    } else {
      ok = await pregnancies.start(
        patientId: userId,
        lmp: _fromLmp ? _lmp : null,
        dueDate: _fromLmp ? null : _due,
        dueDateSource: _source,
      );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = pregnancies.error ?? 'Please log in again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMMM yyyy');
    final chosen = _fromLmp ? _lmp : _due;
    final preview = _preview;
    final today = _today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.editing == null
              ? 'We use this to work out how far along you are and when your baby is due. '
                  'You can change it later, for example after a scan.'
              : 'A scan often gives a more exact due date. Use whichever your clinic goes by.',
          style: PT.sub(),
        ),
        const SizedBox(height: 15),
        Text('What do you know?', style: PT.rowTitle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PChoicePill(
              label: 'The first day of my last period',
              selected: _fromLmp,
              onTap: () => setState(() {
                _fromLmp = true;
                _error = null;
              }),
            ),
            PChoicePill(
              label: 'My due date',
              selected: !_fromLmp,
              onTap: () => setState(() {
                _fromLmp = false;
                _error = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 15),
        PField(
          label: _fromLmp ? 'First day of your last period' : 'Your due date',
          child: PButton(
            chosen == null ? 'Choose a date' : fmt.format(chosen),
            kind: PButtonKind.alt,
            icon: Icons.event_outlined,
            onPressed: _saving ? null : _pick,
          ),
        ),
        if (!_fromLmp) ...[
          const SizedBox(height: 15),
          Text('Who gave you this date?', style: PT.rowTitle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PChoicePill(label: 'A scan', selected: _source == 'scan', onTap: () => setState(() => _source = 'scan')),
              PChoicePill(
                label: 'My doctor or midwife',
                selected: _source == 'clinician',
                onTap: () => setState(() => _source = 'clinician'),
              ),
            ],
          ),
        ],
        if (preview != null) ...[
          const SizedBox(height: 15),
          PCallout(
            body: 'That makes you ${_weeksText(preview, today)} today, '
                'with your baby due around ${fmt.format(preview.dueDate)}.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
        ),
      ],
    );
  }
}

/// "24 weeks and 3 days", "1 week", "6 days".
String _weeksText(Pregnancy p, DateTime today) {
  final w = p.weeksOn(today);
  final d = p.extraDaysOn(today);
  final weeks = '$w ${w == 1 ? 'week' : 'weeks'}';
  final days = '$d ${d == 1 ? 'day' : 'days'}';
  if (w == 0) return days;
  if (d == 0) return weeks;
  return '$weeks and $days';
}

// ── Ending ─────────────────────────────────────────────────────────────

class _EndForm extends StatefulWidget {
  const _EndForm({required this.pregnancy, this.presetOutcome});

  final Pregnancy pregnancy;
  final String? presetOutcome;

  @override
  State<_EndForm> createState() => _EndFormState();
}

class _EndFormState extends State<_EndForm> {
  late String? _outcome = widget.presetOutcome;
  DateTime _endedOn = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;
  String? _error;

  Future<void> _pick() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = widget.pregnancy.datingStart;
    final picked = await showDatePicker(
      context: context,
      helpText: 'When did it end?',
      initialDate: _endedOn,
      firstDate: start.isAfter(today) ? today : start,
      lastDate: today,
    );
    if (picked != null) setState(() => _endedOn = picked);
  }

  Future<void> _save() async {
    if (_outcome == null) {
      setState(() => _error = 'Choose one, or "I\'d rather not say".');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final pregnancies = context.read<PregnancyProvider>();
    final ok = await pregnancies.end(widget.pregnancy, outcome: _outcome!, endedOn: _endedOn);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = pregnancies.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final birth = widget.presetOutcome == 'birth';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          birth
              ? "We'll close your pregnancy record. Your visits stay in your history."
              : "We're sorry if this is a hard time. We'll close your pregnancy record, and your "
                  'visits stay in your history. You only need to tell us what you want to.',
          style: PT.sub(),
        ),
        if (!birth) ...[
          const SizedBox(height: 15),
          Text('What happened?', style: PT.rowTitle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in Pregnancy.outcomes.entries)
                PChoicePill(
                  label: e.value,
                  selected: _outcome == e.key,
                  onTap: () => setState(() {
                    _outcome = e.key;
                    _error = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 15),
        PField(
          label: birth ? 'Date of birth' : 'When it ended',
          child: PButton(
            DateFormat('d MMMM yyyy').format(_endedOn),
            kind: PButtonKind.alt,
            icon: Icons.event_outlined,
            onPressed: _saving ? null : _pick,
          ),
        ),
        if (_outcome == 'loss') ...[
          const SizedBox(height: 15),
          const PCallout(
            body: 'After a pregnancy loss, heavy bleeding, fever or strong pain are reasons to be seen '
                'straight away. Feeling low is common too, and support helps.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
        ),
      ],
    );
  }
}
