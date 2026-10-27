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


  group('Live tables (042)', () {
    test('receipts offer SHA, and only values the table accepts', () {
      // Must match receipts_payment_method_check in 042.
      const accepted = {'cash', 'sha', 'nhif', 'insurance', 'mpesa', 'card', 'subsidized'};
      expect(accepted.containsAll(Receipt.paymentMethodOptions.keys), isTrue);
      expect(Receipt.paymentMethodOptions.containsKey('nhif'), isFalse);
      expect(Receipt.paymentMethodLabel('sha'), 'SHA');
      expect(Receipt.paymentMethodLabel('nhif'), 'NHIF');
    });

    test('a claim is written with the table\'s own column names', () {
      final json = InsuranceClaim(
        id: 'ic-2',
        patientId: 'p-1',
        insuranceType: 'sha',
        insuranceNumber: 'SHA-123',
        claimType: 'maternity',
        claimStatus: 'draft',
        claimedAmount: 1500,
        dateOfService: DateTime(2026, 10, 20, 9),
        createdAt: DateTime(2026, 10, 27),
      ).toJson();
      expect(json['insurance_provider'], 'sha');
      expect(json['policy_number'], 'SHA-123');
      expect(json['claim_type'], 'maternity');
      expect(json['amount'], 1500);
      expect(json['status'], 'draft');
      expect(json['service_date'], '2026-10-20');
      for (final gone in ['insurance_type', 'insurance_number', 'claim_status', 'claimed_amount',
          'date_of_service', 'services', 'approved_amount']) {
        expect(json.containsKey(gone), isFalse, reason: gone);
      }
    });

    test('a live row reads back, and the old "in_review" becomes "under_review"', () {
      final c = InsuranceClaim.fromJson({
        'id': 'ic-3',
        'patient_id': 'p-1',
        'insurance_provider': 'private',
        'policy_number': 'AAR-9',
        'claim_type': 'dental',
        'amount': 4000,
        'status': 'under_review',
        'service_date': '2026-09-01',
        'created_at': '2026-09-02T08:00:00Z',
      });
      expect(c.insuranceType, 'private');
      expect(c.insuranceNumber, 'AAR-9');
      expect(c.claimType, 'dental');
      expect(c.claimedAmount, 4000);
      expect(c.claimStatus, 'under_review');
      expect(InsuranceClaim.statusLabel('under_review'), 'Under Review');
      expect(InsuranceClaim.fromJson({'status': 'in_review'}).claimStatus, 'under_review');
    });

    test('statuses and claim types are exactly the ones the table accepts', () {
      // Must match the CHECKs on insurance_claims (042 pre-check).
      expect(InsuranceClaim.statuses.toSet(),
          {'draft', 'submitted', 'under_review', 'approved', 'rejected', 'paid'});
      expect(InsuranceClaim.claimTypes.keys.toSet(),
          {'outpatient', 'inpatient', 'emergency', 'maternity', 'chronic', 'dental', 'optical', 'other'});
      expect(InsuranceClaim.insurerOptions.containsKey('sha'), isTrue);
    });

    test('a reminder is written with "times", the column 042 renames to', () {
      final json = MedicationReminder(
        id: 'mr-1',
        patientId: 'dep-1',
        medicationName: 'Amoxil',
        dosage: '5ml',
        frequency: 'twice_daily',
        times: [ReminderTime(hour: 8, minute: 0)],
        createdAt: DateTime(2026, 10, 27),
      ).toJson();
      expect(json.containsKey('times'), isTrue);
      expect(json.containsKey('reminder_times'), isFalse);
    });
  });
}
