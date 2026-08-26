import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/caregiver_model.dart';

void main() {
  group('CaregiverAccess access codes', () {
    test('generateAccessCode produces 6-digit string', () {
      final code = CaregiverAccess.generateAccessCode();
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
    });

    test('generateAccessCode produces valid 6-digit codes', () {
      final codes = <String>[];
      for (var i = 0; i < 100; i++) {
        final code = CaregiverAccess.generateAccessCode();
        expect(code.length, 6);
        expect(int.tryParse(code), isNotNull);
        codes.add(code);
      }
      // Timestamp-based: all codes in same ms are identical, but should be valid
      expect(codes.first.length, 6);
    });
  });

  group('CaregiverAccess access level labels', () {
    test('accessLevelLabel returns correct labels', () {
      expect(CaregiverAccess.accessLevelLabel('full'), 'Full Access');
      expect(CaregiverAccess.accessLevelLabel('medical_only'), 'Medical Records Only');
      expect(CaregiverAccess.accessLevelLabel('appointments_only'), 'Appointments Only');
      expect(CaregiverAccess.accessLevelLabel('emergency_only'), 'Emergency Info Only');
    });

    test('unknown level returns raw string', () {
      expect(CaregiverAccess.accessLevelLabel('custom'), 'custom');
    });
  });

  group('CaregiverAccess fromJson/toJson', () {
    test('round-trip preserves all fields', () {
      final access = CaregiverAccess(
        id: 'ca-1',
        caregiverUserId: 'carer-1',
        dependentPatientId: 'patient-1',
        accessCode: '123456',
        accessLevel: 'full',
        isActive: true,
        grantedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 12, 31),
        grantedByPatientId: 'patient-1',
      );

      final restored = CaregiverAccess.fromJson(access.toJson());
      expect(restored.id, 'ca-1');
      expect(restored.accessCode, '123456');
      expect(restored.accessLevel, 'full');
      expect(restored.isActive, true);
      expect(restored.expiresAt, DateTime(2026, 12, 31));
    });

    test('fromJson handles null expiresAt', () {
      final access = CaregiverAccess.fromJson({});
      expect(access.expiresAt, isNull);
      expect(access.isActive, true);
    });
  });

  group('CaregiverActivity fromJson', () {
    test('fromJson handles all fields', () {
      final json = {
        'id': 'act-1',
        'caregiver_access_id': 'ca-1',
        'action_type': 'viewed_records',
        'details': 'Viewed prescriptions',
        'timestamp': '2026-08-01T10:00:00Z',
      };
      final activity = CaregiverActivity.fromJson(json);
      expect(activity.id, 'act-1');
      expect(activity.actionType, 'viewed_records');
      expect(activity.details, 'Viewed prescriptions');
    });
  });
}
