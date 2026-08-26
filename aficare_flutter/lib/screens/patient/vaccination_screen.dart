import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/vaccination_model.dart';

class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key});

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final _supabase = Supabase.instance.client;
  List<VaccinationRecord> _records = [];
  bool _isLoading = true;
  String? _dateOfBirthRaw;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final patientId = _supabase.auth.currentUser?.id;
      if (patientId == null) return;

      // Load records
      final data = await _supabase
          .from('vaccination_records')
          .select()
          .eq('patient_id', patientId)
          .order('date_given', ascending: false);
      _records = (data as List)
          .map((j) => VaccinationRecord.fromJson(j))
          .toList();

      // Try to load DOB for schedule calculation
      try {
        final patient = await _supabase
            .from('patients')
            .select('date_of_birth')
            .eq('id', patientId)
            .maybeSingle();
        if (patient != null) {
          _dateOfBirthRaw = patient['date_of_birth'] as String?;
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading vaccination data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _ageWeeks {
    if (_dateOfBirthRaw == null) return 0;
    final dob = DateTime.tryParse(_dateOfBirthRaw!);
    if (dob == null) return 0;
    return (DateTime.now().difference(dob).inDays / 7).floor();
  }

  List<VaccineSchedule> get _dueVaccines {
    final administeredNames = _records.map((r) => r.vaccineName.toLowerCase()).toSet();
    return VaccinationSchedule.kenyaEPI.where((schedule) {
      if (_ageWeeks < schedule.minAgeWeeks) return false;
      // Check if any record matches this vaccine type
      final alreadyGiven = administeredNames.any((name) =>
          name.contains(schedule.type.toLowerCase()) ||
          name.contains(schedule.name.toLowerCase()));
      return !alreadyGiven;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.canopy)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/patient'),
            ),
            title: const Text('Vaccinations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: _showAddRecordSheet,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  _buildStatsRow(),
                  const SizedBox(height: 16),

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
                    'WHO-recommended Kenya childhood immunization schedule',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('${_records.length}', 'Completed', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        _statCard('${_dueVaccines.length}', 'Due', Icons.schedule_rounded, const Color(0xFFF57F17)),
        const SizedBox(width: 12),
        _statCard('$_ageWeeks', 'Age (wks)', Icons.cake_rounded, const Color(0xFF5C6BC0)),
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
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDueVaccineCard(VaccineSchedule schedule) {
    final isOverdue = _ageWeeks > (schedule.maxAgeWeeks ?? schedule.minAgeWeeks + 4);
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
                Text(schedule.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                final isGiven = _records.any((r) =>
                    r.vaccineName.toLowerCase().contains(v.type.toLowerCase()));
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
                              color: isGiven ? Colors.grey.shade500 : AppColors.textPrimary,
                            )),
                            Text(v.description, style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (record.facility != null && record.facility!.isNotEmpty)
                  Text(record.facility!, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          if (record.nextDueDate != null)
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddVaccinationSheet(onComplete: () => _loadData()),
    );
  }
}

class _AddVaccinationSheet extends StatefulWidget {
  final VoidCallback onComplete;
  const _AddVaccinationSheet({required this.onComplete});

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
                  const Text('Record Vaccination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                        firstDate: DateTime(2020),
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
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      // Find the schedule for this vaccine to set next due date
      final schedule = VaccinationSchedule.kenyaEPI.firstWhere(
        (v) => v.name == _selectedVaccine,
        orElse: () => VaccinationSchedule.kenyaEPI.first,
      );

      DateTime? nextDue;
      final nextSchedule = VaccinationSchedule.kenyaEPI.firstWhere(
        (v) => v.name != _selectedVaccine && v.type == schedule.type,
        orElse: () => schedule,
      );
      if (nextSchedule.name != _selectedVaccine) {
        nextDue = DateTime.now().add(const Duration(days: 28)); // ~4 weeks default
      }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _facilityCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }
}
