import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/mental_health_model.dart';
import 'package:aficare_flutter/screens/patient/mental_health_screen.dart';

/// PHQ-9 answers: the first eight questions, then question 9.
List<int> phq9(int q9, {int others = 0}) => [...List.filled(8, others), q9];

ScreeningOutcome outcome(List<int> answers, {String tool = 'PHQ-9', bool saved = true}) {
  final score = answers.fold(0, (int a, b) => a + b);
  return ScreeningOutcome(
    toolType: tool,
    answers: answers,
    score: score,
    severity: MentalHealthScreening.severityFromScore(tool, score),
    saved: saved,
  );
}

void main() {
  group('Question 9 on its own', () {
    test('any answer above "Not at all" counts, whatever the total', () {
      expect(MentalHealthScreening.selfHarmAnswered('PHQ-9', phq9(0)), isFalse);
      for (final a in [1, 2, 3]) {
        expect(MentalHealthScreening.selfHarmAnswered('PHQ-9', phq9(a)), isTrue, reason: 'answer $a');
      }
    });

    test('other questions, unfinished forms and anxiety forms never count', () {
      expect(MentalHealthScreening.selfHarmAnswered('PHQ-9', phq9(0, others: 3)), isFalse);
      expect(MentalHealthScreening.selfHarmAnswered('PHQ-9', [3, 3, 3]), isFalse);
      expect(MentalHealthScreening.selfHarmAnswered('GAD-7', [0, 0, 0, 0, 0, 0, 0, 0, 3]), isFalse);
    });

    test('a saved screening remembers it', () {
      final s = MentalHealthScreening.fromJson({'tool_type': 'PHQ-9', 'answers': phq9(3), 'total_score': 3});
      expect(s.reportedSelfHarmThoughts, isTrue);
    });
  });

  group('Result', () {
    Future<void> pump(WidgetTester tester, ScreeningOutcome o) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ScreeningResultView(outcome: o))),
      ));
    }

    testWidgets('"nearly every day" on question 9 with a low total gets the safety message first',
        (tester) async {
      await pump(tester, outcome(phq9(3)));

      expect(find.text('Minimal'), findsOneWidget, reason: 'the score is still shown honestly');
      expect(find.text("You don't have to carry this alone"), findsOneWidget);
      expect(find.text('1199'), findsOneWidget);
      expect(find.text('999 or 112'), findsOneWidget);
      expect(find.textContaining('Keep monitoring'), findsNothing);
      expect(tester.getTopLeft(find.text("You don't have to carry this alone")).dy,
          lessThan(tester.getTopLeft(find.text('Minimal')).dy));
    });

    testWidgets('no to question 9: the usual result, no safety message', (tester) async {
      await pump(tester, outcome(phq9(0)));

      expect(find.text("You don't have to carry this alone"), findsNothing);
      expect(find.textContaining('Keep monitoring'), findsOneWidget);
    });

    testWidgets('if saving failed the safety message still shows, and says it was not saved',
        (tester) async {
      await pump(tester, outcome(phq9(1), saved: false));

      expect(find.text("You don't have to carry this alone"), findsOneWidget);
      expect(find.textContaining("couldn't be saved"), findsOneWidget);
    });
  });
}
