import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mens_health_model.dart';
import '../../models/mens_health_tools.dart';
import '../../providers/auth_provider.dart';
import '../../services/mens_health_service.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

class MensHealthScreen extends StatefulWidget {
  const MensHealthScreen({super.key, this.service});

  /// For tests; the app uses the real one.
  final MensHealthService? service;

  @override
  State<MensHealthScreen> createState() => _MensHealthScreenState();
}

class _MensHealthScreenState extends State<MensHealthScreen> {
  late final MensHealthService _service = widget.service ?? MensHealthService();
  List<MensHealthScreening> _screenings = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  /// The tool being saved, so its row can't be started twice meanwhile.
  String? _savingType;

  String? get _patientId => context.read<AuthProvider>().currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _patientId;
    if (id == null) return;
    try {
      final rows = await _service.load(id);
      if (!mounted) return;
      setState(() {
        _screenings = rows;
        _loadFailed = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading men's health: $e");
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _start(MhTool tool) async {
    final answers = await showModalBottomSheet<Map<String, int>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MhQuestionnaire(tool: tool),
    );
    if (answers == null || !mounted) return;

    final result = tool.evaluate(answers);
    final id = _patientId;
    var saved = false;
    if (id != null) {
      setState(() => _savingType = tool.type);
      try {
        await _service.save(patientId: id, tool: tool, answers: answers, result: result);
        saved = true;
      } catch (e) {
        debugPrint("Error saving men's health check-up: $e");
      }
      if (!mounted) return;
      setState(() => _savingType = null);
    }

    // Shown whether or not it saved: the advice matters either way.
    await _showResult(tool, result, saved: saved);
    if (saved && mounted) _load();
  }

  Future<void> _showResult(MhTool tool, MhResult result, {required bool saved, DateTime? takenOn}) {
    return showPModal<void>(
      context: context,
      title: tool.title,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MhResultView(tool: tool, result: result, saved: saved, takenOn: takenOn),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: PButton('Close', onPressed: () => Navigator.pop(ctx)),
          ),
        ],
      ),
    );
  }

  /// Saved check-ups can be opened again when their answers were kept by
  /// question (all since 046); the result is worked out from them again.
  VoidCallback? _reopen(MensHealthScreening s) {
    final tool = MhTool.byType(s.screeningType);
    final answers = s.answersByQuestion;
    if (tool == null || answers == null || !tool.isComplete(answers)) return null;
    return () => _showResult(tool, tool.evaluate(answers), saved: true, takenOn: s.completedAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    return PSliverPage(
      eyebrow: 'Worth checking',
      title: "Men's health",
      subtitle: 'Private check-ups. Only you can see your answers.',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadFailed) ...[
                PLoadError(what: 'your past results', onRetry: _load),
                const SizedBox(height: 16),
              ],
              const PHeading('Check-ups'),
              PCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    for (final tool in MhTool.all)
                      PRow(
                        leadingEmoji: tool.emoji,
                        title: tool.title,
                        subtitle: tool.blurb,
                        extraSubtitle: _lastLine(tool),
                        trailing: [
                          if (_savingType == tool.type)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(Icons.chevron_right_rounded, color: PT.muted),
                        ],
                        onTap: _savingType == null ? () => _start(tool) : null,
                      ),
                  ],
                ),
              ),
              if (_screenings.isNotEmpty) ...[
                const SizedBox(height: 29),
                const PHeading('Your results'),
                PCard(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      for (final s in _screenings.take(10)) _resultRow(s),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 29),
              const PCallout(
                body: 'These check-ups are a guide, not a diagnosis. If something worries you, or a '
                    'result says so, see a health worker.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  String? _lastLine(MhTool tool) {
    for (final s in _screenings) {
      if (s.screeningType == tool.type) {
        return 'Last: ${tool.levelLabel(s.riskLevel)} · ${_date(s.completedAt)}';
      }
    }
    return null;
  }

  Widget _resultRow(MensHealthScreening s) {
    final tool = MhTool.byType(s.screeningType);
    final open = _reopen(s);
    return PRow(
      leadingEmoji: tool?.emoji ?? '📋',
      title: tool?.title ?? s.screeningType,
      subtitle: tool == null
          ? s.riskLevel
          : '${tool.levelLabel(s.riskLevel)} · ${tool.scoreText(s.riskScore)}',
      trailing: [
        Text(_date(s.completedAt), style: PT.label()),
        if (open != null) Icon(Icons.chevron_right_rounded, color: PT.muted),
      ],
      onTap: open,
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The questionnaire: an intro, then one question at a time, with Back and
// Cancel. Pops with the answers when the last question is answered, or
// with nothing if cancelled.
// ═══════════════════════════════════════════════════════════════════════

class MhQuestionnaire extends StatefulWidget {
  const MhQuestionnaire({super.key, required this.tool});

  final MhTool tool;

  @override
  State<MhQuestionnaire> createState() => _MhQuestionnaireState();
}

class _MhQuestionnaireState extends State<MhQuestionnaire> {
  Map<String, int> _answers = {};

  /// Position among the questions asked so far; -1 is the intro.
  int _index = -1;

  MhTool get _tool => widget.tool;

  void _answer(MhQuestion q, int value) {
    final answers = _tool.keptAnswers({..._answers, q.key: value});
    final asked = _tool.askedQuestions(answers);
    final next = asked.indexWhere((x) => x.key == q.key) + 1;
    if (next >= asked.length) {
      Navigator.pop(context, answers);
      return;
    }
    setState(() {
      _answers = answers;
      _index = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asked = _tool.askedQuestions(_answers);
    final onIntro = _index < 0;
    final q = onIntro ? null : asked[_index];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: PT.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: PT.line, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${_tool.emoji}  ${_tool.title}', style: PT.h3()),
                  if (!onIntro) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / asked.length,
                        minHeight: 6,
                        backgroundColor: PT.progressTrack,
                        color: PT.teal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // The total can change as answers decide which
                    // questions are asked, so it is the count so far.
                    Text('Question ${_index + 1} of ${asked.length}', style: PT.label()),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: onIntro ? _intro() : _question(q!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  if (!onIntro)
                    TextButton.icon(
                      onPressed: () => setState(() => _index--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _intro() => [
        Text(_tool.intro, style: PT.body()),
        const SizedBox(height: 14),
        Text(
          "Your answers are private to you. This is a guide, not a diagnosis.",
          style: PT.sub().copyWith(fontSize: 13),
        ),
        const SizedBox(height: 22),
        PButton('Start', expand: true, onPressed: () => setState(() => _index = 0)),
      ];

  List<Widget> _question(MhQuestion q) => [
        if (_tool.preamble != null) ...[
          Text(_tool.preamble!, style: PT.sub()),
          const SizedBox(height: 8),
        ],
        Text(q.text, style: PT.h3().copyWith(fontSize: 18, height: 1.3)),
        if (q.hint != null) ...[
          const SizedBox(height: 8),
          Text(q.hint!, style: PT.sub().copyWith(fontSize: 13)),
        ],
        const SizedBox(height: 16),
        for (final o in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              label: o.label,
              selected: _answers[q.key] == o.value && _answers.containsKey(q.key),
              onTap: () => _answer(q, o.value),
            ),
          ),
      ];
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PT.badgeBlueBg : PT.page,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? PT.teal : PT.line, width: selected ? 2 : 1),
          ),
          child: Text(
            label,
            style: PT.body().copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// A result: the headline, what it means, and one line per finding.
// ═══════════════════════════════════════════════════════════════════════

class MhResultView extends StatelessWidget {
  const MhResultView({
    super.key,
    required this.tool,
    required this.result,
    required this.saved,
    this.takenOn,
  });

  final MhTool tool;
  final MhResult result;
  final bool saved;

  /// For a past result opened again.
  final DateTime? takenOn;

  static PTone tone(MhTone t) => switch (t) {
        MhTone.good => PTone.ok,
        MhTone.warn => PTone.warn,
        MhTone.alert => PTone.red,
      };

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (takenOn != null) ...[
          Text('Taken on ${takenOn!.day}/${takenOn!.month}/${takenOn!.year}', style: PT.label()),
          const SizedBox(height: 8),
        ],
        PCallout(tone: tone(r.tone), title: r.headline, body: r.summary),
        for (final f in r.findings) ...[
          const SizedBox(height: 10),
          PRow(
            leading: Icon(
              switch (f.tone) {
                MhTone.good => Icons.check_circle_outline_rounded,
                MhTone.warn => Icons.info_outline_rounded,
                MhTone.alert => Icons.error_outline_rounded,
              },
              color: switch (f.tone) {
                MhTone.good => PT.green,
                MhTone.warn => PT.warn,
                MhTone.alert => PT.danger,
              },
            ),
            title: f.title,
            subtitle: f.detail,
          ),
        ],
        if (!saved) ...[
          const SizedBox(height: 12),
          const PCallout(
            tone: PTone.warn,
            body: "This result couldn't be saved, so it won't appear on your page. Check your "
                'connection and take it again later if you want it kept.',
          ),
        ],
      ],
    );
  }
}
