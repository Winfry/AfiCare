// The five Men's health check-ups: their questions, and how answers become
// a result. Pure Dart, so every rule can be tested without a screen.
//
// Sexual health, metabolic health and lifestyle use published, validated
// questionnaires word for word (or as close as plain English allows):
//   - Sexual health: IIEF-5 / SHIM (Rosen et al., 1999).
//   - Metabolic health: the harmonised metabolic syndrome criteria
//     (Alberti et al., Circulation 2009), with the IDF waist cut-off for
//     men of sub-Saharan African origin (94 cm).
//   - Lifestyle: AUDIT-C for alcohol (men: 4 or more is positive), PHQ-2
//     for mood (3 or more is positive), and WHO guidance for activity
//     (150 minutes a week), fruit and vegetables (5 servings a day), salt
//     (under 5 g a day), plus 7 or more hours of sleep.
// Heart risk and prostate keep their existing questions and scoring.

/// One answer a person can pick. [value] is what's scored and saved.
class MhOption {
  const MhOption(this.label, this.value);
  final String label;
  final int value;
}

class MhQuestion {
  const MhQuestion({
    required this.key,
    required this.text,
    required this.options,
    this.hint,
    this.showIf,
  });

  final String key;
  final String text;
  final List<MhOption> options;

  /// Extra help shown under the question (how to measure, what counts).
  final String? hint;

  /// Asked only when this returns true for the answers so far.
  final bool Function(Map<String, int> answers)? showIf;

  bool isAsked(Map<String, int> answers) => showIf?.call(answers) ?? true;
}

enum MhTone { good, warn, alert }

/// One line of a result: what was found about one thing, and what to do.
class MhFinding {
  const MhFinding(this.title, this.detail, this.tone);
  final String title;
  final String detail;
  final MhTone tone;
}

class MhResult {
  const MhResult({
    required this.score,
    required this.level,
    required this.headline,
    required this.summary,
    required this.tone,
    this.findings = const [],
  });

  /// Saved as risk_score. Its meaning depends on the tool (see [MhTool.scoreText]).
  final int score;

  /// Saved as risk_level; the allowed values per tool are in [MhTool.levels].
  final String level;
  final String headline;
  final String summary;
  final MhTone tone;
  final List<MhFinding> findings;
}

abstract class MhTool {
  const MhTool();

  /// Saved as screening_type.
  String get type;
  String get title;
  String get emoji;
  String get blurb;

  /// Shown before the first question.
  String get intro;

  /// Shown above every question, e.g. the time it's about.
  String? get preamble => null;

  List<MhQuestion> get questions;

  /// Every risk_level this tool can save, with how it reads.
  Map<String, String> get levels;

  MhResult evaluate(Map<String, int> answers);

  /// How a saved score reads, e.g. "18 of 25".
  String scoreText(int score);

  /// The questions asked, given the answers so far.
  List<MhQuestion> askedQuestions(Map<String, int> answers) =>
      [for (final q in questions) if (q.isAsked(answers)) q];

  /// Only the answers to questions that are still asked: going back and
  /// changing "Do you drink?" to "Never" drops the drinking answers.
  Map<String, int> keptAnswers(Map<String, int> answers) {
    final asked = askedQuestions(answers).map((q) => q.key).toSet();
    return {for (final e in answers.entries) if (asked.contains(e.key)) e.key: e.value};
  }

  bool isComplete(Map<String, int> answers) =>
      askedQuestions(answers).every((q) => answers.containsKey(q.key));

  String levelLabel(String level) => levels[level] ?? level;

  static const all = <MhTool>[
    HeartRiskTool(),
    ProstateTool(),
    LifestyleTool(),
    SexualHealthTool(),
    MetabolicTool(),
  ];

  static MhTool? byType(String type) {
    for (final t in all) {
      if (t.type == type) return t;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Sexual health: IIEF-5 (SHIM)
// ═══════════════════════════════════════════════════════════════════════

class SexualHealthTool extends MhTool {
  const SexualHealthTool();

  @override
  String get type => 'erectile';
  @override
  String get title => 'Sexual health';
  @override
  String get emoji => '💬';
  @override
  String get blurb => 'Erections: the IIEF-5, 5 questions';
  @override
  String get intro =>
      'Five questions doctors use to check for erection problems (the IIEF-5). Erection problems are '
      'common, treatable, and sometimes an early sign of heart disease or diabetes. '
      'Your answers stay private to you.';
  @override
  String get preamble => 'Over the past 6 months:';

  static const _noIntercourse = MhOption('I did not attempt sexual intercourse', 0);

  static const _howOften = [
    MhOption('Almost never or never', 1),
    MhOption('A few times (much less than half the time)', 2),
    MhOption('Sometimes (about half the time)', 3),
    MhOption('Most times (much more than half the time)', 4),
    MhOption('Almost always or always', 5),
  ];

  @override
  List<MhQuestion> get questions => const [
        MhQuestion(
          key: 'confidence',
          text: 'How do you rate your confidence that you could get and keep an erection?',
          options: [
            MhOption('Very low', 1),
            MhOption('Low', 2),
            MhOption('Moderate', 3),
            MhOption('High', 4),
            MhOption('Very high', 5),
          ],
        ),
        MhQuestion(
          key: 'hard_enough',
          text: 'When you had erections with sexual stimulation, how often were your erections hard '
              'enough for penetration?',
          options: [MhOption('No sexual activity', 0), ..._howOften],
        ),
        MhQuestion(
          key: 'maintain',
          text: 'During sexual intercourse, how often were you able to keep your erection after you had '
              'entered your partner?',
          options: [_noIntercourse, ..._howOften],
        ),
        MhQuestion(
          key: 'to_completion',
          text: 'During sexual intercourse, how difficult was it to keep your erection until the end of '
              'intercourse?',
          options: [
            _noIntercourse,
            MhOption('Extremely difficult', 1),
            MhOption('Very difficult', 2),
            MhOption('Difficult', 3),
            MhOption('Slightly difficult', 4),
            MhOption('Not difficult', 5),
          ],
        ),
        MhQuestion(
          key: 'satisfactory',
          text: 'When you attempted sexual intercourse, how often was it satisfactory for you?',
          options: [_noIntercourse, ..._howOften],
        ),
      ];

  @override
  Map<String, String> get levels => const {
        'none': 'No erection problems',
        'mild': 'Mild',
        'mild_moderate': 'Mild to moderate',
        'moderate': 'Moderate',
        'severe': 'Severe',
        'unscored': 'Not enough to score',
      };

  /// The published IIEF-5 bands.
  static String band(int score) {
    if (score >= 22) return 'none';
    if (score >= 17) return 'mild';
    if (score >= 12) return 'mild_moderate';
    if (score >= 8) return 'moderate';
    return 'severe';
  }

  static const _infections = MhFinding(
    'Not covered here: infections',
    'Discharge, sores, or pain when passing urine need a clinic visit. This check does not look for them.',
    MhTone.warn,
  );

  @override
  MhResult evaluate(Map<String, int> answers) {
    final score = questions.fold(0, (int s, q) => s + (answers[q.key] ?? 0));

    // "No sexual activity" scores 0, which would read as a severe problem.
    // The published scoring isn't meant for that, so say so instead.
    if (questions.any((q) => answers[q.key] == 0)) {
      return MhResult(
        score: score,
        level: 'unscored',
        headline: 'Not enough to score',
        summary: "This check needs some sexual activity in the past 6 months to give a score. If you've "
            "avoided sex because of erection worries, that's worth mentioning to a health worker.",
        tone: MhTone.warn,
        findings: const [_infections],
      );
    }

    final level = band(score);
    final findings = <MhFinding>[];
    if (level == 'none') {
      findings.add(const MhFinding(
        'No sign of erection problems',
        'Your answers are in the normal range (22 to 25).',
        MhTone.good,
      ));
    } else {
      findings.addAll(const [
        MhFinding(
          'Worth a check-up',
          'Erection problems can be an early sign of heart disease, diabetes or high blood pressure, '
              'sometimes years before other signs. Ask a health worker to check your blood pressure, '
              'blood sugar and cholesterol.',
          MhTone.alert,
        ),
        MhFinding(
          "Don't buy erection pills without advice",
          'They can be dangerous with some heart medicines (such as nitrates for chest pain), and fake '
              'pills are common. A health worker can prescribe safe treatment.',
          MhTone.warn,
        ),
        MhFinding(
          'Common causes worth looking at',
          'Stress, low mood, alcohol, smoking, and some medicines (including some for blood pressure) '
              "can all play a part. Don't stop a medicine on your own: ask first.",
          MhTone.warn,
        ),
      ]);
    }
    findings.add(_infections);

    return MhResult(
      score: score,
      level: level,
      headline: levels[level]!,
      summary: level == 'none'
          ? 'Score $score of 25. Nothing to act on from this check.'
          : 'Score $score of 25. This is common and treatable. Please talk to a health worker.',
      tone: switch (level) {
        'none' => MhTone.good,
        'mild' || 'mild_moderate' => MhTone.warn,
        _ => MhTone.alert,
      },
      findings: findings,
    );
  }

  @override
  String scoreText(int score) => '$score of 25';
}

// ═══════════════════════════════════════════════════════════════════════
// Metabolic health: metabolic syndrome, 3 or more of 5 signs
// ═══════════════════════════════════════════════════════════════════════

class MetabolicTool extends MhTool {
  const MetabolicTool();

  /// Answer values: the sign is absent, present, or not known.
  static const no = 0;
  static const yes = 1;
  static const unknown = 9;

  @override
  String get type => 'metabolic';
  @override
  String get title => 'Metabolic health';
  @override
  String get emoji => '⚖️';
  @override
  String get blurb => 'Waist, blood pressure, sugar and blood fats';
  @override
  String get intro =>
      'Five signs doctors look for together (metabolic syndrome). Three or more of them raise the risk '
      'of heart disease, stroke and type 2 diabetes. Use your most recent results; '
      "\"I don't know\" is a fine answer.";

  static const _dontKnow = MhOption("I don't know", unknown);

  @override
  List<MhQuestion> get questions => const [
        MhQuestion(
          key: 'waist',
          text: 'Your waist size',
          hint: 'Measure around your bare belly, halfway between your lowest rib and the top of your hip '
              'bone, after breathing out normally. 94 cm is about 37 inches.',
          options: [
            MhOption('Less than 94 cm', no),
            MhOption('94 cm or more', yes),
            _dontKnow,
          ],
        ),
        MhQuestion(
          key: 'blood_pressure',
          text: 'Your blood pressure',
          hint: 'From your most recent reading at a clinic or pharmacy.',
          options: [
            MhOption('Below 130/85 (top number under 130 and bottom under 85)', no),
            MhOption('130/85 or higher (top 130 or more, or bottom 85 or more)', yes),
            MhOption('I take medicine for high blood pressure', yes),
            _dontKnow,
          ],
        ),
        MhQuestion(
          key: 'fasting_glucose',
          text: 'Your fasting blood sugar',
          hint: 'Tested after not eating overnight. A random sugar test (after eating) does not count.',
          options: [
            MhOption('Below 5.6 mmol/L (100 mg/dL)', no),
            MhOption('5.6 mmol/L (100 mg/dL) or higher', yes),
            MhOption('I take medicine for diabetes or high sugar', yes),
            _dontKnow,
          ],
        ),
        MhQuestion(
          key: 'triglycerides',
          text: 'Your triglycerides (a blood fat)',
          hint: 'Part of a "lipid profile" blood test. Medicines such as fenofibrate count; a statin '
              'alone (such as atorvastatin) does not.',
          options: [
            MhOption('Below 1.7 mmol/L (150 mg/dL)', no),
            MhOption('1.7 mmol/L (150 mg/dL) or higher', yes),
            MhOption('I take medicine to lower triglycerides', yes),
            _dontKnow,
          ],
        ),
        MhQuestion(
          key: 'hdl',
          text: 'Your HDL ("good") cholesterol',
          hint: 'Also part of a lipid profile. Here, low is the warning sign. A statin alone does not '
              'count as medicine for HDL.',
          options: [
            MhOption('1.0 mmol/L (40 mg/dL) or higher', no),
            MhOption('Below 1.0 mmol/L (40 mg/dL)', yes),
            MhOption('I take medicine to raise my HDL', yes),
            _dontKnow,
          ],
        ),
      ];

  @override
  Map<String, String> get levels => const {
        'unlikely': 'Not metabolic syndrome',
        'unclear': "Can't tell yet",
        'likely': 'Likely metabolic syndrome',
      };

  static const _signNames = {
    'waist': 'Large waist',
    'blood_pressure': 'Raised blood pressure',
    'fasting_glucose': 'Raised fasting sugar',
    'triglycerides': 'Raised triglycerides',
    'hdl': 'Low HDL cholesterol',
  };

  static const _howToFind = {
    'waist': 'Measure your waist with a tape at home.',
    'blood_pressure': 'Have your blood pressure taken at a pharmacy or clinic.',
    'fasting_glucose': 'Ask a clinic for a fasting blood sugar test.',
    'triglycerides': 'Ask a clinic for a lipid profile (it gives triglycerides and HDL).',
    'hdl': 'Ask a clinic for a lipid profile (it gives triglycerides and HDL).',
  };

  @override
  MhResult evaluate(Map<String, int> answers) {
    final present = [for (final q in questions) if (answers[q.key] == yes) q.key];
    final missing = [for (final q in questions) if (answers[q.key] == unknown || !answers.containsKey(q.key)) q.key];
    final met = present.length;

    final findings = <MhFinding>[
      for (final k in present)
        MhFinding(_signNames[k]!, 'Present: one of the five signs.', MhTone.warn),
      if (missing.isNotEmpty)
        MhFinding(
          'Still to find out',
          // Both blood fats come from one test, so it's named once.
          {for (final k in missing) _howToFind[k]!}.join(' '),
          MhTone.warn,
        ),
      const MhFinding(
        'What helps',
        'Losing even a little weight around the waist, walking most days, less sugar, salt and fried '
            'food, and not smoking all improve these signs.',
        MhTone.good,
      ),
    ];

    if (met >= 3) {
      return MhResult(
        score: met,
        level: 'likely',
        headline: 'Likely metabolic syndrome',
        summary: '$met of 5 signs. Together these raise the risk of heart disease, stroke and type 2 '
            'diabetes. Please see a health worker to confirm with tests and plan treatment.',
        tone: MhTone.alert,
        findings: findings,
      );
    }
    if (met + missing.length >= 3) {
      return MhResult(
        score: met,
        level: 'unclear',
        headline: "Can't tell yet",
        summary: '$met of 5 signs found, and ${missing.length} not known. With 3 or more it would count '
            'as metabolic syndrome, so the missing ones are worth finding out.',
        tone: MhTone.warn,
        findings: findings,
      );
    }
    return MhResult(
      score: met,
      level: 'unlikely',
      headline: 'Not metabolic syndrome',
      summary: met == 0
          ? 'None of the 5 signs. Keep checking every year or two.'
          : '$met of 5 signs: below the 3 that make metabolic syndrome, but '
              '${met == 1 ? "it is" : "each is"} still worth working on.',
      tone: met == 0 ? MhTone.good : MhTone.warn,
      findings: findings,
    );
  }

  @override
  String scoreText(int score) => '$score of 5 signs';
}

// ═══════════════════════════════════════════════════════════════════════
// Lifestyle: 7 areas
// ═══════════════════════════════════════════════════════════════════════

class LifestyleTool extends MhTool {
  const LifestyleTool();

  @override
  String get type => 'lifestyle';
  @override
  String get title => 'Lifestyle';
  @override
  String get emoji => '🏃';
  @override
  String get blurb => 'Tobacco, alcohol, activity, food, salt, sleep, mood';
  @override
  String get intro =>
      'Short questions on seven everyday habits. You get one tip for each area worth working on, '
      'not a score to worry about.';

  /// Until "how often" is answered the drinking questions count as asked,
  /// so the question count only ever goes down (10, then 8 for a non-drinker).
  static bool _drinks(Map<String, int> a) => (a['alcohol_often'] ?? 1) > 0;

  @override
  List<MhQuestion> get questions => const [
        MhQuestion(
          key: 'tobacco',
          text: 'Do you use any tobacco now?',
          hint: 'Cigarettes, shisha, snuff, kuber, or chewing tobacco.',
          options: [
            MhOption('No, never', 0),
            MhOption('No, I stopped', 1),
            MhOption('Yes', 2),
          ],
        ),
        MhQuestion(
          key: 'alcohol_often',
          text: 'How often do you have a drink containing alcohol?',
          options: [
            MhOption('Never', 0),
            MhOption('Monthly or less', 1),
            MhOption('2 to 4 times a month', 2),
            MhOption('2 to 3 times a week', 3),
            MhOption('4 or more times a week', 4),
          ],
        ),
        MhQuestion(
          key: 'alcohol_amount',
          text: 'On a day when you drink, how many drinks do you usually have?',
          hint: 'One drink is half a 500 ml bottle of beer, a small glass (100 ml) of wine, or one tot '
              "of spirits. So one 500 ml beer is 2 drinks. Chang'aa is often as strong as spirits.",
          showIf: _drinks,
          options: [
            MhOption('1 or 2', 0),
            MhOption('3 or 4', 1),
            MhOption('5 or 6', 2),
            MhOption('7 to 9', 3),
            MhOption('10 or more', 4),
          ],
        ),
        MhQuestion(
          key: 'alcohol_heavy',
          text: 'How often do you have 6 or more drinks on one occasion?',
          hint: 'For example, 3 bottles (500 ml) of beer.',
          showIf: _drinks,
          options: [
            MhOption('Never', 0),
            MhOption('Less than monthly', 1),
            MhOption('Monthly', 2),
            MhOption('Weekly', 3),
            MhOption('Daily or almost daily', 4),
          ],
        ),
        MhQuestion(
          key: 'activity',
          text: 'In a usual week, how much time do you spend on activity that makes you breathe harder '
              'than normal?',
          hint: 'Brisk walking, digging, carrying loads, cycling, sport. Physical work counts.',
          options: [
            MhOption('Little or none', 0),
            MhOption('Some, but less than 2½ hours a week', 1),
            MhOption('2½ hours a week or more', 2),
          ],
        ),
        MhQuestion(
          key: 'fruit_veg',
          text: 'On a usual day, how many servings of fruit and vegetables do you eat?',
          hint: 'One serving is a medium fruit (a banana or orange), half a cup of cooked vegetables '
              '(sukuma wiki, cabbage, managu), or a cup of raw salad. Potatoes and cassava do not count.',
          options: [
            MhOption('0 to 2', 0),
            MhOption('3 or 4', 1),
            MhOption('5 or more', 2),
          ],
        ),
        MhQuestion(
          key: 'salt',
          text: 'How often do you add salt or a salty sauce to your food at the table?',
          options: [
            MhOption('Always or often', 2),
            MhOption('Sometimes', 1),
            MhOption('Rarely or never', 0),
          ],
        ),
        MhQuestion(
          key: 'sleep',
          text: 'On a usual night, how many hours do you sleep?',
          options: [
            MhOption('Less than 7 hours', 0),
            MhOption('7 to 9 hours', 1),
            MhOption('More than 9 hours', 2),
          ],
        ),
        MhQuestion(
          key: 'mood_interest',
          text: 'Over the last 2 weeks, how often have you had little interest or pleasure in doing things?',
          options: [
            MhOption('Not at all', 0),
            MhOption('Several days', 1),
            MhOption('More than half the days', 2),
            MhOption('Nearly every day', 3),
          ],
        ),
        MhQuestion(
          key: 'mood_down',
          text: 'Over the last 2 weeks, how often have you felt down, depressed or hopeless?',
          options: [
            MhOption('Not at all', 0),
            MhOption('Several days', 1),
            MhOption('More than half the days', 2),
            MhOption('Nearly every day', 3),
          ],
        ),
      ];

  @override
  Map<String, String> get levels => const {
        'on_track': 'All on track',
        'some': 'A few areas to work on',
        'several': 'Several areas to work on',
      };

  static const areas = 7;

  /// AUDIT-C: 0 to 12. "Never" drinkers score 0.
  static int auditC(Map<String, int> a) =>
      (a['alcohol_often'] ?? 0) > 0 ? (a['alcohol_often'] ?? 0) + (a['alcohol_amount'] ?? 0) + (a['alcohol_heavy'] ?? 0) : 0;

  /// PHQ-2: 0 to 6.
  static int phq2(Map<String, int> a) => (a['mood_interest'] ?? 0) + (a['mood_down'] ?? 0);

  @override
  MhResult evaluate(Map<String, int> answers) {
    final a = answers;
    final work = <MhFinding>[];
    final good = <String>[];

    switch (a['tobacco']) {
      case 2:
        work.add(const MhFinding(
          'Tobacco',
          'Stopping is the single best thing you can do for your heart and lungs. Ask a health worker '
              'about help to quit: with support, far more people succeed.',
          MhTone.alert,
        ));
      case 1:
        good.add('No tobacco: well done for stopping');
      default:
        good.add('No tobacco');
    }

    final audit = auditC(a);
    if (audit >= 8) {
      work.add(MhFinding(
        'Alcohol',
        'Your answers (score $audit of 12) suggest drinking that is very likely harming your health. '
            'Please talk to a health worker. Cutting down suddenly after heavy daily drinking can be '
            'dangerous, so get advice first.',
        MhTone.alert,
      ));
    } else if (audit >= 4) {
      work.add(MhFinding(
        'Alcohol',
        'Your answers (score $audit of 12) are above the safer level for men. Try more alcohol-free '
            'days each week, and fewer drinks on the days you drink.',
        MhTone.warn,
      ));
    } else {
      good.add(_drinks(a) ? 'Alcohol: within the safer level' : 'No alcohol');
    }

    if ((a['activity'] ?? 0) < 2) {
      work.add(const MhFinding(
        'Activity',
        'Aim for 2½ hours a week of activity that makes you breathe harder: about 30 minutes on 5 '
            'days. Brisk walking counts, and every bit helps.',
        MhTone.warn,
      ));
    } else {
      good.add('Active enough');
    }

    if ((a['fruit_veg'] ?? 0) < 2) {
      work.add(const MhFinding(
        'Fruit and vegetables',
        'Aim for 5 servings a day, for example a fruit with breakfast and vegetables with lunch and '
            'supper.',
        MhTone.warn,
      ));
    } else {
      good.add('5 a day of fruit and vegetables');
    }

    if (a['salt'] == 2) {
      work.add(const MhFinding(
        'Salt',
        "Taste before adding salt. Adults should have less than one teaspoon (5 g) a day in total, "
            'and most of it is already in cooked and packaged food. Too much raises blood pressure.',
        MhTone.warn,
      ));
    } else {
      good.add('Salt at the table: not often');
    }

    switch (a['sleep']) {
      case 0:
        work.add(const MhFinding(
          'Sleep',
          'Adults need at least 7 hours. Regular short sleep raises the risk of high blood pressure '
              'and weight gain. If snoring or waking stops you sleeping well, mention it to a health '
              'worker.',
          MhTone.warn,
        ));
      case 2:
        work.add(const MhFinding(
          'Sleep',
          'Regularly needing more than 9 hours can be a sign of low mood or another health problem, '
              "especially if you're still tired. Worth mentioning to a health worker.",
          MhTone.warn,
        ));
      default:
        good.add('7 to 9 hours of sleep');
    }

    final mood = phq2(a);
    if (mood >= 3) {
      work.add(MhFinding(
        'Mood',
        'Your answers (score $mood of 6) suggest you may be depressed. Please take the depression '
            'check on the Mental wellbeing page, and talk to someone you trust or a health worker.',
        MhTone.alert,
      ));
    } else {
      good.add('Mood: no sign of depression');
    }

    final count = work.length;
    final level = count == 0 ? 'on_track' : (count <= 2 ? 'some' : 'several');
    return MhResult(
      score: count,
      level: level,
      headline: count == 0
          ? 'All 7 areas on track'
          : '${areas - count} of $areas areas on track',
      summary: count == 0
          ? 'Nothing to change from these answers. Keep it up.'
          : 'One tip for each area worth working on. Small changes add up.',
      tone: work.any((f) => f.tone == MhTone.alert)
          ? MhTone.alert
          : (count == 0 ? MhTone.good : MhTone.warn),
      findings: [
        ...work,
        if (good.isNotEmpty) MhFinding('On track', good.join(' · '), MhTone.good),
      ],
    );
  }

  @override
  String scoreText(int score) => score == 0 ? 'All on track' : '${areas - score} of $areas on track';
}

// ═══════════════════════════════════════════════════════════════════════
// Heart risk and prostate: unchanged questions and scoring
// ═══════════════════════════════════════════════════════════════════════

class HeartRiskTool extends MhTool {
  const HeartRiskTool();

  @override
  String get type => 'cardiovascular';
  @override
  String get title => 'Heart risk';
  @override
  String get emoji => '❤️';
  @override
  String get blurb => 'Age, cholesterol, blood pressure, smoking, diabetes';
  @override
  String get intro =>
      'Seven questions about the main things that raise the risk of heart disease. '
      'This is a rough guide, not a diagnosis.';

  @override
  List<MhQuestion> get questions => const [
        MhQuestion(key: 'age', text: 'Your age range', options: [
          MhOption('30-39', 0), MhOption('40-49', 1), MhOption('50-59', 2), MhOption('60-69', 3), MhOption('70-79', 4),
        ]),
        MhQuestion(key: 'total_cholesterol', text: 'Total cholesterol (mg/dL)', options: [
          MhOption('<160', 0), MhOption('160-199', 1), MhOption('200-239', 2), MhOption('240-279', 3), MhOption('280+', 4),
        ]),
        MhQuestion(key: 'hdl', text: 'HDL cholesterol (mg/dL)', options: [
          MhOption('60+', 0), MhOption('50-59', 1), MhOption('40-49', 2), MhOption('<40', 3),
        ]),
        MhQuestion(key: 'systolic_bp', text: 'Systolic blood pressure', options: [
          MhOption('<120', 0), MhOption('120-129', 1), MhOption('130-139', 2), MhOption('140-159', 3), MhOption('160+', 4),
        ]),
        MhQuestion(key: 'bp_treatment', text: 'On blood pressure medication?', options: [
          MhOption('No', 0), MhOption('Yes', 2),
        ]),
        MhQuestion(key: 'smoker', text: 'Current smoker?', options: [MhOption('No', 0), MhOption('Yes', 2)]),
        MhQuestion(key: 'diabetes', text: 'Diabetic?', options: [MhOption('No', 0), MhOption('Yes', 2)]),
      ];

  @override
  Map<String, String> get levels => const {
        'low': 'Low risk',
        'moderate': 'Moderate risk',
        'high': 'High risk',
        'very_high': 'Very high risk',
      };

  static String interpretation(int score) {
    if (score <= 5) return 'low';
    if (score <= 10) return 'moderate';
    if (score <= 15) return 'high';
    return 'very_high';
  }

  static const _messages = {
    'low': 'Your cardiovascular risk is low. Maintain a healthy lifestyle with regular exercise and balanced diet.',
    'moderate': 'Moderate risk. Consider lifestyle changes: reduce salt, exercise regularly, quit smoking.',
    'high': 'High risk. Please consult a healthcare provider for a comprehensive cardiovascular assessment.',
    'very_high': 'Very high risk. Urgent medical consultation recommended. Blood pressure and cholesterol '
        'management may be needed.',
  };

  @override
  MhResult evaluate(Map<String, int> answers) {
    final score = questions.fold(0, (int s, q) => s + (answers[q.key] ?? 0));
    final level = interpretation(score);
    return MhResult(
      score: score,
      level: level,
      headline: levels[level]!,
      summary: _messages[level]!,
      tone: switch (level) { 'low' => MhTone.good, 'moderate' => MhTone.warn, _ => MhTone.alert },
    );
  }

  @override
  String scoreText(int score) => 'Score $score';
}

class ProstateTool extends MhTool {
  const ProstateTool();

  @override
  String get type => 'prostate';
  @override
  String get title => 'Prostate health';
  @override
  String get emoji => '🩺';
  @override
  String get blurb => 'Urinary symptoms: the IPSS, 7 questions';
  @override
  String get intro =>
      'Seven questions doctors use to measure urinary symptoms that can come from the prostate '
      '(the IPSS).';
  @override
  String get preamble => 'Over the last month:';

  static const _often = [
    MhOption('Not at all', 0),
    MhOption('Less than 1 time in 5', 1),
    MhOption('Less than half the time', 2),
    MhOption('About half the time', 3),
    MhOption('More than half the time', 4),
    MhOption('Almost always', 5),
  ];

  @override
  List<MhQuestion> get questions => const [
        MhQuestion(
            key: 'incomplete_emptying',
            text: 'How often have you had a feeling of not emptying your bladder completely after urinating?',
            options: _often),
        MhQuestion(
            key: 'frequency',
            text: 'How often have you had to urinate again less than two hours after you finished urinating?',
            options: _often),
        MhQuestion(
            key: 'intermittent',
            text: 'How often have you found you stopped and started again several times when you urinated?',
            options: _often),
        MhQuestion(key: 'urgency', text: 'How often have you found it difficult to put off urinating?', options: _often),
        MhQuestion(key: 'weak_stream', text: 'How often have you had a weak urinary stream?', options: _often),
        MhQuestion(key: 'straining', text: 'How often have you had to push or strain to begin urinating?', options: _often),
        MhQuestion(
          key: 'nocturia',
          text: 'How many times did you usually get up to urinate from going to bed at night until getting up '
              'in the morning?',
          options: [
            MhOption('None', 0),
            MhOption('1 time', 1),
            MhOption('2 times', 2),
            MhOption('3 times', 3),
            MhOption('4 times', 4),
            MhOption('5 or more times', 5),
          ],
        ),
      ];

  @override
  Map<String, String> get levels => const {
        'mild': 'Mild symptoms',
        'moderate': 'Moderate symptoms',
        'severe': 'Severe symptoms',
      };

  static String severity(int score) {
    if (score <= 7) return 'mild';
    if (score <= 19) return 'moderate';
    return 'severe';
  }

  static const _messages = {
    'mild': 'Your symptoms are mild. Continue monitoring and maintain hydration. Consider annual screening after age 50.',
    'moderate': 'Moderate symptoms detected. Consult a urologist for PSA testing and prostate examination.',
    'severe': 'Severe symptoms require medical attention. Please see a urologist promptly.',
  };

  @override
  MhResult evaluate(Map<String, int> answers) {
    final score = questions.fold(0, (int s, q) => s + (answers[q.key] ?? 0));
    final level = severity(score);
    return MhResult(
      score: score,
      level: level,
      headline: levels[level]!,
      summary: 'Score $score of 35. ${_messages[level]!}',
      tone: switch (level) { 'mild' => MhTone.good, 'moderate' => MhTone.warn, _ => MhTone.alert },
    );
  }

  @override
  String scoreText(int score) => '$score of 35';
}
