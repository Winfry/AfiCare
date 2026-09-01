import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/services/pdf_export_service.dart';

Future<String> html(Future<Uint8List> generator) async =>
    String.fromCharCodes(await generator);

void main() {
  group('PdfExportService referral form', () {
    test('includes patient and referral fields', () async {
      final h = await html(PdfExportService.generateReferralForm({
        'patient_name': 'Jane Doe',
        'medilink_id': 'ML-000001',
        'dob': '1990-01-01',
        'gender': 'Female',
        'referring_provider': 'Dr. Otieno',
        'from_facility': 'Kenyatta Hospital',
        'to_facility': 'Moi Hospital',
        'specialty': 'Cardiology',
        'urgency': 'Urgent',
        'reason': 'Chest pain',
        'clinical_notes': 'ECG abnormal',
      }));

      expect(h, contains('Medical Referral Form'));
      expect(h, contains('Jane Doe'));
      expect(h, contains('ML-000001'));
      expect(h, contains('Dr. Otieno'));
      expect(h, contains('Moi Hospital'));
      expect(h, contains('Cardiology'));
    });

    test('falls back to empty strings for missing fields', () async {
      final h = await html(PdfExportService.generateReferralForm({}));
      expect(h, contains('Medical Referral Form'));
    });
  });

  group('PdfExportService prescription receipt', () {
    test('includes medication details', () async {
      final h = await html(PdfExportService.generatePrescriptionReceipt({
        'patient_name': 'Jane Doe',
        'provider_name': 'Dr. Otieno',
        'medication_name': 'Amoxicillin',
        'dosage': '500mg',
        'frequency': '3 times daily',
        'duration': '5 days',
        'instructions': 'After meals',
        'prescription_id': 'RX-123',
      }));

      expect(h, contains('Prescription Receipt'));
      expect(h, contains('Amoxicillin'));
      expect(h, contains('500mg'));
      expect(h, contains('RX-123'));
    });
  });

  group('PdfExportService lab result', () {
    test('renders one row per result', () async {
      final h = await html(PdfExportService.generateLabResult({
        'patient_name': 'Jane Doe',
        'facility_name': 'Clinic A',
        'results': [
          {'test': 'CBC', 'value': '12.0', 'unit': 'g/dL', 'flag': 'low'},
          {'test': 'WBC', 'value': '8000', 'unit': '/mm3'},
        ],
      }));

      expect(h, contains('Laboratory Results'));
      expect(h, contains('CBC'));
      expect(h, contains('WBC'));
    });

    test('handles missing results list', () async {
      final h = await html(PdfExportService.generateLabResult({}));
      expect(h, contains('Laboratory Results'));
    });
  });

  group('PdfExportService radiology result', () {
    test('includes findings and impression', () async {
      final h = await html(PdfExportService.generateRadiologyResult({
        'patient_name': 'Jane Doe',
        'study_type': 'X-Ray',
        'body_part': 'Chest',
        'findings': 'Normal heart size',
        'impression': 'No acute disease',
        'recommendations': 'Reassurance',
      }));

      expect(h, contains('Radiology Report'));
      expect(h, contains('Chest'));
      expect(h, contains('No acute disease'));
    });
  });

  test('_renderHtml returns non-empty bytes', () async {
    final bytes = await PdfExportService.generateReferralForm(
        {'patient_name': 'x'});
    expect(bytes, isNotEmpty);
  });
}
