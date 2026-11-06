import 'package:flutter/material.dart';
import '../../theme/patient_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/active_patient.dart';
import '../../theme/app_colors.dart';
import '../../models/vaccination_model.dart';
import 'widgets/patient_ui.dart';

class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key});

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final _supabase = Supabase.instance.client;
  List<VaccinationRecord> _records = [];
  bool _isLoading = true;
  DateTime? _dateOfBirth;

  /// Whose records are currently loaded, so a profile switch while this
  /// screen is open reloads instead of leaving the previous person's
  /// card on screen.
  String? _loadedFor;

  /// The active patient, re-resolved on every dependency change.
  ActivePatient get _subject => ActivePatient.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `watch` inside ActivePatient.of means this re-runs when the active
    // profile changes.
    final subject = _subject;
    if (subject.id.isNotEmpty && subject.id != _loadedFor) {
      _loadedFor = subject.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData(subject);
      });
    }
  }

  Future<void> _loadData(ActivePatient subject) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // The active patient, not the account holder: this screen is shown
      // on a dependant profile, and a child's immunisation card is
      // exactly what it is for.
      final patientId = subject.id;
      if (patientId.isEmpty) return;

      // Load records
      final data = await _supabase
          .from('vaccination_records')
          .select()
          .eq('patient_id', patientId)
          .order('date_given', ascending: false);
      _records = (data as List)
          .map((j) => VaccinationRecord.fromJson(j))
          .toList();

      // The schedule is age-based, so it needs this patient's own date of
      // birth. A dependant carries theirs on their profile; only the
      // account holder needs a lookup.
      if (subject.dateOfBirth != null) {
        _dateOfBirth = subject.dateOfBirth;
      } else if (!subject.isDependent) {
        try {
          final patient = await _supabase
              .from('patients')
              .select('date_of_birth')
              .eq('id', patientId)
              .maybeSingle();
          final raw = patient?['date_of_birth'] as String?;
          _dateOfBirth = raw == null ? null : DateTime.tryParse(raw);
        } catch (_) {}
      } else {
        _dateOfBirth = null;
      }
    } catch (e) {
      debugPrint('Error loading vaccination data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Null when the date of birth isn't known: then nothing is called due,
  /// rather than treating everyone as a newborn.
  int? get _ageWeeks {
    final dob = _dateOfBirth;
    if (dob == null) return null;
    return (DateTime.now().difference(dob).inDays / 7).floor();
  }

  bool get _pastChildSchedule {
    final age = _ageWeeks;
    return age != null && age >= VaccinationSchedule.childScheduleEndsWeeks;
  }

  List<String> get _givenNames => VaccinationSchedule.givenNames(_records);

  List<VaccineSchedule> get _dueVaccines =>
      VaccinationSchedule.dueNow(ageWeeks: _ageWeeks, given: _givenNames);

  String get _ageText {
    final weeks = _ageWeeks;
    if (weeks == null) return '—';
    if (weeks < 52) return '$weeks wks';
    final dob = _dateOfBirth!;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    if (years < 2) return '${(weeks / 4.345).floor()} mths';
    return '$years yrs';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    return PSliverPage(
      eyebrow: 'Staying protected',
      // Names the profile, so a parent can tell their own card from
      // their child's at a glance.
      title: _subject.isDependent ? "${_subject.firstName}'s vaccinations" : 'Vaccinations',
      subtitle: "What's been given, and what's due — checked against Kenya's national schedule.",
      action: PButton('Add a record', icon: Icons.add, onPressed: _showAddRecordSheet),
      slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  _buildStatsRow(),
                  const SizedBox(height: 16),

                  if (_ageWeeks == null) ...[
                    PCallout(
                      title: 'Add a date of birth to see what is due',
                      body: _subject.isDependent
                          ? "We need ${_subject.firstName}'s date of birth to check the schedule. You can add it on their profile."
                          : 'We need your date of birth to check the schedule. You can add it on your profile.',
                      tone: PTone.blue,
                    ),
                    const SizedBox(height: 16),
                  ] else if (_pastChildSchedule) ...[
                    PCallout(
                      title: 'This schedule is for young children',
                      body: _subject.isDependent
                          ? "${_subject.firstName} is past the baby and toddler vaccines below. Ask your clinic which vaccines they need at their age."
                          : 'The vaccines below are for babies and toddlers. Ask your clinic which vaccines you need now, for example a tetanus booster, or vaccines before travel or pregnancy.',
                      tone: PTone.blue,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Due Vaccines (if any)
                  if (_dueVaccines.isNotEmpty) ...[
                    const Text('Due / Overdue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFFF57F17))),
                    const SizedBox(height: 8),
                    ...(_dueVaccines.map((v) => _buildDueVaccineCard(v))),
                    const SizedBox(height: 16),
                  ],

                  // Kenya EPI Schedule
                  const Text('Kenya EPI Schedule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    "Kenya's childhood immunisation schedule, birth to 18 months",
                    style: TextStyle(color: PT.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  _buildScheduleList(),

                  const SizedBox(height: 16),

                  // Completed Records
                  if (_records.isNotEmpty) ...[
                    const Text('Completed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_records.map((r) => _buildCompletedCard(r))),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('${_givenNames.length}', 'Completed', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        _statCard('${_dueVaccines.length}', 'Due', Icons.schedule_rounded, const Color(0xFFF57F17)),
        const SizedBox(width: 12),
        _statCard(_ageText, 'Age', Icons.cake_rounded, const Color(0xFF5C6BC0)),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: PT.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDueVaccineCard(VaccineSchedule schedule) {
    final isOverdue =
        VaccinationSchedule.stateFor(schedule, ageWeeks: _ageWeeks, given: _givenNames) == VaccineState.overdue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? const Color(0xFFF57F17).withOpacity(0.4) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isOverdue ? const Color(0xFFF57F17) : const Color(0xFF26A69A)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOverdue ? Icons.warning_rounded : Icons.vaccines_rounded,
              color: isOverdue ? const Color(0xFFF57F17) : const Color(0xFF26A69A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(schedule.description, style: TextStyle(fontSize: 12, color: PT.muted)),
                if (isOverdue)
                  Text('Ask your clinic about a catch-up dose',
                      style: TextStyle(fontSize: 12, color: PT.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFF57F17) : const Color(0xFF26A69A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOverdue ? 'OVERDUE' : 'DUE',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    // Group by age
    final grouped = <String, List<VaccineSchedule>>{};
    for (final v in VaccinationSchedule.kenyaEPI) {
      final key = v.minAgeWeeks == 0
          ? 'Birth'
          : v.minAgeWeeks < 36
              ? '${v.minAgeWeeks} weeks'
              : '${(v.minAgeWeeks / 4).floor()} months';
      grouped.putIfAbsent(key, () => []).add(v);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.mistBackground,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              ...entry.value.map((v) {
                final isGiven = VaccinationSchedule.isGiven(v, _givenNames);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGiven ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isGiven ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.name, style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: isGiven ? TextDecoration.lineThrough : null,
                              color: isGiven ? PT.muted : AppColors.textPrimary,
                            )),
                            Text(v.description, style: TextStyle(
                              fontSize: 11,
                              color: PT.muted,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompletedCard(VaccinationRecord record) {
    // Once the next dose is on the card too, its old "Next" date is done.
    final next = VaccinationSchedule.nextInSeries(record.vaccineName);
    final showNext = record.nextDueDate != null && (next == null || !VaccinationSchedule.isGiven(next, _givenNames));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.vaccineName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '${record.dateGiven.day}/${record.dateGiven.month}/${record.dateGiven.year}',
                  style: TextStyle(fontSize: 12, color: PT.muted),
                ),
                if (record.facility != null && record.facility!.isNotEmpty)
                  Text(record.facility!, style: TextStyle(fontSize: 11, color: PT.muted)),
              ],
            ),
          ),
          if (showNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Next: ${record.nextDueDate!.day}/${record.nextDueDate!.month}/${record.nextDueDate!.year}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF5C6BC0)),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddRecordSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The id is captured here rather than read inside the sheet, so the
      // record is filed against the profile the user was actually looking
      // at when they tapped Add.
      builder: (_) => _AddVaccinationSheet(
        patientId: _subject.id,
        patientName: _subject.isDependent ? _subject.fullName : null,
        dateOfBirth: _dateOfBirth,
        onComplete: () => _loadData(_subject),
      ),
    );
  }
}

class _AddVaccinationSheet extends StatefulWidget {
  final VoidCallback onComplete;
  const _AddVaccinationSheet({
    required this.patientId,
    required this.patientName,
    required this.dateOfBirth,
    required this.onComplete,
  });

  /// Used to work out when the next dose in the series is due.
  final DateTime? dateOfBirth;

  /// Whose card this record belongs to — the active profile, which may be
  /// a dependant.
  final String patientId;

  /// Set only when that profile is a dependant, so the sheet can say
  /// whose card is being added to.
  final String? patientName;

  @override
  State<_AddVaccinationSheet> createState() => _AddVaccinationSheetState();
}

class _AddVaccinationSheetState extends State<_AddVaccinationSheet> {
  final _supabase = Supabase.instance.client;
  String? _selectedVaccine;
  final _facilityCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  final _vaccineOptions = VaccinationSchedule.kenyaEPI
      .map((v) => v.name)
      .toSet()
      .toList()
    ..sort();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName == null
                        ? 'Record Vaccination'
                        : 'Record for ${widget.patientName}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  // Vaccine selector
                  DropdownButtonFormField<String>(
                    value: _selectedVaccine,
                    decoration: InputDecoration(
                      labelText: 'Vaccine',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
                      ),
                    ),
                    items: _vaccineOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _selectedVaccine = v),
                  ),
                  const SizedBox(height: 14),

                  // Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, color: AppColors.canopy),
                    title: const Text('Date Given'),
                    subtitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: widget.dateOfBirth ?? DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Facility
                  TextField(
                    controller: _facilityCtrl,
                    decoration: InputDecoration(
                      labelText: 'Facility',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Batch number
                  TextField(
                    controller: _batchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Batch Number (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting || _selectedVaccine == null ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.canopy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Record', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final patientId = widget.patientId;
    if (patientId.isEmpty) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final schedule = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == _selectedVaccine);
      final nextDue = VaccinationSchedule.nextDueDate(
        schedule.name,
        given: _selectedDate,
        dateOfBirth: widget.dateOfBirth,
      );

      await _supabase.from('vaccination_records').insert({
        'patient_id': patientId,
        'vaccine_name': _selectedVaccine,
        'vaccine_type': schedule.type,
        'date_given': _selectedDate.toIso8601String(),
        'next_due_date': nextDue?.toIso8601String(),
        'facility': _facilityCtrl.text.trim().isNotEmpty ? _facilityCtrl.text.trim() : null,
        'batch_number': _batchCtrl.text.trim().isNotEmpty ? _batchCtrl.text.trim() : null,
        'status': 'completed',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vaccination recorded'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save the record. Check your connection and try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _facilityCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }
}
