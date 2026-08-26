import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/household_model.dart';

class CHWScreeningScreen extends StatefulWidget {
  const CHWScreeningScreen({super.key});

  @override
  State<CHWScreeningScreen> createState() => _CHWScreeningScreenState();
}

class _CHWScreeningScreenState extends State<CHWScreeningScreen> {
  final _supabase = Supabase.instance.client;
  List<CommunityScreening> _screenings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScreenings();
  }

  Future<void> _loadScreenings() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null) return;

    try {
      final data = await _supabase
          .from('community_screenings')
          .select()
          .eq('chv_id', chvId)
          .order('screening_date', ascending: false)
          .limit(50);
      _screenings = (data as List).map((j) => CommunityScreening.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading screenings: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.canopy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/chw'),
        ),
        title: const Text('Community Screenings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.canopy))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Screening Tools', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 10),
                        _screeningTool('malaria', 'Malaria Rapid Diagnostic', '🦟', 'Test for malaria using RDT kit'),
                        _screeningTool('tb', 'TB Symptom Screening', '🫁', 'Cough, fever, weight loss, night sweats'),
                        _screeningTool('malnutrition', 'Malnutrition (MUAC)', '📏', 'Mid-upper arm circumference measurement'),
                        _screeningTool('blood_pressure', 'Blood Pressure Check', '❤️', 'Measure systolic and diastolic BP'),
                        _screeningTool('blood_sugar', 'Random Blood Sugar', '🩸', 'Capillary blood glucose test'),
                        _screeningTool('visual', 'Visual Acuity', '👁️', 'Snellen chart eye test'),
                        const SizedBox(height: 20),

                        Text('Recent Screenings (${_screenings.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (_screenings.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No screenings recorded yet.', style: TextStyle(color: Colors.grey.shade400)),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _screeningResultCard(_screenings[i]),
                      ),
                      childCount: _screenings.length,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _screeningTool(String type, String title, String icon, String desc) {
    return GestureDetector(
      onTap: () => _startScreening(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _screeningResultCard(CommunityScreening s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(CommunityScreening.screeningIcon(s.screeningType), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CommunityScreening.screeningLabel(s.screeningType),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${s.screeningDate.day}/${s.screeningDate.month}/${s.screeningDate.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: s.outcome == 'normal'
                  ? const Color(0xFFE8F5E9)
                  : s.outcome == 'referred'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              s.outcome.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: s.outcome == 'normal'
                    ? const Color(0xFF2E7D32)
                    : s.outcome == 'referred'
                        ? const Color(0xFFF57F17)
                        : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startScreening(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScreeningFormSheet(
        screeningType: type,
        onComplete: () => _loadScreenings(),
      ),
    );
  }
}

class _ScreeningFormSheet extends StatefulWidget {
  final String screeningType;
  final VoidCallback onComplete;
  const _ScreeningFormSheet({required this.screeningType, required this.onComplete});

  @override
  State<_ScreeningFormSheet> createState() => _ScreeningFormSheetState();
}

class _ScreeningFormSheetState extends State<_ScreeningFormSheet> {
  final _supabase = Supabase.instance.client;
  final _notesCtrl = TextEditingController();
  String _outcome = 'normal';
  bool _isSaving = false;

  // Malaria
  String _malariaResult = 'negative';
  // TB
  bool _hasCough = false;
  bool _hasFever = false;
  bool _hasNightSweats = false;
  bool _hasWeightLoss = false;
  // MUAC
  final _muacCtrl = TextEditingController();
  // BP
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  // Blood sugar
  final _bsCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  Text(CommunityScreening.screeningLabel(widget.screeningType),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 16),
                  _buildFormFields(),
                  const SizedBox(height: 16),
                  const Text('Outcome', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _outcomeChip('normal', 'Normal', const Color(0xFF2E7D32)),
                      _outcomeChip('referral_needed', 'Needs Referral', const Color(0xFFF57F17)),
                      _outcomeChip('referred', 'Referred', const Color(0xFFC62828)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Notes...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.canopy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Screening', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    switch (widget.screeningType) {
      case 'malaria':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RDT Result', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _choiceChip('Positive', _malariaResult == 'positive', () => setState(() => _malariaResult = 'positive')),
              _choiceChip('Negative', _malariaResult == 'negative', () => setState(() => _malariaResult = 'negative')),
              _choiceChip('Invalid', _malariaResult == 'invalid', () => setState(() => _malariaResult = 'invalid')),
            ]),
          ],
        );
      case 'tb':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Symptoms (check all present)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            CheckboxListTile(title: const Text('Cough > 2 weeks'), value: _hasCough, onChanged: (v) => setState(() => _hasCough = v!), contentPadding: EdgeInsets.zero, dense: true),
            CheckboxListTile(title: const Text('Fever'), value: _hasFever, onChanged: (v) => setState(() => _hasFever = v!), contentPadding: EdgeInsets.zero, dense: true),
            CheckboxListTile(title: const Text('Night sweats'), value: _hasNightSweats, onChanged: (v) => setState(() => _hasNightSweats = v!), contentPadding: EdgeInsets.zero, dense: true),
            CheckboxListTile(title: const Text('Unexplained weight loss'), value: _hasWeightLoss, onChanged: (v) => setState(() => _hasWeightLoss = v!), contentPadding: EdgeInsets.zero, dense: true),
          ],
        );
      case 'malnutrition':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('MUAC Measurement (mm)', _muacCtrl, TextInputType.number),
            const SizedBox(height: 6),
            Text('Green: >12.5mm | Yellow: 11.5-12.5mm | Red: <11.5mm',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        );
      case 'blood_pressure':
        return Row(children: [
          Expanded(child: _field('Systolic (mmHg)', _bpSysCtrl, TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _field('Diastolic (mmHg)', _bpDiaCtrl, TextInputType.number)),
        ]);
      case 'blood_sugar':
        return _field('Random Blood Sugar (mg/dL)', _bsCtrl, TextInputType.number);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.canopy.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.canopy : AppColors.borderSubtle),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.canopy : Colors.grey.shade700)),
      ),
    );
  }

  Widget _outcomeChip(String value, String label, Color color) {
    final sel = _outcome == value;
    return GestureDetector(
      onTap: () => setState(() => _outcome = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? color : AppColors.borderSubtle, width: sel ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? color : Colors.grey.shade700)),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.canopy, width: 1.5)),
      ),
    );
  }

  Future<void> _save() async {
    final chvId = _supabase.auth.currentUser?.id;
    if (chvId == null) return;
    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> results = {};
      switch (widget.screeningType) {
        case 'malaria':
          results = {'rdt_result': _malariaResult};
          if (_malariaResult == 'positive') _outcome = 'referral_needed';
          break;
        case 'tb':
          results = {'cough': _hasCough, 'fever': _hasFever, 'night_sweats': _hasNightSweats, 'weight_loss': _hasWeightLoss};
          if (_hasCough && _hasFever) _outcome = 'referral_needed';
          break;
        case 'malnutrition':
          results = {'muac_mm': double.tryParse(_muacCtrl.text)};
          break;
        case 'blood_pressure':
          results = {'systolic': int.tryParse(_bpSysCtrl.text), 'diastolic': int.tryParse(_bpDiaCtrl.text)};
          final sys = int.tryParse(_bpSysCtrl.text) ?? 0;
          if (sys >= 140) _outcome = 'referral_needed';
          break;
        case 'blood_sugar':
          results = {'rbs_mg_dl': double.tryParse(_bsCtrl.text)};
          final rbs = double.tryParse(_bsCtrl.text) ?? 0;
          if (rbs > 200) _outcome = 'referral_needed';
          break;
      }

      await _supabase.from('community_screenings').insert({
        'id': const Uuid().v4(),
        'chv_id': chvId,
        'screening_type': widget.screeningType,
        'results': results,
        'outcome': _outcome,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'screening_date': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screening saved'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }
}
