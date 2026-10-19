import 'package:flutter_test/flutter_test.dart';
import 'package:aficare_flutter/models/caregiver_model.dart';

void main() {
  final now = DateTime(2026, 10, 16, 12);

  CaregiverAccess grant({
    bool isActive = true,
    DateTime? codeExpiresAt,
    DateTime? redeemedAt,
  }) =>
      CaregiverAccess(
        id: 'ca-1',
        accessCode: 'ABCD2345',
        accessLevel: 'full',
        isActive: isActive,
        grantedAt: DateTime(2026, 10, 15),
        codeExpiresAt: codeExpiresAt,
        redeemedAt: redeemedAt,
      );

  group('CaregiverAccess status', () {
    test('an unused code inside its 48 hours is waiting', () {
      final g = grant(codeExpiresAt: now.add(const Duration(hours: 5)));
      expect(g.statusAt(now), CaregiverGrantStatus.waiting);
      expect(g.isLiveAt(now), isTrue);
    });

    test('an unused code past its time has expired', () {
      final g = grant(codeExpiresAt: now.subtract(const Duration(minutes: 1)));
      expect(g.statusAt(now), CaregiverGrantStatus.expired);
      expect(g.isLiveAt(now), isFalse);
    });

    test('an entered code stays active after the code time passes', () {
      final g = grant(
        codeExpiresAt: now.subtract(const Duration(days: 30)),
        redeemedAt: now.subtract(const Duration(days: 31)),
      );
      expect(g.statusAt(now), CaregiverGrantStatus.active);
      expect(g.isLiveAt(now), isTrue);
    });

    test('stopped wins over everything', () {
      final g = grant(isActive: false, redeemedAt: now, codeExpiresAt: now.add(const Duration(days: 1)));
      expect(g.statusAt(now), CaregiverGrantStatus.stopped);
      expect(g.isLiveAt(now), isFalse);
    });

    test('a code with no expiry recorded is treated as expired, not open forever', () {
      expect(grant().statusAt(now), CaregiverGrantStatus.expired);
    });
  });

  group('CaregiverAccess codes', () {
    test('formatCode splits eight characters into two groups', () {
      expect(CaregiverAccess.formatCode('ABCD2345'), 'ABCD-2345');
    });

    test('normaliseCode accepts what people actually type', () {
      expect(CaregiverAccess.normaliseCode(' abcd-2345 '), 'ABCD2345');
      expect(CaregiverAccess.normaliseCode('ab cd 23 45'), 'ABCD2345');
    });

    test('formatCode leaves anything that is not eight characters alone', () {
      expect(CaregiverAccess.formatCode('123456'), '123456');
    });
  });

  group('CaregiverAccess access levels', () {
    test('every level has a label and a plain-words scope', () {
      for (final level in ['full', 'medical_only', 'appointments_only', 'emergency_only']) {
        expect(CaregiverAccess.accessLevelLabel(level), isNot(level));
        expect(CaregiverAccess.accessLevelScope(level), isNotEmpty);
      }
    });

    test('no level claims to share mental health', () {
      for (final level in ['full', 'medical_only', 'appointments_only', 'emergency_only']) {
        expect(CaregiverAccess.accessLevelScope(level).toLowerCase(), isNot(contains('mental')));
      }
    });

    test('unknown level returns raw string', () {
      expect(CaregiverAccess.accessLevelLabel('custom'), 'custom');
    });
  });

  group('fromJson', () {
    test('CaregiverAccess reads what my_caregiver_grants() returns', () {
      final g = CaregiverAccess.fromJson({
        'id': 'ca-1',
        'access_code': 'ABCD2345',
        'access_level': 'medical_only',
        'is_active': true,
        'granted_at': '2026-10-15T09:00:00Z',
        'code_expires_at': '2026-10-17T09:00:00Z',
        'redeemed_at': '2026-10-15T10:00:00Z',
        'caregiver_name': 'Amina Otieno',
        'last_viewed_at': null,
      });
      expect(g.accessLevel, 'medical_only');
      expect(g.caregiverName, 'Amina Otieno');
      expect(g.redeemedAt, isNotNull);
      expect(g.lastViewedAt, isNull);
    });

    test('CaregiverAccess survives an empty row', () {
      final g = CaregiverAccess.fromJson({});
      expect(g.codeExpiresAt, isNull);
      expect(g.isActive, isTrue);
    });

    test('CaregiverLink falls back to a neutral name', () {
      final l = CaregiverLink.fromJson({'access_id': 'ca-1', 'patient_name': '  ', 'access_level': 'full'});
      expect(l.patientName, 'AfiCare patient');
      expect(l.accessId, 'ca-1');
    });
  });
}
