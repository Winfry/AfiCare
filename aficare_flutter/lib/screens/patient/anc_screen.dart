import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/anc_visit_model.dart';

class AncScreen extends StatefulWidget {
  const AncScreen({super.key});

  @override
  State<AncScreen> createState() => _AncScreenState();
}

class _AncScreenState extends State<AncScreen> {
  final _supabase = Supabase.instance.client;
  List<AncVisit> _visits = [];
  bool _isLoading = true;
  DateTime? _lmp;
  String? _notesRaw;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final patientId = _supabase.auth.currentUser?.id;
      if (patientId == null) return;

      // Load visits
      final visitData = await _supabase
          .from('anc_visits')
          .select()
          .eq('patient_id', patientId)
          .order('visit_date', ascending: false);
      _visits = (visitData as List)
          .map((j) => AncVisit.fromJson(j))
          .toList();

      // Load LMP from patient notes
      try {
        final patient = await _supabase
            .from('patients')
            .select('notes')
            .eq('id', patientId)
            .maybeSingle();
        if (patient != null && patient['notes'] != null) {
          _notesRaw = patient['notes'] as String;
          if (_notesRaw!.contains('lmp:')) {
            final lmpStr = _notesRaw!.split('lmp:')[1].split(';')[0].trim();
            _lmp = DateTime.tryParse(lmpStr);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading ANC data: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not load ANC data: $e'), backgroundColor: Colors.red),
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _gestationalWeeks {
    if (_lmp == null) return 0;
    return (DateTime.now().difference(_lmp!).inDays / 7).floor();
  }

  String get _trimester => AncVisit.trimesterFromWeeks(_gestationalWeeks);

  String get _dueDate {
    if (_lmp == null) return 'Not set';
    final due = _lmp!.add(const Duration(days: 280));
    return '${due.day}/${due.month}/${due.year}';
  }

  int get _daysUntilDue {
    if (_lmp == null) return 0;
    return _lmp!.add(const Duration(days: 280)).difference(DateTime.now()).inDays;
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
            title: const Text('ANC Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: _showAddVisitSheet,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add Visit', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pregnancy Progress Card
                  _buildPregnancyCard(),
                  const SizedBox(height: 16),

                  // Visit Stats
                  _buildVisitStats(),
                  const SizedBox(height: 16),

                  // Danger Signs Warning
                  if (_trimester == 'third' || _trimester == 'second')
                    _buildDangerSignsCard(),

                  // Visit Timeline
                  const Text('Visit History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  if (_visits.isEmpty)
                    _buildEmptyState()
                  else
                    ...(_visits.map((v) => _buildVisitCard(v))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancyCard() {
    final weeks = _gestationalWeeks;
    final progress = (weeks / 40).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFE91E63).withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤰', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weeks > 0 ? 'Week $weeks' : 'Set LMP to begin',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                  Text(
                    AncVisit.trimesterLabel(_trimester),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Due: $_dueDate', style: const TextStyle(color: Colors.white, fontSize: 13)),
              Text(
                _daysUntilDue > 0 ? '$_daysUntilDue days remaining' : 'Due date passed',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lmp == null)
            TextButton(
              onPressed: _showSetLmpSheet,
              child: const Text('Set Last Menstrual Period', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitStats() {
    return Row(
      children: [
        _statCard('${_visits.length}', 'Visits', Icons.medical_services_rounded, const Color(0xFF5C6BC0)),
        const SizedBox(width: 12),
        _statCard('$_gestationalWeeks', 'Weeks', Icons.calendar_month_rounded, const Color(0xFF26A69A)),
        const SizedBox(width: 12),
        _statCard('${_daysUntilDue > 0 ? _daysUntilDue : 0}', 'Days to Due', Icons.timer_rounded, const Color(0xFFF57F17)),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
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

  Widget _buildDangerSignsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Color(0xFFF57F17), size: 20),
              const SizedBox(width: 8),
              const Text('Danger Signs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Seek immediate medical care if you experience:\n'
            '• Severe headache or blurred vision\n'
            '• Vaginal bleeding\n'
            '• Severe abdominal pain\n'
            '• Reduced fetal movement\n'
            '• Difficulty breathing or convulsions',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(Icons.medical_services_outlined, color: Colors.grey.shade300, size: 48),
          const SizedBox(height: 12),
          Text('No ANC Visits Yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            'Track your antenatal care visits to ensure a healthy pregnancy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddVisitSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log First Visit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(AncVisit visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _trimesterColor(visit.trimester).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Visit ${visit.visitNumber}',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _trimesterColor(visit.trimester)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${visit.gestationalWeeks} weeks',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${visit.visitDate.day}/${visit.visitDate.month}/${visit.visitDate.year}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Vitals row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (visit.systolicBP != null)
                _vitalChip('BP', '${visit.systolicBP}/${visit.diastolicBP}', Icons.monitor_heart_rounded),
              if (visit.weight != null)
                _vitalChip('Weight', '${visit.weight} kg', Icons.scale_rounded),
              if (visit.hemoglobin != null)
                _vitalChip('Hb', '${visit.hemoglobin} g/dL', Icons.bloodtype_rounded),
              if (visit.fetalHeartRate != null)
                _vitalChip('FHR', '${visit.fetalHeartRate} bpm', Icons.favorite_rounded),
            ],
          ),
          if (visit.dangerSigns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: visit.dangerSigns.map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
                ),
                child: Text(d, style: const TextStyle(fontSize: 11, color: Color(0xFFF57F17))),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vitalChip(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _trimesterColor(String t) {
    switch (t) {
      case 'first': return const Color(0xFF5C6BC0);
      case 'second': return const Color(0xFF26A69A);
      case 'third': return const Color(0xFFE91E63);
      default: return Colors.grey;
    }
  }

  void _showSetLmpSheet() {
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 140));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set Last Menstrual Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text('This helps calculate your due date and track your pregnancy.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 300,
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 300)),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) => setSheetState(() => selectedDate = d),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final patientId = _supabase.auth.currentUser?.id;
                    if (patientId == null) return;

                    // Save LMP to patient notes
                    try {
                      final notes = _notesRaw ?? '';
                      String updatedNotes;
                      if (notes.contains('lmp:')) {
                        updatedNotes = notes.replaceAll(
                          RegExp(r'lmp:.*?;'),
                          'lmp: ${selectedDate.toIso8601String()};',
                        );
                      } else {
                        updatedNotes = '$notes lmp: ${selectedDate.toIso8601String()};';
                      }

                      await _supabase.from('patients').upsert({
                        'id': patientId,
                        'notes': updatedNotes,
                      });

                      Navigator.pop(ctx);
                      setState(() {
                        _lmp = selectedDate;
                        _notesRaw = updatedNotes;
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving LMP: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddVisitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddVisitSheet(
        visitNumber: _visits.length + 1,
        gestationalWeeks: _gestationalWeeks,
        onComplete: () => _loadData(),
      ),
    );
  }
}

class _AddVisitSheet extends StatefulWidget {
  final int visitNumber;
  final int gestationalWeeks;
  final VoidCallback onComplete;
  const _AddVisitSheet({required this.visitNumber, required this.gestationalWeeks, required this.onComplete});

  @override
  State<_AddVisitSheet> createState() => _AddVisitSheetState();
}

class _AddVisitSheetState extends State<_AddVisitSheet> {
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _hbCtrl = TextEditingController();
  final _fhrCtrl = TextEditingController();
  final _fundalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _facilityCtrl = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  List<String> _selectedDangerSigns = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                  Text('Add Visit #${widget.visitNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Gestational age: ${widget.gestationalWeeks} weeks', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  _field('Systolic BP (mmHg)', _bpSysCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Diastolic BP (mmHg)', _bpDiaCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Weight (kg)', _weightCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Hemoglobin (g/dL)', _hbCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Fetal Heart Rate (bpm)', _fhrCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Fundal Height (cm)', _fundalCtrl, TextInputType.number),
                  const SizedBox(height: 10),
                  _field('Facility', _facilityCtrl, TextInputType.text),
                  const SizedBox(height: 16),

                  const Text('Danger Signs Observed:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AncVisit.dangerSignsList.map((sign) {
                      final selected = _selectedDangerSigns.contains(sign);
                      return FilterChip(
                        label: Text(sign, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.grey.shade700)),
                        selected: selected,
                        onSelected: (s) => setState(() {
                          if (s) _selectedDangerSigns.add(sign);
                          else _selectedDangerSigns.remove(sign);
                        }),
                        selectedColor: const Color(0xFFF57F17),
                        backgroundColor: Colors.grey.shade100,
                      );
                    }).toList(),
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
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Visit', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      await _supabase.from('anc_visits').insert({
        'patient_id': patientId,
        'visit_number': widget.visitNumber,
        'gestational_weeks': widget.gestationalWeeks,
        'trimester': AncVisit.trimesterFromWeeks(widget.gestationalWeeks),
        'visit_date': DateTime.now().toIso8601String(),
        'systolic_bp': int.tryParse(_bpSysCtrl.text),
        'diastolic_bp': int.tryParse(_bpDiaCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
        'hemoglobin': double.tryParse(_hbCtrl.text),
        'fetal_heart_rate': int.tryParse(_fhrCtrl.text),
        'fundal_height': double.tryParse(_fundalCtrl.text),
        'facility': _facilityCtrl.text.trim(),
        'danger_signs': _selectedDangerSigns,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit recorded'), backgroundColor: Color(0xFF2E7D32)),
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
    _bpSysCtrl.dispose();
    _bpDiaCtrl.dispose();
    _weightCtrl.dispose();
    _hbCtrl.dispose();
    _fhrCtrl.dispose();
    _fundalCtrl.dispose();
    _notesCtrl.dispose();
    _facilityCtrl.dispose();
    super.dispose();
  }
}
