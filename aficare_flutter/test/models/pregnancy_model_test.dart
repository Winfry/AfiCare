import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/pregnancy_model.dart';

void main() {
  Pregnancy fromLmp(DateTime lmp) =>
      Pregnancy(id: 'p1', patientId: 'u1', lmpDate: lmp, dueDate: Pregnancy.dueDateFromLmp(lmp));

  group('dates', () {
    test('due date is 280 days after the LMP, across a month and year end', () {
      expect(Pregnancy.dueDateFromLmp(DateTime(2026, 5, 10)), DateTime(2027, 2, 14));
      expect(Pregnancy.dueDateFromLmp(DateTime(2026, 3, 29)), DateTime(2027, 1, 3));
    });

    test('weeks, days and trimester are counted from the LMP', () {
      final p = fromLmp(DateTime(2026, 5, 10));
      expect(p.weeksOn(DateTime(2026, 5, 10)), 0);
      expect(p.weeksOn(DateTime(2026, 8, 2)), 12);
      expect(p.trimesterOn(DateTime(2026, 8, 2)), 'first');
      expect(p.weeksOn(DateTime(2026, 8, 9)), 13);
      expect(p.trimesterOn(DateTime(2026, 8, 9)), 'second');
      expect(p.weeksOn(DateTime(2026, 10, 25)), 24);
      expect(p.extraDaysOn(DateTime(2026, 10, 28)), 3);
      expect(p.trimesterOn(DateTime(2026, 11, 22)), 'third'); // week 28
    });

    test('a due date from a scan dates the pregnancy back 40 weeks', () {
      final p = Pregnancy(id: 'p1', patientId: 'u1', dueDate: DateTime(2027, 2, 14), dueDateSource: 'scan');
      expect(p.datingStart, DateTime(2026, 5, 10));
      expect(p.weeksOn(DateTime(2026, 10, 25)), 24);
    });

    test('days to due go negative once it has passed', () {
      final p = fromLmp(DateTime(2026, 5, 10));
      expect(p.daysToDueOn(DateTime(2027, 2, 4)), 10);
      expect(p.daysToDueOn(DateTime(2027, 2, 14)), 0);
      expect(p.daysToDueOn(DateTime(2027, 2, 17)), -3);
    });

    test('progress stays between 0 and 1', () {
      final p = fromLmp(DateTime(2026, 5, 10));
      expect(p.progressOn(DateTime(2026, 4, 1)), 0);
      expect(p.progressOn(DateTime(2026, 9, 27)), closeTo(0.5, 0.001)); // day 140
      expect(p.progressOn(DateTime(2027, 3, 1)), 1);
    });

    test('a date before the pregnancy counts as week 0, never negative', () {
      final p = fromLmp(DateTime(2026, 5, 10));
      expect(p.weeksOn(DateTime(2026, 4, 1)), 0);
      expect(p.extraDaysOn(DateTime(2026, 4, 1)), 0);
    });
  });

  group('antenatal contacts', () {
    test('eight recommended, never fewer than none to go', () {
      expect(Pregnancy.ancContactWeeks, hasLength(8));
      expect(Pregnancy.contactsToGo(0), 8);
      expect(Pregnancy.contactsToGo(3), 5);
      expect(Pregnancy.contactsToGo(10), 0);
    });

    test('next contact week after the current week', () {
      expect(Pregnancy.nextContactWeekAfter(0), 12);
      expect(Pregnancy.nextContactWeekAfter(12), 20);
      expect(Pregnancy.nextContactWeekAfter(24), 26);
      expect(Pregnancy.nextContactWeekAfter(40), isNull);
    });
  });

  group('checks', () {
    final today = DateTime(2026, 10, 27);

    test('LMP must be past and at most 44 weeks ago', () {
      expect(Pregnancy.checkLmp(DateTime(2026, 6, 1), today), isNull);
      expect(Pregnancy.checkLmp(today, today), isNull);
      expect(Pregnancy.checkLmp(DateTime(2026, 10, 28), today), contains('future'));
      expect(Pregnancy.checkLmp(today.subtract(const Duration(days: 44 * 7 + 1)), today), contains('44 weeks'));
    });

    test('due date within 42 weeks ahead or 4 weeks past', () {
      expect(Pregnancy.checkDueDate(DateTime(2027, 3, 1), today), isNull);
      expect(Pregnancy.checkDueDate(today.subtract(const Duration(days: 28)), today), isNull);
      expect(Pregnancy.checkDueDate(today.subtract(const Duration(days: 29)), today), contains('four weeks'));
      expect(Pregnancy.checkDueDate(today.add(const Duration(days: 42 * 7 + 1)), today), contains('42 weeks'));
    });
  });

  group('json', () {
    test('reads a database row and writes only the app-owned columns', () {
      final p = Pregnancy.fromJson({
        'id': 'p1',
        'patient_id': 'u1',
        'lmp_date': '2026-05-10',
        'due_date': '2027-02-14',
        'due_date_source': 'lmp',
        'status': 'ended',
        'outcome': 'birth',
        'ended_on': '2027-02-10',
        'created_at': '2026-07-01T08:00:00+00:00',
      });
      expect(p.isOngoing, isFalse);
      expect(p.lmpDate, DateTime(2026, 5, 10));
      expect(p.endedOn, DateTime(2027, 2, 10));
      expect(p.toJson(), {
        'patient_id': 'u1',
        'lmp_date': '2026-05-10',
        'due_date': '2027-02-14',
        'due_date_source': 'lmp',
        'status': 'ended',
        'outcome': 'birth',
        'ended_on': '2027-02-10',
      });
    });

    test('every outcome the app offers is one the database accepts', () {
      // Must match the CHECK on pregnancies.outcome in 041_pregnancies.sql.
      expect(Pregnancy.outcomes.keys.toSet(), {'birth', 'loss', 'other', 'not_said'});
      expect(Pregnancy.dueDateSources.keys.toSet(), {'lmp', 'scan', 'clinician'});
    });
  });
}
