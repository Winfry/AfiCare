import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/mental_health_model.dart';

void main() {
  group('MentalHealthScreening PHQ-9 Severity', () {
    test('score 0-4 = none/minimal', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 0), 'none');
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 4), 'none');
    });

    test('score 5-9 = mild', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 5), 'mild');
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 9), 'mild');
    });

    test('score 10-14 = moderate', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 10), 'moderate');
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 14), 'moderate');
    });

    test('score 15-19 = moderately_severe', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 15), 'moderately_severe');
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 19), 'moderately_severe');
    });

    test('score 20-27 = severe', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 20), 'severe');
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 27), 'severe');
    });

    test('max PHQ-9 score is 27 (9 questions x max 3)', () {
      expect(MentalHealthScreening.severityFromScore('PHQ-9', 27), 'severe');
    });
  });

  group('MentalHealthScreening GAD-7 Severity', () {
    test('score 0-4 = none/minimal', () {
      expect(MentalHealthScreening.severityFromScore('GAD-7', 0), 'none');
      expect(MentalHealthScreening.severityFromScore('GAD-7', 4), 'none');
    });

    test('score 5-9 = mild', () {
      expect(MentalHealthScreening.severityFromScore('GAD-7', 5), 'mild');
      expect(MentalHealthScreening.severityFromScore('GAD-7', 9), 'mild');
    });

    test('score 10-14 = moderate', () {
      expect(MentalHealthScreening.severityFromScore('GAD-7', 10), 'moderate');
      expect(MentalHealthScreening.severityFromScore('GAD-7', 14), 'moderate');
    });

    test('score 15-21 = severe (no moderately_severe for GAD-7)', () {
      expect(MentalHealthScreening.severityFromScore('GAD-7', 15), 'severe');
      expect(MentalHealthScreening.severityFromScore('GAD-7', 21), 'severe');
    });

    test('max GAD-7 score is 21 (7 questions x max 3)', () {
      expect(MentalHealthScreening.severityFromScore('GAD-7', 21), 'severe');
    });
  });

  group('MentalHealthScreening severityLabel', () {
    test('maps severity keys to human labels', () {
      expect(MentalHealthScreening.severityLabel('none'), 'Minimal');
      expect(MentalHealthScreening.severityLabel('mild'), 'Mild');
      expect(MentalHealthScreening.severityLabel('moderate'), 'Moderate');
      expect(MentalHealthScreening.severityLabel('moderately_severe'), 'Moderately Severe');
      expect(MentalHealthScreening.severityLabel('severe'), 'Severe');
    });

    test('unknown severity returns raw string', () {
      expect(MentalHealthScreening.severityLabel('unknown'), 'unknown');
    });
  });

  group('MentalHealthScreening fromJson/toJson', () {
    test('round-trip preserves all fields', () {
      final now = DateTime.utc(2026, 3, 15, 10, 30);
      final screening = MentalHealthScreening(
        id: 'test-id-1',
        patientId: 'patient-1',
        toolType: 'PHQ-9',
        answers: [1, 2, 0, 3, 1, 2, 0, 1, 0],
        totalScore: 10,
        severity: 'moderate',
        completedAt: now,
        providerNotes: 'Follow up in 2 weeks',
      );

      final json = screening.toJson();
      final restored = MentalHealthScreening.fromJson(json);

      expect(restored.id, 'test-id-1');
      expect(restored.patientId, 'patient-1');
      expect(restored.toolType, 'PHQ-9');
      expect(restored.answers, [1, 2, 0, 3, 1, 2, 0, 1, 0]);
      expect(restored.totalScore, 10);
      expect(restored.severity, 'moderate');
      expect(restored.providerNotes, 'Follow up in 2 weeks');
    });

    test('fromJson handles null/missing fields gracefully', () {
      final screening = MentalHealthScreening.fromJson({});
      expect(screening.id, '');
      expect(screening.toolType, 'PHQ-9');
      expect(screening.answers, isEmpty);
      expect(screening.totalScore, 0);
    });
  });

  group('MoodEntry', () {
    test('moodEmoji maps correctly', () {
      expect(MoodEntry.moodEmoji(1), '😞');
      expect(MoodEntry.moodEmoji(2), '😟');
      expect(MoodEntry.moodEmoji(3), '😐');
      expect(MoodEntry.moodEmoji(4), '🙂');
      expect(MoodEntry.moodEmoji(5), '😊');
      expect(MoodEntry.moodEmoji(0), '😐'); // default
    });

    test('moodLabel maps correctly', () {
      expect(MoodEntry.moodLabel(1), 'Very Low');
      expect(MoodEntry.moodLabel(2), 'Low');
      expect(MoodEntry.moodLabel(3), 'Okay');
      expect(MoodEntry.moodLabel(4), 'Good');
      expect(MoodEntry.moodLabel(5), 'Great');
      expect(MoodEntry.moodLabel(99), 'Okay'); // default
    });

    test('fromJson handles missing fields', () {
      final entry = MoodEntry.fromJson({});
      expect(entry.mood, 3);
      expect(entry.factors, isEmpty);
    });

    test('toJson/fromJson round-trip', () {
      final entry = MoodEntry(
        id: 'm1',
        patientId: 'p1',
        mood: 4,
        journal: 'Felt good today',
        factors: ['exercise', 'sleep'],
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      final restored = MoodEntry.fromJson(entry.toJson());
      expect(restored.mood, 4);
      expect(restored.factors, ['exercise', 'sleep']);
    });
  });
}
