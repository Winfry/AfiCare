import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/womens_health_model.dart';

void main() {
  group('WomensHealthRecord.fromJson', () {
    test('reads what the old dashboard saved', () {
      final r = WomensHealthRecord.fromJson({
        'pregnancy_status': 'trying',
        'checklist': {'folic_acid': true, 'exercise': false},
        'menstrual_pain': 6.0,
        'cycle_length': 30,
        'period_duration': 4,
        'last_pap_smear': '2024-03-12T00:00:00.000',
        'last_mammogram': null,
        'next_period': '2026-10-20T00:00:00.000',
      });
      expect(r.lifeStage, 'trying');
      expect(r.checklist, {'folic_acid': true, 'exercise': false});
      expect(r.periodPain, 6);
      expect(r.cycleLength, 30);
      expect(r.periodLength, 4);
      expect(r.lastCervicalScreening, DateTime(2024, 3, 12));
      expect(r.lastMammogram, isNull);
      expect(r.savedNextPeriod, DateTime(2026, 10, 20));
    });

    test('falls back to defaults for missing or nonsense values', () {
      final r = WomensHealthRecord.fromJson({
        'pregnancy_status': 'something_else',
        'cycle_length': 400,
        'period_duration': 0,
        'menstrual_pain': 42,
        'checklist': 'not a map',
      });
      expect(r.lifeStage, 'not_pregnant');
      expect(r.cycleLength, WomensHealthRecord.defaultCycleLength);
      expect(r.periodLength, WomensHealthRecord.defaultPeriodLength);
      expect(r.periodPain, 10);
      expect(r.checklist, isEmpty);
    });

    test('null gives an empty record with no pain recorded', () {
      final r = WomensHealthRecord.fromJson(null);
      expect(r.lifeStage, 'not_pregnant');
      expect(r.periodPain, isNull);
      expect(r.expectedNextPeriod(DateTime(2026, 10, 13)), isNull);
    });

    test('keeps keys it does not manage when written back', () {
      final r = WomensHealthRecord.fromJson({'pregnancy_status': 'pregnant', 'future_field': 7});
      final json = r.toJson();
      expect(json['future_field'], 7);
      expect(json['pregnancy_status'], 'pregnant');
    });
  });

  group('cycle', () {
    final today = DateTime(2026, 10, 13);

    test('predicts one cycle after the last logged start', () {
      final r = WomensHealthRecord(lastPeriodStart: DateTime(2026, 10, 1), cycleLength: 28);
      expect(r.expectedNextPeriod(today), DateTime(2026, 10, 29));
      expect(r.daysUntilNextPeriod(today), 16);
    });

    test('a logged start takes over from a hand-typed prediction', () {
      final old = WomensHealthRecord(savedNextPeriod: DateTime(2026, 12, 1));
      expect(old.expectedNextPeriod(today), DateTime(2026, 12, 1));
      final logged = old.copyWith(lastPeriodStart: DateTime(2026, 10, 10));
      expect(logged.savedNextPeriod, isNull);
      expect(logged.expectedNextPeriod(today), DateTime(2026, 11, 7));
    });

    test('reports a late period as negative days', () {
      final r = WomensHealthRecord(lastPeriodStart: DateTime(2026, 9, 1), cycleLength: 28);
      expect(r.daysUntilNextPeriod(today), -14);
    });

    test('knows when a period is under way', () {
      final r = WomensHealthRecord(lastPeriodStart: DateTime(2026, 10, 11), periodLength: 5);
      expect(r.onPeriod(today), isTrue);
      expect(r.onPeriod(DateTime(2026, 10, 16)), isFalse);
    });

    test('counts days across a month end and a year end', () {
      final r = WomensHealthRecord(lastPeriodStart: DateTime(2026, 12, 20), cycleLength: 28);
      expect(r.expectedNextPeriod(today), DateTime(2027, 1, 17));
    });

    test('flags cycles outside 21 to 35 days', () {
      expect(const WomensHealthRecord(cycleLength: 28).cycleOutsideTypicalRange, isFalse);
      expect(const WomensHealthRecord(cycleLength: 19).cycleOutsideTypicalRange, isTrue);
      expect(const WomensHealthRecord(cycleLength: 40).cycleOutsideTypicalRange, isTrue);
    });

    test('toJson writes the prediction to next_period for old readers', () {
      final r = WomensHealthRecord(lastPeriodStart: DateTime.now().subtract(const Duration(days: 3)));
      final next = r.expectedNextPeriod(DateTime.now())!;
      expect(r.toJson()['next_period'], next.toIso8601String().split('T').first);
    });
  });

  group('screenings', () {
    final today = DateTime(2026, 10, 13);

    test('nothing recorded under the starting age is "not yet"', () {
      const r = WomensHealthRecord();
      expect(r.breastStatus(today, age: 32).state, ScreeningState.notYet);
      expect(r.cervicalStatus(today, age: 32).state, ScreeningState.notRecorded);
      expect(r.cervicalStatus(today).state, ScreeningState.notRecorded);
    });

    test('cervical screening is due three years later', () {
      final r = WomensHealthRecord(lastCervicalScreening: DateTime(2025, 3, 12));
      final s = r.cervicalStatus(today);
      expect(s.state, ScreeningState.upToDate);
      expect(s.dueDate, DateTime(2028, 3, 12));
    });

    test('due within three months is "due soon"', () {
      final r = WomensHealthRecord(lastCervicalScreening: DateTime(2023, 12, 1));
      expect(r.cervicalStatus(today).state, ScreeningState.dueSoon);
    });

    test('past the due date is overdue', () {
      final r = WomensHealthRecord(lastMammogram: DateTime(2024, 1, 5));
      final s = r.breastStatus(today, age: 50);
      expect(s.state, ScreeningState.overdue);
      expect(s.dueDate, DateTime(2026, 1, 5));
    });

    test('clearing a date removes it', () {
      final r = WomensHealthRecord(lastMammogram: DateTime(2024, 1, 5));
      expect(r.copyWith(clearMammogram: true).lastMammogram, isNull);
    });
  });

  group('ScreeningStatus.addMonths', () {
    test('keeps the day where it exists', () {
      expect(ScreeningStatus.addMonths(DateTime(2024, 3, 12), 36), DateTime(2027, 3, 12));
    });

    test('clamps to the last day of a shorter month', () {
      expect(ScreeningStatus.addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(ScreeningStatus.addMonths(DateTime(2023, 1, 31), 1), DateTime(2023, 2, 28));
    });

    test('rolls over the year', () {
      expect(ScreeningStatus.addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });
}
