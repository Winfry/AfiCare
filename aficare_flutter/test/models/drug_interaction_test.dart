import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/drug_interaction_model.dart';

void main() {
  group('DrugInteractionService', () {
    test('has 16 known interactions', () {
      expect(DrugInteractionService.knownInteractions.length, 16);
    });

    test('no interactions with single medication', () {
      final result = DrugInteractionService.checkInteractions(['Warfarin']);
      expect(result, isEmpty);
    });

    test('no interactions with empty list', () {
      final result = DrugInteractionService.checkInteractions([]);
      expect(result, isEmpty);
    });

    test('Warfarin + Aspirin = severe interaction', () {
      final result = DrugInteractionService.checkInteractions(['Warfarin', 'Aspirin']);
      expect(result.length, 1);
      expect(result.first.drug1, 'Warfarin');
      expect(result.first.drug2, 'Aspirin');
      expect(result.first.severity, 'severe');
    });

    test('Metformin + Alcohol = severe interaction', () {
      final result = DrugInteractionService.checkInteractions(['Metformin', 'Alcohol']);
      expect(result.length, 1);
      expect(result.first.severity, 'severe');
    });

    test('Lisinopril + Potassium = moderate interaction', () {
      final result = DrugInteractionService.checkInteractions(['Lisinopril', 'Potassium']);
      expect(result.length, 1);
      expect(result.first.severity, 'moderate');
    });

    test('Amlodipine + Simvastatin = moderate interaction', () {
      final result = DrugInteractionService.checkInteractions(['Amlodipine', 'Simvastatin']);
      expect(result.length, 1);
      expect(result.first.severity, 'moderate');
    });

    test('Omeprazole + Clopidogrel = severe interaction', () {
      final result = DrugInteractionService.checkInteractions(['Omeprazole', 'Clopidogrel']);
      expect(result.length, 1);
      expect(result.first.severity, 'severe');
    });

    test('case-insensitive matching', () {
      final result = DrugInteractionService.checkInteractions(['warfarin', 'aspirin']);
      expect(result.length, 1);
      expect(result.first.severity, 'severe');
    });

    test('partial name matching works', () {
      final result = DrugInteractionService.checkInteractions(['Warfarin 5mg', 'Aspirin 100mg']);
      expect(result.length, 1);
    });

    test('reversed drug order still detected', () {
      final result = DrugInteractionService.checkInteractions(['Aspirin', 'Warfarin']);
      expect(result.length, 1);
      expect(result.first.severity, 'severe');
    });

    test('multiple medications with multiple interactions', () {
      final result = DrugInteractionService.checkInteractions([
        'Warfarin', 'Aspirin', 'Ibuprofen', 'Lisinopril',
      ]);
      // Warfarin+Aspirin (severe), Warfarin+Ibuprofen (severe), Ibuprofen+Lisinopril (moderate)
      expect(result.length, 3);
    });

    test('checkNewMedication detects interactions', () {
      final result = DrugInteractionService.checkNewMedication('Warfarin', ['Aspirin']);
      expect(result.length, 1);
      expect(result.first.severity, 'severe');
    });

    test('checkNewMedication no interaction', () {
      final result = DrugInteractionService.checkNewMedication('Paracetamol', ['Amoxicillin']);
      expect(result, isEmpty);
    });

    test('non-interacting medications produce empty result', () {
      final result = DrugInteractionService.checkInteractions(['Paracetamol', 'Amoxicillin', 'Omeprazole']);
      expect(result, isEmpty);
    });
  });

  group('DrugInteraction labels', () {
    test('severityLabel returns correct strings', () {
      expect(DrugInteraction.severityLabel('severe'), 'Severe — Avoid Combination');
      expect(DrugInteraction.severityLabel('moderate'), 'Moderate — Monitor Closely');
      expect(DrugInteraction.severityLabel('mild'), 'Mild — Low Risk');
      expect(DrugInteraction.severityLabel('unknown'), 'unknown');
    });
  });

  group('DrugInteraction recommendation field', () {
    test('all interactions have recommendations', () {
      for (final interaction in DrugInteractionService.knownInteractions) {
        expect(interaction.recommendation.isNotEmpty, true,
            reason: '${interaction.drug1} + ${interaction.drug2} missing recommendation');
      }
    });
  });
}
