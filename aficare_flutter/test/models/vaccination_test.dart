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
