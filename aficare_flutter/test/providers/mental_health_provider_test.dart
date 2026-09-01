import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/mental_health_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> screening({
    String id = 's1',
    String toolType = 'PHQ-9',
    int totalScore = 15,
    String completedAt = '2026-08-01T09:00:00.000Z',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'tool_type': toolType,
      'answers': <int>[2, 2, 2, 2, 0, 0, 0, 0, 0],
      'total_score': totalScore,
      'severity': 'moderately_severe',
      'completed_at': completedAt,
      'provider_notes': null,
    };
  }

  Map<String, dynamic> mood({
    String id = 'm1',
    int value = 4,
    String recordedAt = '2026-08-01T09:00:00.000Z',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'mood': value,
      'journal': null,
      'factors': <String>[],
      'recorded_at': recordedAt,
    };
  }

  group('MentalHealthProvider.loaders', () {
    test('loadScreenings and latest tool getters', () async {
      fake.routeJson('/rest/v1/mental_health_screenings', [
        screening(id: 'phq-latest', toolType: 'PHQ-9', totalScore: 16),
        screening(id: 'gad-latest', toolType: 'GAD-7', totalScore: 10, completedAt: '2026-07-01T09:00:00.000Z'),
      ]);

      final provider = MentalHealthProvider();
      await provider.loadScreenings('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.screenings, hasLength(2));
      expect(provider.latestPHQ9!.toolType, 'PHQ-9');
      expect(provider.latestGAD7!.toolType, 'GAD-7');
    });

    test('loadMoodEntries populates and averages', () async {
      fake.routeJson('/rest/v1/mood_entries', [
        mood(id: 'm1', value: 4),
        mood(id: 'm2', value: 2),
      ]);

      final provider = MentalHealthProvider();
      await provider.loadMoodEntries('p1');

      expect(provider.moodEntries, hasLength(2));
      expect(provider.averageMood, 3.0);
    });

    test('empty mood entries default to 3.0', () async {
      fake.routeJson('/rest/v1/mood_entries', <Object?>[]);

      final provider = MentalHealthProvider();
      await provider.loadMoodEntries('p1');

      expect(provider.moodEntries, isEmpty);
      expect(provider.averageMood, 3.0);
    });
  });

  group('MentalHealthProvider.saveScreening', () {
    test('inserts scored screening and prepends', () async {
      fake.routeJson('/rest/v1/mental_health_screenings', <String, dynamic>{});

      final provider = MentalHealthProvider();
      final ok = await provider.saveScreening(
        patientId: 'p1',
        toolType: 'PHQ-9',
        answers: [3, 3, 3, 3, 3, 3, 3, 3, 3],
      );

      expect(ok, isTrue);
      final insert =
          fake.requestsTo('POST', 'mental_health_screenings').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('tool_type', 'PHQ-9'));
      expect(body, containsPair('total_score', 27));
      expect(body, containsPair('severity', 'severe'));

      expect(provider.screenings.first.toolType, 'PHQ-9');
      expect(provider.screenings.first.totalScore, 27);
    });

    test('failure returns false', () async {
      fake.routeRaw(
        '/rest/v1/mental_health_screenings',
        http.Response('{"message":"denied"}', 403),
      );

      final provider = MentalHealthProvider();
      final ok = await provider.saveScreening(
        patientId: 'p1',
        toolType: 'GAD-7',
        answers: [1, 2],
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('MentalHealthProvider.saveMoodEntry', () {
    test('inserts and prepends a mood entry', () async {
      fake.routeJson('/rest/v1/mood_entries', <String, dynamic>{});

      final provider = MentalHealthProvider();
      final ok = await provider.saveMoodEntry(
        patientId: 'p1',
        mood: 5,
        journal: 'Feeling great',
        factors: ['exercise'],
      );

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'mood_entries').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('mood', 5));
      expect(body, containsPair('factors', ['exercise']));

      expect(provider.moodEntries.first.mood, 5);
    });
  });
}
