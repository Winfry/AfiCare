import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/active_patient.dart';
import '../../models/medication_reminder_model.dart';
import '../../services/medication_reminder_service.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key});

  @override
  State<MedicationReminderScreen> createState() => _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  final _service = MedicationReminderService();
  List<MedicationReminder> _reminders = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  /// The reminder whose Pause / Turn on / Delete is in flight, so its
  /// buttons can't be pressed twice.
  String? _busyId;

  /// Whose reminders are loaded, so switching profile reloads instead of
  /// leaving the previous person's list on screen.
  String? _loadedFor;

  ActivePatient get _subject => ActivePatient.of(context);

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final subject = _subject;
    if (subject.id.isNotEmpty && subject.id != _loadedFor) {
      _loadedFor = subject.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadReminders();
      });
    }
  }

  Future<void> _loadReminders() async {
    // Reminders follow the active profile: a parent setting a reminder
    // for their child's syrup should not file it against themselves.
    final patientId = ActivePatient.of(context, listen: false).id;
    if (patientId.isEmpty) return;

    try {
      final reminders = await _service.fetchReminders(patientId);
      if (mounted) {
        setState(() {
          _reminders = reminders;
          _loadFailed = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      // Keep whatever was already on screen; an empty list here would
      // read as "your reminders are gone".
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggle(MedicationReminder r) async {
    setState(() => _busyId = r.id);
    final turningOn = !r.isActive;
    final subject = ActivePatient.of(context, listen: false);
    final ok = await _service.toggleReminder(r.id, turningOn,
        reminder: r, personName: subject.isDependent ? subject.firstName : null);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok) {
      pToast(context, turningOn ? '${r.medicationName} reminder is on' : '${r.medicationName} reminder paused');
      _loadReminders();
    } else {
      pToast(context, "Couldn't change that. Check your connection and try again.");
    }
  }

  Future<void> _delete(MedicationReminder r) async {
    final confirmed = await showPModal<bool>(
      context: context,
      title: 'Delete this reminder?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "The ${r.medicationName} reminder will stop. This doesn't change your prescription "
            'or remove the medicine from your list.',
            style: PT.sub(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PButton('Keep it', kind: PButtonKind.alt, onPressed: () => Navigator.pop(ctx, false)),
              const SizedBox(width: 8),
              PButton('Delete', kind: PButtonKind.red, onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = r.id);
    final ok = await _service.deleteReminder(r.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok) {
      pToast(context, '${r.medicationName} reminder deleted');
      _loadReminders();
    } else {
      pToast(context, "Couldn't delete that. Check your connection and try again.");
    }
  }

  Future<void> _add() async {
    // Captured now so the reminder is filed against the profile that was
    // on screen when Add was tapped.
    final subject = ActivePatient.of(context, listen: false);
    if (subject.id.isEmpty) return;

    final permissionGranted = await showPModal<bool>(
      context: context,
      title: subject.isDependent ? 'New reminder for ${subject.firstName}' : 'New reminder',
      builder: (ctx) => _ReminderForm(
        patientId: subject.id,
        personName: subject.isDependent ? subject.firstName : null,
        service: _service,
      ),
    );
    if (permissionGranted == null || !mounted) return;

    pToast(
      context,
      kIsWeb
          ? 'Reminder saved. It will ring on a phone with the AfiCare app.'
          : permissionGranted
              ? 'Reminder saved'
              : "Reminder saved, but AfiCare can't send notifications. Turn them on in your phone's settings.",
    );
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    final subject = _subject;
    final active = _reminders.where((r) => r.isActive).toList();
    final paused = _reminders.where((r) => !r.isActive).toList();

    return PSliverPage(
      eyebrow: 'A small nudge',
      title: subject.isDependent ? "${subject.firstName}'s reminders" : 'Medicine reminders',
      subtitle: 'Set to the times you actually take things, not the times a form suggested.',
      action: PButton('Add a reminder', icon: Icons.add, onPressed: _add),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A browser can't ring at 8 am with the tab closed, and
              // saying nothing would let someone rely on it.
              if (kIsWeb) ...[
                const PCallout(
                  tone: PTone.warn,
                  title: "Reminders don't ring in a browser",
                  body: "They're saved here, and will ring on a phone that has the AfiCare app "
                      'and is signed in to this account.',
                ),
                const SizedBox(height: 16),
              ],
              if (_loadFailed) ...[
                PLoadError(
                  what: subject.isDependent ? "${subject.firstName}'s reminders" : 'your reminders',
                  onRetry: _loadReminders,
                ),
                const SizedBox(height: 16),
              ],
              if (_reminders.isEmpty && !_loadFailed)
                PCard(
                  child: PEmpty(
                    emoji: '⏰',
                    title: 'No reminders yet',
                    body: 'Add one for each medicine, at the times you really take it.',
                    action: PButton('Add a reminder', icon: Icons.add, onPressed: _add),
                  ),
                ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 13),
                PHeading('Your reminders', action: PBadge('${active.length} on', tone: PTone.ok)),
                _ReminderList(
                  reminders: active,
                  busyId: _busyId,
                  onToggle: _toggle,
                  onDelete: _delete,
                ),
              ],
              if (paused.isNotEmpty) ...[
                const SizedBox(height: 29),
                PHeading('Paused', action: PBadge('${paused.length} off', tone: PTone.warn)),
                _ReminderList(
                  reminders: paused,
                  busyId: _busyId,
                  onToggle: _toggle,
                  onDelete: _delete,
                ),
              ],
              const SizedBox(height: 29),
              const PHeading('How these reach you'),
              PCard(
                child: Text(
                  kIsWeb
                      ? "On a phone with the AfiCare app, reminders arrive even when the app is closed. "
                          "Pausing one doesn't remove the medicine from your list."
                      : "Reminders arrive on this phone even when AfiCare is closed. "
                          "Pausing one doesn't remove the medicine from your list.",
                  style: PT.sub().copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Reminder rows
// ═══════════════════════════════════════════════════════════════════════

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.reminders,
    required this.busyId,
    required this.onToggle,
    required this.onDelete,
  });

  final List<MedicationReminder> reminders;
  final String? busyId;
  final ValueChanged<MedicationReminder> onToggle;
  final ValueChanged<MedicationReminder> onDelete;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          for (final r in reminders)
            _ReminderRow(
              reminder: r,
              busy: busyId == r.id,
              onToggle: () => onToggle(r),
              onDelete: () => onDelete(r),
            ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
  });

  final MedicationReminder reminder;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final dosage = r.dosage.trim();
    final when = r.frequency == 'as_needed'
        ? 'As needed'
        : [
            MedicationReminder.frequencyLabel(r.frequency),
            r.times.map((t) => t.formatted).join(', '),
          ].where((s) => s.isNotEmpty).join(' · ');

    final controls = <Widget>[
      PBadge(r.isActive ? 'On' : 'Paused', tone: r.isActive ? PTone.ok : PTone.warn),
      PButton(
        busy ? '…' : (r.isActive ? 'Pause' : 'Turn on'),
        kind: PButtonKind.alt,
        dense: true,
        onPressed: busy ? null : onToggle,
      ),
      IconButton(
        tooltip: 'Delete reminder',
        onPressed: busy ? null : onDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: PT.muted),
        visualDensity: VisualDensity.compact,
      ),
    ];

    // Three controls beside the name squeeze it to nothing on a phone,
    // so there they sit on their own line underneath.
    final mobile = PT.isMobile(context);
    return PRow(
      leading: PSoftIcon(r.isActive ? Icons.alarm_rounded : Icons.alarm_off_rounded),
      title: dosage.isEmpty ? r.medicationName : '${r.medicationName} · $dosage',
      subtitle: when,
      trailing: mobile ? const [] : controls,
      below: mobile
          ? Padding(
              padding: const EdgeInsets.only(left: 53),
              child: Row(
                children: [
                  controls[0],
                  const Spacer(),
                  controls[1],
                  const SizedBox(width: 4),
                  controls[2],
                ],
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// New reminder (inside showPModal). Pops with whether notifications are
// allowed once saved, or stays open showing the problem if not saved.
// ═══════════════════════════════════════════════════════════════════════

class _ReminderForm extends StatefulWidget {
  const _ReminderForm({required this.patientId, this.personName, required this.service});

  final String patientId;

  /// The dependant's first name when it's their medicine, so the alarm
  /// says whose it is.
  final String? personName;
  final MedicationReminderService service;

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  static const _frequencies = [
    ('once_daily', 'Once a day'),
    ('twice_daily', 'Twice a day'),
    ('three_times', '3 times a day'),
    ('four_times', '4 times a day'),
    ('as_needed', 'As needed'),
  ];

  /// Starting times for each frequency; the person can change any of them.
  static List<ReminderTime> _defaultTimes(String frequency) => switch (frequency) {
        'twice_daily' => [ReminderTime(hour: 8, minute: 0), ReminderTime(hour: 20, minute: 0)],
        'three_times' => [
            ReminderTime(hour: 8, minute: 0),
            ReminderTime(hour: 14, minute: 0),
            ReminderTime(hour: 20, minute: 0),
          ],
        'four_times' => [
            ReminderTime(hour: 8, minute: 0),
            ReminderTime(hour: 12, minute: 0),
            ReminderTime(hour: 17, minute: 0),
            ReminderTime(hour: 22, minute: 0),
          ],
        // No alarm: a medicine taken only when needed shouldn't ring daily.
        'as_needed' => [],
        _ => [ReminderTime(hour: 8, minute: 0)],
      };

  final _name = TextEditingController();
  final _dosage = TextEditingController();
  String _frequency = 'once_daily';
  List<ReminderTime> _times = _defaultTimes('once_daily');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int? index) async {
    final current = index == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay(hour: _times[index].hour, minute: _times[index].minute);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final t = ReminderTime(hour: picked.hour, minute: picked.minute);
    setState(() => index == null ? _times.add(t) : _times[index] = t);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Add the name of the medicine.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final permissionGranted = await widget.service.requestPermission();
    final saved = await widget.service.saveReminder(
      patientId: widget.patientId,
      personName: widget.personName,
      medicationName: _name.text.trim(),
      dosage: _dosage.text.trim(),
      frequency: _frequency,
      times: _times,
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, permissionGranted);
    } else {
      setState(() {
        _saving = false;
        _error = "Couldn't save this reminder. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asNeeded = _frequency == 'as_needed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PFormGrid([
          PField(
            label: 'Medicine',
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: pInput(hint: 'e.g. Metformin'),
            ),
          ),
          PField(
            label: 'Dose (optional)',
            child: TextField(controller: _dosage, decoration: pInput(hint: 'e.g. 500 mg')),
          ),
        ]),
        const SizedBox(height: 18),
        Text('How often', style: PT.label().copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _frequencies)
              PChoicePill(
                label: f.$2,
                selected: _frequency == f.$1,
                onTap: () => setState(() {
                  _frequency = f.$1;
                  _times = _defaultTimes(f.$1);
                }),
              ),
          ],
        ),
        if (!asNeeded) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Remind me at', style: PT.label().copyWith(fontSize: 11))),
              TextButton.icon(
                onPressed: () => _pickTime(null),
                icon: const Icon(Icons.add, size: 16, color: PT.teal),
                label: Text('Add a time', style: PT.button().copyWith(color: PT.teal, fontSize: 13)),
              ),
            ],
          ),
          for (int i = 0; i < _times.length; i++)
            PRow(
              leading: const PSoftIcon(Icons.alarm_rounded, size: 36),
              title: _times[i].formatted,
              subtitle: _times[i].shortLabel,
              trailing: [
                PButton('Change', kind: PButtonKind.alt, dense: true, onPressed: () => _pickTime(i)),
                if (_times.length > 1)
                  IconButton(
                    tooltip: 'Remove this time',
                    onPressed: () => setState(() => _times.removeAt(i)),
                    icon: const Icon(Icons.close_rounded, size: 18, color: PT.muted),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Saving…' : 'Save reminder', onPressed: _saving ? null : _save),
        ),
      ],
    );
  }
}
