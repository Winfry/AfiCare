import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/kmpdc_verification_provider.dart';
import 'package:aficare_flutter/models/kmpdc_practitioner_model.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> practitionerRow({
    String id = 'kp1',
    String cadre = 'medical_doctor',
    String fullName = 'JANE MWANGI',
    String maskedRegistrationNo = 'E0****2',
    String status = 'ACTIVE',
  }) {
    return {
      'id': id,
      'cadre': cadre,
      'full_name': fullName,
      'masked_registration_no': maskedRegistrationNo,
      'qualifications': 'MBChB (UoN) 2010',
      'discipline': null,
      'license_type': 'General Practice',
      'status': status,
      'synced_at': '2026-01-02T09:00:00.000Z',
    };
  }

  group('KmpdcVerificationProvider.search', () {
    test('maps rows from a name search', () async {
      fake.routeJson('/rest/v1/kmpdc_practitioners', [practitionerRow()]);

      final provider = KmpdcVerificationProvider();
      await provider.search(name: 'Jane Mwangi');

      expect(provider.error, isNull);
      expect(provider.results, hasLength(1));
      expect(provider.results.first.fullName, 'JANE MWANGI');
      expect(provider.results.first.maskedRegistrationNo, 'E0****2');

      final req = fake.requestsTo('GET', 'kmpdc_practitioners').single;
      expect(req.url.queryParameters['full_name'], contains('Jane Mwangi'));
    });

    test('no match returns empty, no crash', () async {
      fake.routeJson('/rest/v1/kmpdc_practitioners', <Map<String, dynamic>>[]);

      final provider = KmpdcVerificationProvider();
      await provider.search(name: 'Nobody Here');

      expect(provider.error, isNull);
      expect(provider.results, isEmpty);
    });

    test('server error records error', () async {
      fake.routeRaw(
        '/rest/v1/kmpdc_practitioners',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = KmpdcVerificationProvider();
      await provider.search(name: 'Jane Mwangi');

      expect(provider.error, isNotNull);
    });
  });

  group('KmpdcVerificationProvider.matchesLicensePattern', () {
    test('matches when the masked form of a full ID equals the stored masked value', () {
      final provider = KmpdcVerificationProvider();
      // "E0****2" is 7 characters (E,0,*,*,*,*,2) -- a full ID must also
      // be 7 characters, starting "E0" and ending "2", to mask down to it.
      final candidate = KmpdcPractitionerModel.fromJson(practitionerRow(maskedRegistrationNo: 'E0****2'));

      expect(provider.matchesLicensePattern(candidate, 'E012342'), isTrue);
      expect(provider.matchesLicensePattern(candidate, 'E099992'), isTrue);
      expect(provider.matchesLicensePattern(candidate, 'X012342'), isFalse);
      expect(provider.matchesLicensePattern(candidate, 'E0123452'), isFalse); // wrong length
      expect(provider.matchesLicensePattern(candidate, null), isFalse);
    });
  });

  group('KmpdcVerificationProvider.triggerSync', () {
    test('calls the Edge Function and refreshes lastSyncedAt', () async {
      fake.routeJson('/functions/v1/sync-kmpdc-register', {'ok': true, 'skipped': true, 'lastSyncedAt': '2026-01-02T09:00:00.000Z'});
      fake.routeJson('/rest/v1/kmpdc_practitioners', [
        {'synced_at': '2026-01-02T09:00:00.000Z'},
      ]);

      final provider = KmpdcVerificationProvider();
      await provider.triggerSync();

      expect(provider.error, isNull);
      expect(provider.lastSyncedAt, DateTime.parse('2026-01-02T09:00:00.000Z'));
      // FunctionsClient sends a lowercase method string ("post"), unlike
      // the REST client's uppercase "GET"/"POST" elsewhere in this suite.
      expect(fake.requestsTo('post', 'functions/v1/sync-kmpdc-register'), hasLength(1));
    });
  });
}
