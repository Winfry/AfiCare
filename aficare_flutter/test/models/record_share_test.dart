import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/record_share_model.dart';

Map<String, dynamic> _shareJson({
  String? revokedAt,
  String expiresAt = '2026-10-28T19:00:00Z',
  String? openedAt,
  String? openedByName,
  String? openedByRole,
  int viewCount = 0,
}) =>
    {
      'id': 's1',
      'code': 'ABCD2345',
      'sections': ['allergies', 'medications'],
      'created_at': '2026-10-28T15:00:00Z',
      'expires_at': expiresAt,
      'revoked_at': revokedAt,
      'opened_at': openedAt,
      'opened_by_name': openedByName,
      'opened_by_role': openedByRole,
      'last_viewed_at': openedAt,
      'view_count': viewCount,
    };

void main() {
  group('RecordShare', () {
    final now = DateTime.utc(2026, 10, 28, 16);

    test('reads what my_record_shares returns', () {
      final s = RecordShare.fromJson(_shareJson(
        openedAt: '2026-10-28T15:30:00Z',
        openedByName: 'Dr Otieno',
        openedByRole: 'doctor',
        viewCount: 2,
      ));
      expect(s.code, 'ABCD2345');
      expect(s.sections, ['allergies', 'medications']);
      expect(s.sectionLabels, 'Allergies, Medicines');
      expect(s.openedBy, 'Dr Otieno');
      expect(s.viewCount, 2);
      expect(s.isActiveAt(now), isTrue);
    });

    test('not opened yet has no opener', () {
      expect(RecordShare.fromJson(_shareJson()).openedBy, isNull);
    });

    test('an opener with no name is described by their role', () {
      final s = RecordShare.fromJson(_shareJson(openedAt: '2026-10-28T15:30:00Z', openedByRole: 'nurse'));
      expect(s.openedBy, 'a nurse');
    });

    test('stopped beats expired, and expired is not active', () {
      final stopped = RecordShare.fromJson(_shareJson(revokedAt: '2026-10-28T15:10:00Z'));
      expect(stopped.statusAt(now), ShareStatus.revoked);

      final expired = RecordShare.fromJson(_shareJson(expiresAt: '2026-10-28T15:59:00Z'));
      expect(expired.statusAt(now), ShareStatus.expired);
      expect(expired.isActiveAt(now), isFalse);
    });

    test('codes: shown in two halves, typed any way', () {
      expect(RecordShare.formatCode('abcd2345'), 'ABCD-2345');
      expect(RecordShare.normaliseCode(' abcd-2345 '), 'ABCD2345');
    });

    test('the QR holds only the code, and reads back', () {
      final qr = RecordShare.qrData('abcd-2345');
      expect(qr, 'AFICARE-SHARE:ABCD2345');
      expect(RecordShare.codeFromQr(qr), 'ABCD2345');
      expect(RecordShare.codeFromQr('aficare-share:abcd2345'), 'ABCD2345');
    });

    test('anything else is not a share QR', () {
      for (final raw in ['ML-NBO-123456', 'AFICARE-SHARE:SHORT', 'https://x/v/ABCD2345', '']) {
        expect(RecordShare.codeFromQr(raw), isNull, reason: raw);
      }
    });

    test('the durations are the ones the database accepts', () {
      expect(RecordShare.durations.map((d) => d.$1), [1, 4, 24, 72, 168]);
      expect(RecordShare.durationLabel(72), '3 days');
    });
  });

  group('ShareSection', () {
    test('the six sections the database accepts, and never mental health', () {
      expect(ShareSection.all.map((s) => s.id).toSet(),
          {'basic_info', 'allergies', 'medications', 'medical_history', 'vital_signs', 'lab_results'});
      expect(ShareSection.all.any((s) => s.id.contains('mental')), isFalse);
    });
  });

  group('SharedRecord', () {
    final base = <String, dynamic>{
      'share_id': 's1',
      'patient_id': 'p1',
      'patient_name': 'Mary Wanjiru',
      'medilink_id': 'ML-NBO-111111',
      'is_dependant': false,
      'guardian_name': null,
      'relationship': null,
      'sections': ['allergies', 'medications'],
      'shared_at': '2026-10-28T15:00:00Z',
      'expires_at': '2026-10-28T19:00:00Z',
      'basic_info': null,
      'allergies': ['Penicillin'],
      'medications': {
        'prescribed': [
          {'medication_name': 'Salbutamol', 'dosage': '2 puffs', 'provider_name': 'Dr Kamau'}
        ],
        'self_reported': <String>[],
      },
      'medical_history': null,
      'vital_signs': null,
      'lab_results': null,
    };

    test('a section that was not shared is null, a shared empty one is empty', () {
      final r = SharedRecord.fromJson({...base, 'allergies': <String>[]});
      expect(r.allergies, isEmpty);
      expect(r.conditions, isNull);
      expect(r.vitals, isNull);
      expect(r.labs, isNull);
      expect(r.dateOfBirth, isNull);
      expect(r.has('allergies'), isTrue);
      expect(r.has('lab_results'), isFalse);
    });

    test('reads the shared sections', () {
      final r = SharedRecord.fromJson(base);
      expect(r.allergies, ['Penicillin']);
      expect(r.prescribed!.single['medication_name'], 'Salbutamol');
      expect(r.selfReportedMedicines, isEmpty);
      expect(r.whoseRecord, 'Mary Wanjiru');
    });

    test("a dependant's record says whose child it is", () {
      final r = SharedRecord.fromJson({
        ...base,
        'patient_name': 'Brian',
        'is_dependant': true,
        'guardian_name': 'Mary Wanjiru',
        'relationship': 'child',
        'sections': ['basic_info'],
        'basic_info': {'date_of_birth': '2019-05-01', 'gender': 'male', 'blood_type': 'A+'},
      });
      expect(r.whoseRecord, "Brian · Mary Wanjiru's child");
      expect(r.ageOn(DateTime(2026, 4, 30)), 6);
      expect(r.ageOn(DateTime(2026, 5, 1)), 7);
      expect(r.bloodType, 'A+');
    });

    test('vital signs on one line, leaving out what was not measured', () {
      expect(
        SharedRecord.vitalsLine({'temperature': 37.9, 'systolic_bp': 120, 'diastolic_bp': 80, 'pulse_rate': 88}),
        'Temp 37.9 °C · BP 120/80 · Pulse 88',
      );
      expect(SharedRecord.vitalsLine({'oxygen_saturation': 97.0}), 'SpO₂ 97%');
      expect(SharedRecord.vitalsLine({}), '');
    });
  });
}
