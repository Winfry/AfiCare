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


  group('MedicationCost and the live medication_costs table (042)', () {
    test('writes the table\'s own column names, and a date without a time', () {
      final json = MedicationCost(
        id: 'mc-2',
        patientId: 'p-1',
        medicationName: 'Metformin',
        dosage: '500mg',
        quantity: 60,
        unitCost: 20,
        totalCost: 1200,
        pharmacyName: 'Goodlife',
        paymentMethod: 'sha',
        purchaseDate: DateTime(2026, 10, 27, 14, 30),
      ).toJson();
      expect(json['cost'], 1200);
      expect(json['pharmacy'], 'Goodlife');
      expect(json['quantity'], 60);
      expect(json['purchase_date'], '2026-10-27');
      // Columns the table doesn't have would make every save fail.
      for (final gone in ['total_cost', 'unit_cost', 'pharmacy_name', 'facility_name', 'receipt_id']) {
        expect(json.containsKey(gone), isFalse, reason: gone);
      }
    });

    test('reads a live row and works out the unit cost', () {
      final c = MedicationCost.fromJson({
        'id': 'mc-3',
        'patient_id': 'p-1',
        'medication_name': 'Amoxil',
        'cost': 900,
        'quantity': 3,
        'pharmacy': 'Haltons',
        'payment_method': 'mpesa',
        'purchase_date': '2026-10-01',
      });
      expect(c.totalCost, 900);
      expect(c.unitCost, 300);
      expect(c.pharmacyName, 'Haltons');
    });

    test('offers SHA, not NHIF, and only values the table accepts', () {
      // Must match medication_costs_payment_method_check in 042.
      const accepted = {'cash', 'sha', 'nhif', 'insurance', 'mpesa', 'subsidized'};
      expect(accepted.containsAll(MedicationCost.paymentMethodOptions.keys), isTrue);
      expect(MedicationCost.paymentMethodOptions.containsKey('sha'), isTrue);
      expect(MedicationCost.paymentMethodOptions.containsKey('nhif'), isFalse);
      expect(MedicationCost.paymentMethodLabel('sha'), 'SHA');
      expect(MedicationCost.paymentMethodLabel('mpesa'), 'M-Pesa');
    });
  });
}
