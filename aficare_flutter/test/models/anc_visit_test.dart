import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/anc_visit_model.dart';

void main() {
  group('AncVisit trimester calculation', () {
    test('weeks 1-12 = first trimester', () {
      expect(AncVisit.trimesterFromWeeks(1), 'first');
      expect(AncVisit.trimesterFromWeeks(6), 'first');
      expect(AncVisit.trimesterFromWeeks(12), 'first');
    });

    test('weeks 13-27 = second trimester', () {
      expect(AncVisit.trimesterFromWeeks(13), 'second');
      expect(AncVisit.trimesterFromWeeks(20), 'second');
      expect(AncVisit.trimesterFromWeeks(27), 'second');
    });

    test('weeks 28-40 = third trimester', () {
      expect(AncVisit.trimesterFromWeeks(28), 'third');
      expect(AncVisit.trimesterFromWeeks(36), 'third');
      expect(AncVisit.trimesterFromWeeks(40), 'third');
    });
  });

  group('AncVisit trimesterLabel', () {
    test('returns correct labels', () {
      expect(AncVisit.trimesterLabel('first'), '1st Trimester (Weeks 1-12)');
      expect(AncVisit.trimesterLabel('second'), '2nd Trimester (Weeks 13-27)');
      expect(AncVisit.trimesterLabel('third'), '3rd Trimester (Weeks 28-40)');
    });

    test('unknown trimester returns raw string', () {
      expect(AncVisit.trimesterLabel('unknown'), 'unknown');
    });
  });

  group('AncVisit danger signs list', () {
    test('has 12 danger signs', () {
      expect(AncVisit.dangerSignsList.length, 12);
    });

    test('includes critical signs', () {
      expect(AncVisit.dangerSignsList, contains('Severe headache'));
      expect(AncVisit.dangerSignsList, contains('Vaginal bleeding'));
      expect(AncVisit.dangerSignsList, contains('Reduced fetal movement'));
      expect(AncVisit.dangerSignsList, contains('Convulsions/seizures'));
    });
  });

  group('AncVisit fromJson/toJson', () {
    test('round-trip preserves all fields', () {
      final visit = AncVisit(
        id: 'anc-1',
        patientId: 'p-1',
        visitNumber: 3,
        gestationalWeeks: 24,
        trimester: 'second',
        visitDate: DateTime(2026, 6, 15),
        systolicBP: 120,
        diastolicBP: 80,
        weight: 65.5,
        hemoglobin: 11.2,
        dangerSigns: ['Severe headache'],
        facility: 'Mama Lucy Hospital',
      );

      final restored = AncVisit.fromJson(visit.toJson());
      expect(restored.id, 'anc-1');
      expect(restored.visitNumber, 3);
      expect(restored.gestationalWeeks, 24);
      expect(restored.trimester, 'second');
      expect(restored.systolicBP, 120);
      expect(restored.weight, 65.5);
      expect(restored.dangerSigns, ['Severe headache']);
      expect(restored.facility, 'Mama Lucy Hospital');
    });

    test('fromJson handles null/missing fields', () {
      final visit = AncVisit.fromJson({});
      expect(visit.visitNumber, 1);
      expect(visit.gestationalWeeks, 0);
      expect(visit.dangerSigns, isEmpty);
    });

    test('fromJson with null numeric fields', () {
      final visit = AncVisit.fromJson({
        'systolic_bp': null,
        'weight': null,
        'hemoglobin': null,
      });
      expect(visit.systolicBP, isNull);
      expect(visit.weight, isNull);
      expect(visit.hemoglobin, isNull);
    });
  });
}
