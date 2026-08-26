import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/receipt_model.dart';
import 'package:aficare_flutter/models/insurance_claim_model.dart';
import 'package:aficare_flutter/models/medication_reminder_model.dart';

void main() {
  group('Receipt', () {
    test('fromJson/toJson round-trip', () {
      final receipt = Receipt(
        id: 'r-1',
        patientId: 'p-1',
        imageUrl: 'https://example.com/receipt.jpg',
        facilityName: 'Kenyatta Hospital',
        totalAmount: 2500,
        serviceType: 'Consultation',
        paymentMethod: 'nhif',
        date: DateTime(2026, 8, 15),
        createdAt: DateTime(2026, 8, 15),
      );

      final restored = Receipt.fromJson(receipt.toJson());
      expect(restored.id, 'r-1');
      expect(restored.facilityName, 'Kenyatta Hospital');
      expect(restored.totalAmount, 2500);
      expect(restored.paymentMethod, 'nhif');
    });

    test('paymentMethodLabel returns correct labels', () {
      expect(Receipt.paymentMethodLabel('cash'), 'Cash');
      expect(Receipt.paymentMethodLabel('nhif'), 'NHIF');
      expect(Receipt.paymentMethodLabel('insurance'), 'Insurance');
      expect(Receipt.paymentMethodLabel('mpesa'), 'M-Pesa');
      expect(Receipt.paymentMethodLabel('card'), 'Card');
      expect(Receipt.paymentMethodLabel('subsidized'), 'Subsidized');
    });

    test('serviceTypeOptions has 9 options', () {
      expect(Receipt.serviceTypeOptions.length, 9);
      expect(Receipt.serviceTypeOptions, contains('Consultation'));
      expect(Receipt.serviceTypeOptions, contains('Lab Test'));
      expect(Receipt.serviceTypeOptions, contains('Medication'));
    });

    test('fromJson handles null fields', () {
      final receipt = Receipt.fromJson({});
      expect(receipt.totalAmount, isNull);
      expect(receipt.facilityName, isNull);
      expect(receipt.paymentMethod, isNull);
    });
  });

  group('InsuranceClaim', () {
    test('statusLabel returns correct labels', () {
      expect(InsuranceClaim.statusLabel('draft'), 'Draft');
      expect(InsuranceClaim.statusLabel('submitted'), 'Submitted');
      expect(InsuranceClaim.statusLabel('in_review'), 'Under Review');
      expect(InsuranceClaim.statusLabel('approved'), 'Approved');
      expect(InsuranceClaim.statusLabel('rejected'), 'Rejected');
      expect(InsuranceClaim.statusLabel('paid'), 'Paid');
    });

    test('insuranceTypeLabel returns correct labels', () {
      expect(InsuranceClaim.insuranceTypeLabel('nhif'), 'NHIF');
      expect(InsuranceClaim.insuranceTypeLabel('private'), 'Private Insurance');
      expect(InsuranceClaim.insuranceTypeLabel('community'), 'Community Health Fund');
      expect(InsuranceClaim.insuranceTypeLabel('other'), 'Other');
    });

    test('fromJson/toJson round-trip', () {
      final claim = InsuranceClaim(
        id: 'ic-1',
        patientId: 'p-1',
        insuranceType: 'nhif',
        insuranceNumber: 'NHIF-12345',
        claimStatus: 'submitted',
        claimedAmount: 15000,
        facilityName: 'Mama Lucy',
        dateOfService: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 8, 2),
      );

      final restored = InsuranceClaim.fromJson(claim.toJson());
      expect(restored.id, 'ic-1');
      expect(restored.insuranceType, 'nhif');
      expect(restored.claimedAmount, 15000);
      expect(restored.claimStatus, 'submitted');
    });
  });

  group('MedicationReminder', () {
    test('frequencyLabel returns correct labels', () {
      expect(MedicationReminder.frequencyLabel('once_daily'), 'Once daily');
      expect(MedicationReminder.frequencyLabel('twice_daily'), 'Twice daily');
      expect(MedicationReminder.frequencyLabel('three_times'), '3 times daily');
      expect(MedicationReminder.frequencyLabel('four_times'), '4 times daily');
      expect(MedicationReminder.frequencyLabel('as_needed'), 'As needed');
    });

    test('fromJson/toJson round-trip', () {
      final reminder = MedicationReminder(
        id: 'mr-1',
        patientId: 'p-1',
        medicationName: 'Metformin',
        dosage: '500mg',
        frequency: 'twice_daily',
        times: [
          ReminderTime(hour: 8, minute: 0, label: 'Morning'),
          ReminderTime(hour: 20, minute: 0, label: 'Evening'),
        ],
        isActive: true,
        createdAt: DateTime(2026, 8, 1),
      );

      final restored = MedicationReminder.fromJson(reminder.toJson());
      expect(restored.medicationName, 'Metformin');
      expect(restored.frequency, 'twice_daily');
      expect(restored.times.length, 2);
    });
  });

  group('ReminderTime', () {
    test('formatted returns 12-hour time', () {
      expect(ReminderTime(hour: 8, minute: 0).formatted, '8:00 AM');
      expect(ReminderTime(hour: 13, minute: 30).formatted, '1:30 PM');
      expect(ReminderTime(hour: 0, minute: 0).formatted, '12:00 AM');
      expect(ReminderTime(hour: 12, minute: 0).formatted, '12:00 PM');
      expect(ReminderTime(hour: 23, minute: 59).formatted, '11:59 PM');
    });

    test('shortLabel returns time-of-day label', () {
      expect(ReminderTime(hour: 8, minute: 0).shortLabel, 'Morning');
      expect(ReminderTime(hour: 14, minute: 0).shortLabel, 'Afternoon');
      expect(ReminderTime(hour: 19, minute: 0).shortLabel, 'Evening');
      expect(ReminderTime(hour: 23, minute: 0).shortLabel, 'Night');
    });

    test('shortLabel uses custom label when provided', () {
      expect(ReminderTime(hour: 8, minute: 0, label: 'With breakfast').shortLabel, 'With breakfast');
    });
  });
}
