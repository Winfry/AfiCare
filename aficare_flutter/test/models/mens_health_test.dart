import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/mens_health_model.dart';
import 'package:aficare_flutter/models/mens_health_tools.dart';

/// Answers every asked question with the given value, then applies [over].
Map<String, int> answerAll(MhTool tool, int value, [Map<String, int> over = const {}]) {
  var a = <String, int>{...over};
  for (final q in tool.questions) {
    if (q.isAsked(a) && !a.containsKey(q.key)) a[q.key] = value;
  }
  return tool.keptAnswers(a);
}

void main() {
  group('Every tool', () {
    test('asks its own questions: none shares the heart-risk questions any more', () {
      final heartKeys = const HeartRiskTool().questions.map((q) => q.key).toSet();
      for (final tool in [const SexualHealthTool(), const MetabolicTool(), const LifestyleTool()]) {
        final keys = tool.questions.map((q) => q.key).toSet();
        expect(keys.intersection(heartKeys).difference({'hdl'}), isEmpty, reason: tool.type);
        expect(tool.questions, isNot(same(const HeartRiskTool().questions)), reason: tool.type);
      }
    });

    test('types are the five the database allows, each once', () {
      expect(MhTool.all.map((t) => t.type).toList()..sort(),
          ['cardiovascular', 'erectile', 'lifestyle', 'metabolic', 'prostate']);
    });

    test('question keys are unique, and every question has options with unique answers', () {
      for (final tool in MhTool.all) {
        final keys = tool.questions.map((q) => q.key).toList();
        expect(keys.toSet().length, keys.length, reason: tool.type);
        for (final q in tool.questions) {
          expect(q.options, isNotEmpty, reason: '${tool.type}.${q.key}');
          final labels = q.options.map((o) => o.label).toList();
          expect(labels.toSet().length, labels.length, reason: '${tool.type}.${q.key}');
        }
      }
    });

    test('every level a tool can produce is one it declares (and the database accepts)', () {
      const allowed = {
        'cardiovascular': {'low', 'moderate', 'high', 'very_high'},
        'prostate': {'mild', 'moderate', 'severe'},
        'erectile': {'none', 'mild', 'mild_moderate', 'moderate', 'severe', 'unscored'},
        'metabolic': {'unlikely', 'unclear', 'likely'},
        'lifestyle': {'on_track', 'some', 'several'},
      };
      for (final tool in MhTool.all) {
        expect(tool.levels.keys.toSet(), allowed[tool.type], reason: tool.type);
        // Try every answer to every question, one at a time, on top of
        // each uniform background answer.
        for (final q in tool.questions) {
          for (final o in q.options) {
            for (final base in q.options.map((x) => x.value).toSet()) {
              final a = answerAll(tool, base, {q.key: o.value});
              expect(allowed[tool.type], contains(tool.evaluate(a).level),
                  reason: '${tool.type} ${q.key}=${o.value} base=$base');
            }
          }
        }
      }
    });
  });

  group('Sexual health (IIEF-5)', () {
    const tool = SexualHealthTool();

    test('five questions, the first without a "no activity" answer', () {
      expect(tool.questions, hasLength(5));
      expect(tool.questions.first.options.map((o) => o.value), [1, 2, 3, 4, 5]);
      for (final q in tool.questions.skip(1)) {
        expect(q.options.map((o) => o.value), [0, 1, 2, 3, 4, 5], reason: q.key);
      }
    });

    test('the published bands', () {
      expect(SexualHealthTool.band(25), 'none');
      expect(SexualHealthTool.band(22), 'none');
      expect(SexualHealthTool.band(21), 'mild');
      expect(SexualHealthTool.band(17), 'mild');
      expect(SexualHealthTool.band(16), 'mild_moderate');
      expect(SexualHealthTool.band(12), 'mild_moderate');
      expect(SexualHealthTool.band(11), 'moderate');
      expect(SexualHealthTool.band(8), 'moderate');
      expect(SexualHealthTool.band(7), 'severe');
      expect(SexualHealthTool.band(5), 'severe');
    });

    test('all 5s: no problems, scored 25 of 25', () {
      final r = tool.evaluate(answerAll(tool, 5));
      expect(r.score, 25);
      expect(r.level, 'none');
      expect(r.tone, MhTone.good);
      expect(r.findings.map((f) => f.title), isNot(contains('Worth a check-up')));
    });

    test('a problem points to a heart and diabetes check and warns against unprescribed pills', () {
      final r = tool.evaluate(answerAll(tool, 3)); // 15
      expect(r.score, 15);
      expect(r.level, 'mild_moderate');
      final titles = r.findings.map((f) => f.title).toList();
      expect(titles, contains('Worth a check-up'));
      expect(titles, contains("Don't buy erection pills without advice"));
    });

    test('no sexual activity is "not enough to score", never "severe"', () {
      final r = tool.evaluate(answerAll(tool, 0, {'confidence': 3}));
      expect(r.level, 'unscored');
      expect(r.headline, 'Not enough to score');
    });

    test('always says infections are not covered', () {
      for (final v in [0, 3, 5]) {
        final r = tool.evaluate(answerAll(tool, v, {'confidence': v == 0 ? 1 : v}));
        expect(r.findings.map((f) => f.title), contains('Not covered here: infections'));
      }
    });
  });

  group('Metabolic health', () {
    const tool = MetabolicTool();
    const y = MetabolicTool.yes, n = MetabolicTool.no, u = MetabolicTool.unknown;

    Map<String, int> a(int waist, int bp, int sugar, int tg, int hdl) =>
        {'waist': waist, 'blood_pressure': bp, 'fasting_glucose': sugar, 'triglycerides': tg, 'hdl': hdl};

    test('3 or more of 5 signs: likely', () {
      final r = tool.evaluate(a(y, y, y, n, n));
      expect(r.level, 'likely');
      expect(r.score, 3);
      expect(r.tone, MhTone.alert);
    });

    test('taking medicine for a sign counts as having it', () {
      final bpMedicine = tool.questions.firstWhere((q) => q.key == 'blood_pressure')
          .options.firstWhere((o) => o.label.contains('medicine'));
      expect(bpMedicine.value, y);
      for (final q in tool.questions) {
        for (final o in q.options.where((o) => o.label.contains('medicine'))) {
          expect(o.value, y, reason: q.key);
        }
      }
    });

    test("2 signs with 1 unknown: can't tell yet, and says how to find out", () {
      final r = tool.evaluate(a(y, y, n, u, n));
      expect(r.level, 'unclear');
      expect(r.score, 2);
      final todo = r.findings.firstWhere((f) => f.title == 'Still to find out');
      expect(todo.detail, contains('lipid profile'));
    });

    test('both blood fats unknown name the lipid profile once', () {
      final r = tool.evaluate(a(n, n, u, u, u));
      final todo = r.findings.firstWhere((f) => f.title == 'Still to find out').detail;
      expect('lipid profile'.allMatches(todo).length, 1);
      expect(todo, contains('fasting blood sugar'));
    });

    test('2 signs, nothing unknown: not metabolic syndrome, but worth working on', () {
      final r = tool.evaluate(a(y, y, n, n, n));
      expect(r.level, 'unlikely');
      expect(r.tone, MhTone.warn);
      expect(r.summary, contains('each is'));
    });

    test('no signs: all clear', () {
      final r = tool.evaluate(a(n, n, n, n, n));
      expect(r.level, 'unlikely');
      expect(r.score, 0);
      expect(r.tone, MhTone.good);
    });

    test('nothing known at all is never "not metabolic syndrome"', () {
      expect(tool.evaluate(a(u, u, u, u, u)).level, 'unclear');
    });

    test('the cut-offs shown are the published ones for men', () {
      final text = tool.questions.expand((q) => q.options.map((o) => o.label)).join(' | ');
      expect(text, contains('94 cm'));
      expect(text, contains('130/85'));
      expect(text, contains('5.6 mmol/L'));
      expect(text, contains('1.7 mmol/L'));
      expect(text, contains('1.0 mmol/L'));
    });
  });

  group('Lifestyle', () {
    const tool = LifestyleTool();

    Map<String, int> healthy([Map<String, int> over = const {}]) => tool.keptAnswers({
          'tobacco': 0,
          'alcohol_often': 0,
          'activity': 2,
          'fruit_veg': 2,
          'salt': 0,
          'sleep': 1,
          'mood_interest': 0,
          'mood_down': 0,
          ...over,
        });

    test('the drinking questions are asked only of people who drink', () {
      expect(tool.askedQuestions({'alcohol_often': 0}).map((q) => q.key),
          isNot(contains('alcohol_amount')));
      expect(tool.askedQuestions({'alcohol_often': 2}).map((q) => q.key),
          containsAll(['alcohol_amount', 'alcohol_heavy']));
    });

    test('before "how often" is answered the drinking questions still count, so the total never grows', () {
      expect(tool.askedQuestions(const {}).length, 10);
      expect(tool.askedQuestions(const {'alcohol_often': 0}).length, 8);
    });

    test('changing to "Never" drops earlier drinking answers', () {
      final kept = tool.keptAnswers({'alcohol_often': 0, 'alcohol_amount': 4, 'alcohol_heavy': 4});
      expect(kept.keys, ['alcohol_often']);
    });

    test('healthy answers: all 7 on track', () {
      final a = healthy();
      expect(tool.isComplete(a), isTrue);
      final r = tool.evaluate(a);
      expect(r.level, 'on_track');
      expect(r.score, 0);
      expect(r.headline, 'All 7 areas on track');
    });

    test('AUDIT-C: men score 4 or more is above the safer level; 8 or more is harmful', () {
      expect(LifestyleTool.auditC({'alcohol_often': 0, 'alcohol_amount': 4}), 0);
      final three = tool.evaluate(healthy({'alcohol_often': 2, 'alcohol_amount': 1, 'alcohol_heavy': 0}));
      expect(three.findings.map((f) => f.title), isNot(contains('Alcohol')));
      final four = tool.evaluate(healthy({'alcohol_often': 2, 'alcohol_amount': 1, 'alcohol_heavy': 1}));
      final f4 = four.findings.firstWhere((f) => f.title == 'Alcohol');
      expect(f4.tone, MhTone.warn);
      final eight = tool.evaluate(healthy({'alcohol_often': 4, 'alcohol_amount': 2, 'alcohol_heavy': 2}));
      final f8 = eight.findings.firstWhere((f) => f.title == 'Alcohol');
      expect(f8.tone, MhTone.alert);
      expect(f8.detail, contains('get advice first'));
    });

    test('PHQ-2 of 3 or more points to the depression check', () {
      final r = tool.evaluate(healthy({'mood_interest': 2, 'mood_down': 1}));
      final mood = r.findings.firstWhere((f) => f.title == 'Mood');
      expect(mood.detail, contains('Mental wellbeing'));
      expect(r.tone, MhTone.alert);
      final two = tool.evaluate(healthy({'mood_interest': 1, 'mood_down': 1}));
      expect(two.findings.map((f) => f.title), isNot(contains('Mood')));
    });

    test('counts areas to work on, and the headline matches', () {
      final r = tool.evaluate(healthy({'tobacco': 2, 'activity': 0, 'fruit_veg': 1, 'sleep': 0}));
      expect(r.score, 4);
      expect(r.level, 'several');
      expect(r.headline, '3 of 7 areas on track');
      expect(tool.scoreText(4), '3 of 7 on track');
      expect(tool.evaluate(healthy({'salt': 2})).level, 'some');
    });

    test('having stopped tobacco is on track, and praised', () {
      final r = tool.evaluate(healthy({'tobacco': 1}));
      expect(r.level, 'on_track');
      expect(r.findings.last.detail, contains('well done for stopping'));
    });
  });

  group('Heart risk and prostate keep their scoring', () {
    test('heart risk bands', () {
      expect(HeartRiskTool.interpretation(5), 'low');
      expect(HeartRiskTool.interpretation(6), 'moderate');
      expect(HeartRiskTool.interpretation(10), 'moderate');
      expect(HeartRiskTool.interpretation(11), 'high');
      expect(HeartRiskTool.interpretation(15), 'high');
      expect(HeartRiskTool.interpretation(16), 'very_high');
    });

    test('IPSS bands', () {
      expect(ProstateTool.severity(7), 'mild');
      expect(ProstateTool.severity(8), 'moderate');
      expect(ProstateTool.severity(19), 'moderate');
      expect(ProstateTool.severity(20), 'severe');
      expect(const ProstateTool().evaluate(answerAll(const ProstateTool(), 5)).score, 35);
    });
  });

  group('Saved results', () {
    test('round-trips through JSON', () {
      final s = MensHealthScreening(
        id: 's1',
        patientId: 'p1',
        screeningType: 'metabolic',
        responses: const {'answers': {'waist': 1}},
        riskScore: 1,
        riskLevel: 'unlikely',
        completedAt: DateTime.utc(2026, 10, 31),
      );
      final back = MensHealthScreening.fromJson(s.toJson());
      expect(back.screeningType, 'metabolic');
      expect(back.answersByQuestion, {'waist': 1});
    });

    test('older rows saved as a list have no answers by question', () {
      final s = MensHealthScreening.fromJson({
        'screening_type': 'cardiovascular',
        'responses': {'answers': [1, 2, 3]},
        'risk_score': 6,
        'risk_level': 'moderate',
      });
      expect(s.answersByQuestion, isNull);
    });
  });
}
