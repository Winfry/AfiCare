import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/mens_health_model.dart';

void main() {
  group('MensHealthScreening CVD Risk Interpretation', () {
    test('score 0-5 = low', () {
      expect(MensHealthScreening.cvdRiskInterpretation(0), 'low');
      expect(MensHealthScreening.cvdRiskInterpretation(5), 'low');
    });

    test('score 6-10 = moderate', () {
      expect(MensHealthScreening.cvdRiskInterpretation(6), 'moderate');
      expect(MensHealthScreening.cvdRiskInterpretation(10), 'moderate');
    });

    test('score 11-15 = high', () {
      expect(MensHealthScreening.cvdRiskInterpretation(11), 'high');
      expect(MensHealthScreening.cvdRiskInterpretation(15), 'high');
    });

    test('score 16+ = very_high', () {
      expect(MensHealthScreening.cvdRiskInterpretation(16), 'very_high');
      expect(MensHealthScreening.cvdRiskInterpretation(20), 'very_high');
    });
  });

  group('MensHealthScreening IPSS Severity', () {
    test('score 0-7 = mild', () {
      expect(MensHealthScreening.ipssSeverity(0), 'mild');
      expect(MensHealthScreening.ipssSeverity(7), 'mild');
    });

    test('score 8-19 = moderate', () {
      expect(MensHealthScreening.ipssSeverity(8), 'moderate');
      expect(MensHealthScreening.ipssSeverity(19), 'moderate');
    });

    test('score 20-35 = severe', () {
      expect(MensHealthScreening.ipssSeverity(20), 'severe');
      expect(MensHealthScreening.ipssSeverity(35), 'severe');
    });

    test('max IPSS score is 35 (7 questions x max 5)', () {
      expect(MensHealthScreening.ipssSeverity(35), 'severe');
    });
  });

  group('MensHealthScreening screening labels', () {
    test('screeningLabel returns correct labels', () {
      expect(MensHealthScreening.screeningLabel('cardiovascular'), 'Cardiovascular Risk (Framingham)');
      expect(MensHealthScreening.screeningLabel('prostate'), 'Prostate Health (IPSS)');
      expect(MensHealthScreening.screeningLabel('lifestyle'), 'Lifestyle & Wellness');
      expect(MensHealthScreening.screeningLabel('erectile'), 'Sexual Health (IIEF-5)');
      expect(MensHealthScreening.screeningLabel('metabolic'), 'Metabolic Syndrome');
    });

    test('screeningDescription returns non-empty for all types', () {
      for (final type in ['cardiovascular', 'prostate', 'lifestyle', 'erectile', 'metabolic']) {
        final desc = MensHealthScreening.screeningDescription(type);
        expect(desc.isNotEmpty, true, reason: '$type should have a description');
      }
    });

    test('riskLevelLabel returns correct labels', () {
      expect(MensHealthScreening.riskLevelLabel('low'), 'Low Risk');
      expect(MensHealthScreening.riskLevelLabel('moderate'), 'Moderate Risk');
      expect(MensHealthScreening.riskLevelLabel('high'), 'High Risk');
      expect(MensHealthScreening.riskLevelLabel('very_high'), 'Very High Risk');
    });
  });

  group('MensHealthScreening CVD questions', () {
    test('has 7 CVD questions', () {
      expect(MensHealthScreening.cvdQuestions.length, 7);
    });

    test('all CVD questions have matching scores and options', () {
      for (final q in MensHealthScreening.cvdQuestions) {
        final options = (q['options'] as List).cast<String>();
        final scores = (q['scores'] as List).cast<int>();
        expect(options.length, scores.length, reason: '${q['key']} options/scores mismatch');
        expect(options.isNotEmpty, true, reason: '${q['key']} has no options');
      }
    });

    test('CVD total max score is 21', () {
      int maxScore = 0;
      for (final q in MensHealthScreening.cvdQuestions) {
        final scores = (q['scores'] as List).cast<int>();
        maxScore += scores.reduce((a, b) => a > b ? a : b);
      }
      expect(maxScore, 21);
    });
  });

  group('MensHealthScreening IPSS questions', () {
    test('has 7 IPSS questions', () {
      expect(MensHealthScreening.ipssQuestions.length, 7);
    });

    test('all IPSS questions have 6 options (0-5 scoring)', () {
      for (final q in MensHealthScreening.ipssQuestions) {
        final options = (q['options'] as List).cast<String>();
        final scores = (q['scores'] as List).cast<int>();
        expect(options.length, 6, reason: '${q['key']} should have 6 options');
        expect(scores, [0, 1, 2, 3, 4, 5], reason: '${q['key']} scores wrong');
      }
    });
  });

  group('MensHealthScreening fromJson/toJson', () {
    test('round-trip preserves all fields', () {
      final screening = MensHealthScreening(
        id: 'mh-1',
        patientId: 'p-1',
        screeningType: 'prostate',
        responses: {'q1': 3, 'q2': 2},
        riskScore: 12,
        riskLevel: 'moderate',
        completedAt: DateTime(2026, 8, 1),
      );

      final restored = MensHealthScreening.fromJson(screening.toJson());
      expect(restored.id, 'mh-1');
      expect(restored.screeningType, 'prostate');
      expect(restored.riskScore, 12);
      expect(restored.riskLevel, 'moderate');
      expect(restored.responses['q1'], 3);
    });
  });
}
