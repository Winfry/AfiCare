import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/mens_health_model.dart';

class MensHealthScreen extends StatefulWidget {
  const MensHealthScreen({super.key});

  @override
  State<MensHealthScreen> createState() => _MensHealthScreenState();
}

class _MensHealthScreenState extends State<MensHealthScreen> {
  final _supabase = Supabase.instance.client;
  List<MensHealthScreening> _screenings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScreenings();
  }

  Future<void> _loadScreenings() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;
    try {
      final data = await _supabase
          .from('mens_health_screenings')
          .select()
          .eq('patient_id', patientId)
          .order('completed_at', ascending: false)
          .limit(30);
      _screenings = (data as List).map((j) => MensHealthScreening.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading mens health: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.canopy)));
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
            title: const Text("Men's Health", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Men in Kenya face high rates of cardiovascular disease, prostate cancer, and mental health challenges. Early screening saves lives.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Screening Tools', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),

                  _toolCard('cardiovascular', 'Cardiovascular Risk', 'Framingham-inspired 10-year risk assessment', '❤️', const Color(0xFFE53935)),
                  _toolCard('prostate', 'Prostate Health (IPSS)', 'Urinary symptom score — 7 questions', '🩺', const Color(0xFF1565C0)),
                  _toolCard('lifestyle', 'Lifestyle & Wellness', 'Activity, alcohol, smoking, sleep, stress', '🏃', const Color(0xFF2E7D32)),
                  _toolCard('erectile', 'Sexual Health (IIEF-5)', 'Erectile function screening', '💊', const Color(0xFF7B1FA2)),
                  _toolCard('metabolic', 'Metabolic Syndrome', 'Waist, BP, glucose, triglycerides, HDL', '⚖️', const Color(0xFFF57F17)),

                  if (_screenings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Recent Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_screenings.take(5).map((s) => _resultCard(s))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCard(String type, String title, String desc, String icon, Color color) {
    return GestureDetector(
      onTap: () => _startScreening(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
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

  Widget _resultCard(MensHealthScreening s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _riskColor(s.riskLevel).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(MensHealthScreening.riskLevelLabel(s.riskLevel),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _riskColor(s.riskLevel))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MensHealthScreening.screeningLabel(s.screeningType),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Score: ${s.riskScore}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text('${s.completedAt.day}/${s.completedAt.month}/${s.completedAt.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'low': return const Color(0xFF2E7D32);
      case 'moderate': return const Color(0xFFF9A825);
      case 'high': return const Color(0xFFF57F17);
      case 'very_high': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  void _startScreening(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MensHealthScreeningSheet(
        screeningType: type,
        onComplete: () => _loadScreenings(),
      ),
    );
  }
}

class _MensHealthScreeningSheet extends StatefulWidget {
  final String screeningType;
  final VoidCallback onComplete;
  const _MensHealthScreeningSheet({required this.screeningType, required this.onComplete});

  @override
  State<_MensHealthScreeningSheet> createState() => _MensHealthScreeningSheetState();
}

class _MensHealthScreeningSheetState extends State<_MensHealthScreeningSheet> {
  int _currentQ = 0;
  final List<int> _answers = [];
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _questions {
    switch (widget.screeningType) {
      case 'cardiovascular': return MensHealthScreening.cvdQuestions;
      case 'prostate': return MensHealthScreening.ipssQuestions;
      default: return MensHealthScreening.cvdQuestions;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQ >= _questions.length) {
      _submitScreening();
      return const SizedBox.shrink();
    }

    final q = _questions[_currentQ];
    final options = (q['options'] as List).cast<String>();
    final scores = (q['scores'] as List).cast<int>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(MensHealthScreening.screeningLabel(widget.screeningType),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: (_currentQ + 1) / _questions.length, minHeight: 6,
                        backgroundColor: Colors.grey.shade200, color: AppColors.canopy)),
                Text('${_currentQ + 1}/${_questions.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q['question'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 16),
                  ...options.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () {
                        _answers.add(scores[entry.key]);
                        setState(() => _currentQ++);
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitScreening() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    final supabase = Supabase.instance.client;
    final patientId = supabase.auth.currentUser?.id;
    if (patientId == null) return;

    final totalScore = _answers.fold(0, (int s, a) => s + a);
    String riskLevel;
    if (widget.screeningType == 'prostate') {
      riskLevel = MensHealthScreening.ipssSeverity(totalScore);
    } else {
      riskLevel = MensHealthScreening.cvdRiskInterpretation(totalScore);
    }

    try {
      await supabase.from('mens_health_screenings').insert({
        'id': const Uuid().v4(),
        'patient_id': patientId,
        'screening_type': widget.screeningType,
        'responses': {'answers': _answers},
        'risk_score': totalScore,
        'risk_level': riskLevel,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving screening: $e');
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: $totalScore', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(MensHealthScreening.riskLevelLabel(riskLevel),
                  style: TextStyle(fontWeight: FontWeight.w600, color: _riskColor(riskLevel), fontSize: 16)),
              const SizedBox(height: 12),
              Text(_getResultMessage(widget.screeningType, riskLevel),
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'low': return const Color(0xFF2E7D32);
      case 'moderate': return const Color(0xFFF9A825);
      case 'high': case 'severe': return const Color(0xFFF57F17);
      case 'very_high': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  String _getResultMessage(String type, String level) {
    if (type == 'prostate') {
      switch (level) {
        case 'mild': return 'Your symptoms are mild. Continue monitoring and maintain hydration. Consider annual screening after age 50.';
        case 'moderate': return 'Moderate symptoms detected. Consult a urologist for PSA testing and prostate examination.';
        case 'severe': return 'Severe symptoms require medical attention. Please see a urologist promptly.';
      }
    }
    switch (level) {
      case 'low': return 'Your cardiovascular risk is low. Maintain a healthy lifestyle with regular exercise and balanced diet.';
      case 'moderate': return 'Moderate risk. Consider lifestyle changes: reduce salt, exercise regularly, quit smoking.';
      case 'high': return 'High risk. Please consult a healthcare provider for a comprehensive cardiovascular assessment.';
      case 'very_high': return 'Very high risk. Urgent medical consultation recommended. Blood pressure and cholesterol management may be needed.';
    }
    return '';
  }
}
