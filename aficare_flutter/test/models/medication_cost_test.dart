import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/medication_cost_model.dart';

void main() {
  group('MedicationBudget.calculate', () {
    test('calculates spent amount correctly for current month', () {
      final now = DateTime.now();
      final costs = [
        MedicationCost(
          id: '1', patientId: 'p1', medicationName: 'Metformin',
          dosage: '500mg', quantity: 30, unitCost: 100, totalCost: 3000,
          purchaseDate: DateTime(now.year, now.month, 5),
        ),
        MedicationCost(
          id: '2', patientId: 'p1', medicationName: 'Amlodipine',
          dosage: '5mg', quantity: 30, unitCost: 150, totalCost: 4500,
          purchaseDate: DateTime(now.year, now.month, 10),
        ),
      ];

      final budget = MedicationBudget.calculate(
        patientId: 'p1',
        monthlyBudget: 10000,
        costs: costs,
      );

      expect(budget.spentThisMonth, 7500);
      expect(budget.remaining, 2500);
      expect(budget.isOverBudget, false);
      expect(budget.isNearLimit, false);
    });

    test('detects over-budget', () {
      final now = DateTime.now();
      final costs = [
        MedicationCost(
          id: '1', patientId: 'p1', medicationName: 'Expensive Drug',
          dosage: '100mg', quantity: 1, unitCost: 15000, totalCost: 15000,
          purchaseDate: DateTime(now.year, now.month, 1),
        ),
      ];

      final budget = MedicationBudget.calculate(
        patientId: 'p1',
        monthlyBudget: 10000,
        costs: costs,
      );

      expect(budget.isOverBudget, true);
      expect(budget.remaining, -5000);
    });

    test('detects near-limit (>80%)', () {
      final now = DateTime.now();
      final costs = [
        MedicationCost(
          id: '1', patientId: 'p1', medicationName: 'Drug',
          dosage: '10mg', quantity: 1, unitCost: 8500, totalCost: 8500,
          purchaseDate: DateTime(now.year, now.month, 1),
        ),
      ];

      final budget = MedicationBudget.calculate(
        patientId: 'p1',
        monthlyBudget: 10000,
        costs: costs,
      );

      expect(budget.isNearLimit, true);
      expect(budget.isOverBudget, false);
      expect(budget.usagePercentage, closeTo(85.0, 0.1));
    });

    test('ignores costs from previous months', () {
      final now = DateTime.now();
      final costs = [
        MedicationCost(
          id: '1', patientId: 'p1', medicationName: 'Old Drug',
          dosage: '10mg', quantity: 1, unitCost: 5000, totalCost: 5000,
          purchaseDate: DateTime(now.year, now.month - 1, 1),
        ),
        MedicationCost(
          id: '2', patientId: 'p1', medicationName: 'New Drug',
          dosage: '10mg', quantity: 1, unitCost: 2000, totalCost: 2000,
          purchaseDate: DateTime(now.year, now.month, 1),
        ),
      ];

      final budget = MedicationBudget.calculate(
        patientId: 'p1',
        monthlyBudget: 10000,
        costs: costs,
      );

      expect(budget.spentThisMonth, 2000);
      expect(budget.remaining, 8000);
    });

    test('zero budget results in zero usage', () {
      final budget = MedicationBudget.calculate(
        patientId: 'p1',
        monthlyBudget: 0,
        costs: [],
      );
      expect(budget.usagePercentage, 0);
    });
  });

  group('MedicationCost payment labels', () {
    test('paymentMethodLabel returns correct labels', () {
      expect(MedicationCost.paymentMethodLabel('cash'), 'Cash');
      expect(MedicationCost.paymentMethodLabel('nhif'), 'NHIF');
      expect(MedicationCost.paymentMethodLabel('insurance'), 'Insurance');
      expect(MedicationCost.paymentMethodLabel('mhealth'), 'M-Pesa');
      expect(MedicationCost.paymentMethodLabel('free'), 'Free (Subsidized)');
    });
  });

  group('MedicationCost fromJson/toJson', () {
    test('round-trip preserves all fields', () {
      final cost = MedicationCost(
        id: 'mc-1',
        patientId: 'p-1',
        medicationName: 'Metformin',
        dosage: '500mg',
        quantity: 60,
        unitCost: 100,
        totalCost: 6000,
        pharmacyName: 'Good Life Pharmacy',
        paymentMethod: 'nhif',
        purchaseDate: DateTime(2026, 8, 1),
      );

      final restored = MedicationCost.fromJson(cost.toJson());
      expect(restored.id, 'mc-1');
      expect(restored.medicationName, 'Metformin');
      expect(restored.unitCost, 100);
      expect(restored.totalCost, 6000);
      expect(restored.paymentMethod, 'nhif');
    });
  });
}
