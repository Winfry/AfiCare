import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/mental_health_model.dart';

class MentalHealthScreen extends StatefulWidget {
  const MentalHealthScreen({super.key});

  @override
  State<MentalHealthScreen> createState() => _MentalHealthScreenState();
}

class _MentalHealthScreenState extends State<MentalHealthScreen> {
  final _supabase = Supabase.instance.client;
  List<MentalHealthScreening> _screenings = [];
  List<MoodEntry> _moodEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final patientId = _supabase.auth.currentUser?.id;
      if (patientId == null) return;

      final screeningData = await _supabase
          .from('mental_health_screenings')
          .select()
          .eq('patient_id', patientId)
          .order('completed_at', ascending: false)
          .limit(20);
      _screenings = (screeningData as List)
          .map((j) => MentalHealthScreening.fromJson(j))
          .toList();

      final moodData = await _supabase
          .from('mood_entries')
          .select()
          .eq('patient_id', patientId)
          .order('recorded_at', ascending: false)
          .limit(30);
      _moodEntries = (moodData as List)
          .map((j) => MoodEntry.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading mental health data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            title: const Text('Mental Health', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Mood Check-in
                  _buildMoodCheckin(),
                  const SizedBox(height: 16),

                  // PHQ-9 Section
                  _buildScreeningCard(
                    title: 'Depression Screening (PHQ-9)',
                    subtitle: 'Standard 9-question assessment for depression',
                    icon: Icons.psychology_rounded,
                    color: const Color(0xFF5C6BC0),
                    latest: _screenings.where((s) => s.toolType == 'PHQ-9').firstOrNull,
                    onTap: () => _startScreening('PHQ-9'),
                  ),
                  const SizedBox(height: 12),

                  // GAD-7 Section
                  _buildScreeningCard(
                    title: 'Anxiety Screening (GAD-7)',
                    subtitle: 'Standard 7-question assessment for anxiety',
                    icon: Icons.healing_rounded,
                    color: const Color(0xFF26A69A),
                    latest: _screenings.where((s) => s.toolType == 'GAD-7').firstOrNull,
                    onTap: () => _startScreening('GAD-7'),
                  ),
                  const SizedBox(height: 16),

                  // Recent Mood History
                  if (_moodEntries.isNotEmpty) ...[
                    const Text('Recent Moods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildMoodHistory(),
                    const SizedBox(height: 16),
                  ],

                  // Crisis Support
                  _buildCrisisCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCheckin() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF5C6BC0).withOpacity(0.1), const Color(0xFF26A69A).withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 2, 3, 4, 5].map((mood) {
              return GestureDetector(
                onTap: () => _saveMood(mood),
                child: Column(
                  children: [
                    Text(
                      MentalHealthScreening.severityLabel(MoodEntry.moodLabel(mood)),
                      style: const TextStyle(fontSize: 11, color: Colors.transparent),
                    ),
                    Text(MoodEntry.moodEmoji(mood), style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 4),
                    Text(MoodEntry.moodLabel(mood), style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600,
                    )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    MentalHealthScreening? latest,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
            if (latest != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _severityColor(latest.severity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      MentalHealthScreening.severityLabel(latest.severity),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _severityColor(latest.severity),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Score: ${latest.totalScore}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const Spacer(),
                  Text(
                    _formatDate(latest.completedAt),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text('Take Assessment', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodHistory() {
    final last7 = _moodEntries.take(7).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: last7.map((entry) {
          final day = ['S','M','T','W','T','F','S'][entry.recordedAt.weekday % 7];
          return Column(
            children: [
              Text(MoodEntry.moodEmoji(entry.mood), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(day, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCrisisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: Color(0xFFF57F17), size: 24),
              const SizedBox(width: 10),
              const Text('Need Immediate Support?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'If you or someone you know is in crisis, reach out:',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _crisisLine('Kenya Mental Health Crisis Line', '0800 723 253'),
          const SizedBox(height: 6),
          _crisisLine('Befrienders Kenya', '+254 722 178 177'),
          const SizedBox(height: 6),
          _crisisLine('Emergency', '999'),
        ],
      ),
    );
  }

  Widget _crisisLine(String name, String number) {
    return Row(
      children: [
        Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$name: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  void _saveMood(int mood) async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      await _supabase.from('mood_entries').insert({
        'patient_id': patientId,
        'mood': mood,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood logged: ${MoodEntry.moodEmoji(mood)} ${MoodEntry.moodLabel(mood)}'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Error saving mood: $e');
    }
  }

  void _startScreening(String toolType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScreeningSheet(
        toolType: toolType,
        onComplete: () => _loadData(),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'none': return const Color(0xFF2E7D32);
      case 'mild': return const Color(0xFFF9A825);
      case 'moderate': return const Color(0xFFF57C00);
      case 'moderately_severe': return const Color(0xFFD32F2F);
      case 'severe': return const Color(0xFFB71C1C);
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

// Screening bottom sheet
class _ScreeningSheet extends StatefulWidget {
  final String toolType;
  final VoidCallback onComplete;
  const _ScreeningSheet({required this.toolType, required this.onComplete});

  @override
  State<_ScreeningSheet> createState() => _ScreeningSheetState();
}

class _ScreeningSheetState extends State<_ScreeningSheet> {
  int _currentQuestion = 0;
  final List<int> _answers = [];
  bool _isSubmitting = false;

  static const _phq9Questions = [
    'Little interest or pleasure in doing things',
    'Feeling down, depressed, or hopeless',
    'Trouble falling or staying asleep, or sleeping too much',
    'Feeling tired or having little energy',
    'Poor appetite or overeating',
    'Feeling bad about yourself',
    'Trouble concentrating on things',
    'Moving or speaking slowly, or being fidgety/restless',
    'Thoughts that you would be better off dead',
  ];

  static const _gad7Questions = [
    'Feeling nervous, anxious, or on edge',
    'Not being able to stop or control worrying',
    'Worrying too much about different things',
    'Trouble relaxing',
    'Being so restless that it is hard to sit still',
    'Becoming easily annoyed or irritable',
    'Feeling afraid, as if something awful might happen',
  ];

  List<String> get _questions => widget.toolType == 'PHQ-9' ? _phq9Questions : _gad7Questions;
  int get _totalQuestions => _questions.length;

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
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.toolType == 'PHQ-9' ? 'Depression Screening' : 'Anxiety Screening',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentQuestion + 1) / _totalQuestions,
                          backgroundColor: Colors.grey.shade200,
                          color: widget.toolType == 'PHQ-9'
                              ? const Color(0xFF5C6BC0)
                              : const Color(0xFF26A69A),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_currentQuestion + 1}/$_totalQuestions',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Question
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Over the last 2 weeks, how often have you been bothered by:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _questions[_currentQuestion],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  _answerOption(0, 'Not at all'),
                  _answerOption(1, 'Several days'),
                  _answerOption(2, 'More than half the days'),
                  _answerOption(3, 'Nearly every day'),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  TextButton(
                    onPressed: () => setState(() {
                      _answers.removeLast();
                      _currentQuestion--;
                    }),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerOption(int value, String label) {
    final selected = _answers.isNotEmpty && _currentQuestion < _answers.length && _answers[_currentQuestion] == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_currentQuestion < _answers.length) {
              _answers[_currentQuestion] = value;
            } else {
              _answers.add(value);
            }
          });

          // Auto-advance after brief delay
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            if (_currentQuestion < _totalQuestions - 1) {
              setState(() => _currentQuestion++);
            } else {
              _submitScreening();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? (widget.toolType == 'PHQ-9'
                    ? const Color(0xFF5C6BC0).withOpacity(0.1)
                    : const Color(0xFF26A69A).withOpacity(0.1))
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? (widget.toolType == 'PHQ-9' ? const Color(0xFF5C6BC0) : const Color(0xFF26A69A))
                  : AppColors.borderSubtle,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(label, style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (widget.toolType == 'PHQ-9' ? const Color(0xFF5C6BC0) : const Color(0xFF26A69A))
                : AppColors.textPrimary,
          )),
        ),
      ),
    );
  }

  void _submitScreening() async {
    setState(() => _isSubmitting = true);
    final supabase = Supabase.instance.client;
    final patientId = supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      final totalScore = _answers.fold(0, (int acc, a) => acc + a);
      final severity = MentalHealthScreening.severityFromScore(widget.toolType, totalScore);

      await supabase.from('mental_health_screenings').insert({
        'patient_id': patientId,
        'tool_type': widget.toolType,
        'answers': _answers,
        'total_score': totalScore,
        'severity': severity,
        'completed_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();
        _showResultDialog(totalScore, severity);
      }
    } catch (e) {
      debugPrint('Error saving screening: $e');
    }
  }

  void _showResultDialog(int score, String severity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${widget.toolType} Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _severityColor(severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                MentalHealthScreening.severityLabel(severity),
                style: TextStyle(fontWeight: FontWeight.w600, color: _severityColor(severity)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _severityMessage(severity),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _severityMessage(String severity) {
    switch (severity) {
      case 'none': return 'Your responses suggest minimal symptoms. Keep monitoring your mental health.';
      case 'mild': return 'You may be experiencing mild symptoms. Consider talking to a healthcare provider.';
      case 'moderate': return 'Moderate symptoms detected. We recommend consulting with a healthcare professional.';
      case 'moderately_severe': return 'Your responses indicate moderately severe symptoms. Please seek professional support.';
      case 'severe': return 'Your responses indicate severe symptoms. Please contact a mental health professional or crisis line.';
      default: return '';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'none': return const Color(0xFF2E7D32);
      case 'mild': return const Color(0xFFF9A825);
      case 'moderate': return const Color(0xFFF57C00);
      case 'moderately_severe': return const Color(0xFFD32F2F);
      case 'severe': return const Color(0xFFB71C1C);
      default: return Colors.grey;
    }
  }
}
