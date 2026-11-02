import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/vaccination_model.dart';

void main() {
  group('VaccinationSchedule Kenya EPI', () {
    test('has 19 vaccines in schedule', () {
      expect(VaccinationSchedule.kenyaEPI.length, 19);
    });

    test('includes BCG at birth', () {
      final bcg = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'BCG');
      expect(bcg.minAgeWeeks, 0);
      expect(bcg.maxAgeWeeks, 1);
      expect(bcg.category, 'child');
    });

    test('includes OPV 0 at birth', () {
      final opv0 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'OPV 0');
      expect(opv0.minAgeWeeks, 0);
      expect(opv0.type, 'OPV');
    });

    test('includes 6-week vaccines (Penta 1, PCV 1, Rota 1)', () {
      final penta1 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Penta 1');
      expect(penta1.minAgeWeeks, 6);
      expect(penta1.maxAgeWeeks, 8);

      final pcv1 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'PCV 1');
      expect(pcv1.minAgeWeeks, 6);

      final rota1 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Rota 1');
      expect(rota1.minAgeWeeks, 6);
    });

    test('includes 9-month vaccines (MR 1, Yellow Fever, R21 Malaria)', () {
      final mr1 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Measles-Rubella 1');
      expect(mr1.minAgeWeeks, 36);
      expect(mr1.maxAgeWeeks, 44);

      final yf = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Yellow Fever');
      expect(yf.minAgeWeeks, 36);

      final r21 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Malaria (R21)');
      expect(r21.minAgeWeeks, 36);
    });

    test('includes 18-month MR 2 booster', () {
      final mr2 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'Measles-Rubella 2');
      expect(mr2.minAgeWeeks, 72);
      expect(mr2.maxAgeWeeks, 80);
    });

    test('all vaccines have required fields', () {
      for (final v in VaccinationSchedule.kenyaEPI) {
        expect(v.name.isNotEmpty, true);
        expect(v.type.isNotEmpty, true);
        expect(v.description.isNotEmpty, true);
        expect(['child', 'adolescent', 'adult', 'maternal'].contains(v.category), true);
      }
    });
  });

  group('VaccinationSchedule.getDueSchedules', () {
    test('newborn (week 0) gets BCG, OPV 0, HepB 0', () {
      final due = VaccinationSchedule.getDueSchedules(0);
      final names = due.map((v) => v.name).toList();
      expect(names, containsAll(['BCG', 'OPV 0', 'HepB 0']));
    });

    test('6-week-old gets 6-week vaccines', () {
      final due = VaccinationSchedule.getDueSchedules(6);
      final names = due.map((v) => v.name).toList();
      expect(names, containsAll(['OPV 1', 'Penta 1', 'PCV 1', 'Rota 1']));
    });

    test('10-week-old gets 10-week vaccines', () {
      final due = VaccinationSchedule.getDueSchedules(10);
      final names = due.map((v) => v.name).toList();
      expect(names, containsAll(['OPV 2', 'Penta 2', 'PCV 2', 'Rota 2']));
    });

    test('14-week-old gets 14-week vaccines', () {
      final due = VaccinationSchedule.getDueSchedules(14);
      final names = due.map((v) => v.name).toList();
      expect(names, containsAll(['OPV 3', 'Penta 3', 'PCV 3', 'IPV']));
    });

    test('9-month-old (36 weeks) gets MR1, YF, R21', () {
      final due = VaccinationSchedule.getDueSchedules(36);
      final names = due.map((v) => v.name).toList();
      expect(names, containsAll(['Measles-Rubella 1', 'Yellow Fever', 'Malaria (R21)']));
    });

    test('18-month-old (76 weeks) gets MR2', () {
      final due = VaccinationSchedule.getDueSchedules(76);
      final names = due.map((v) => v.name).toList();
      expect(names, contains('Measles-Rubella 2'));
    });
  });

  group('VaccinationSchedule.isGiven', () {
    VaccineSchedule dose(String name) => VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == name);

    test('matches the exact dose only', () {
      expect(VaccinationSchedule.isGiven(dose('OPV 0'), ['OPV 0']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('OPV 1'), ['OPV 0']), isFalse);
      expect(VaccinationSchedule.isGiven(dose('OPV 3'), ['OPV 0', 'OPV 1', 'OPV 2']), isFalse);
      expect(VaccinationSchedule.isGiven(dose('Measles-Rubella 2'), ['Measles-Rubella 1']), isFalse);
    });

    test('reads other ways of writing the same dose', () {
      expect(VaccinationSchedule.isGiven(dose('Penta 1'), ['Pentavalent 1']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('Penta 2'), ['penta-2']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('OPV 1'), ['OPV dose 1']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('Measles-Rubella 1'), ['MR1']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('Measles-Rubella 1'), ['Measles Rubella 1']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('BCG'), ['BCG vaccine']), isTrue);
      expect(VaccinationSchedule.isGiven(dose('Yellow Fever'), ['YF']), isTrue);
    });

    test('only completed records count as given', () {
      final records = [
        VaccinationRecord(id: '1', patientId: 'p', vaccineName: 'BCG', dateGiven: DateTime(2026)),
        VaccinationRecord(id: '2', patientId: 'p', vaccineName: 'OPV 0', dateGiven: DateTime(2026), status: 'scheduled'),
        VaccinationRecord(id: '3', patientId: 'p', vaccineName: 'HepB 0', dateGiven: DateTime(2026), status: 'skipped'),
      ];
      expect(VaccinationSchedule.givenNames(records), ['BCG']);
    });
  });

  group('VaccinationSchedule.stateFor', () {
    final opv1 = VaccinationSchedule.kenyaEPI.firstWhere((v) => v.name == 'OPV 1');

    test('not yet, due, then overdue as a baby grows', () {
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 4, given: []), VaccineState.notYet);
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 6, given: []), VaccineState.due);
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 8, given: []), VaccineState.due);
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 9, given: []), VaccineState.overdue);
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 9, given: ['OPV 1']), VaccineState.given);
    });

    test('nothing is due for someone 5 or older, or of unknown age', () {
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: 260, given: []), VaccineState.notApplicable);
      expect(VaccinationSchedule.stateFor(opv1, ageWeeks: null, given: []), VaccineState.notApplicable);
      expect(VaccinationSchedule.dueNow(ageWeeks: 40 * 52, given: []), isEmpty);
      expect(VaccinationSchedule.dueNow(ageWeeks: 259, given: []), isNotEmpty, reason: 'under 5 can still catch up');
    });
  });

  group('VaccinationSchedule next dose', () {
    test('the next dose is the next one in the same series', () {
      expect(VaccinationSchedule.nextInSeries('OPV 0')?.name, 'OPV 1');
      expect(VaccinationSchedule.nextInSeries('OPV 2')?.name, 'OPV 3');
      expect(VaccinationSchedule.nextInSeries('OPV 3'), isNull, reason: 'not back to OPV 0');
      expect(VaccinationSchedule.nextInSeries('Measles-Rubella 1')?.name, 'Measles-Rubella 2');
      expect(VaccinationSchedule.nextInSeries('BCG'), isNull);
      expect(VaccinationSchedule.nextInSeries('Something else'), isNull);
    });

    test('due at the age the schedule sets, counted from birth', () {
      final dob = DateTime(2026, 1, 1);
      expect(
        VaccinationSchedule.nextDueDate('OPV 0', given: dob, dateOfBirth: dob),
        dob.add(const Duration(days: 42)),
      );
      expect(
        VaccinationSchedule.nextDueDate('Measles-Rubella 1', given: DateTime(2026, 9, 10), dateOfBirth: dob),
        dob.add(const Duration(days: 72 * 7)),
        reason: 'MR 2 at 18 months, not 4 weeks later',
      );
    });

    test('never sooner than 4 weeks after a late dose', () {
      final dob = DateTime(2026, 1, 1);
      final lateGiven = DateTime(2026, 4, 1); // Penta 1 at about 13 weeks
      expect(
        VaccinationSchedule.nextDueDate('Penta 1', given: lateGiven, dateOfBirth: dob),
        DateTime(2026, 4, 29),
      );
    });

    test('without a date of birth, the gap between doses counts from the date given', () {
      expect(
        VaccinationSchedule.nextDueDate('OPV 0', given: DateTime(2026, 3, 1)),
        DateTime(2026, 3, 1).add(const Duration(days: 42)),
      );
      expect(
        VaccinationSchedule.nextDueDate('Penta 1', given: DateTime(2026, 3, 1)),
        DateTime(2026, 3, 29),
      );
    });

    test('no next date after the last dose of a series', () {
      expect(VaccinationSchedule.nextDueDate('OPV 3', given: DateTime(2026, 3, 1)), isNull);
      expect(VaccinationSchedule.nextDueDate('BCG', given: DateTime(2026, 3, 1)), isNull);
    });
  });

  group('VaccinationRecord', () {
    test('fromJson/toJson round-trip', () {
      final record = VaccinationRecord(
        id: 'vr-1',
        patientId: 'p-1',
        vaccineName: 'BCG',
        dateGiven: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 4, 1),
        facility: 'Kenyatta Hospital',
        status: 'completed',
      );

      final restored = VaccinationRecord.fromJson(record.toJson());
      expect(restored.id, 'vr-1');
      expect(restored.vaccineName, 'BCG');
      expect(restored.facility, 'Kenyatta Hospital');
      expect(restored.status, 'completed');
    });
  });
}
