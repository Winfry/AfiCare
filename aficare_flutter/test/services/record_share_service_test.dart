import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aficare_flutter/services/record_share_service.dart';

import '../helpers/fake_supabase.dart';

http.Response _dbError(String code, String message) => http.Response(
      jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}),
      400,
      headers: {'content-type': 'application/json'},
    );

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  RecordShareService service() => RecordShareService(Supabase.instance.client);

  test('create sends whose record, what and how long, and returns the code', () async {
    fake.routeJson('/rest/v1/rpc/create_record_share', {
      'id': 's1',
      'code': 'ABCD2345',
      'sections': ['allergies'],
      'created_at': '2026-10-28T15:00:00Z',
      'expires_at': '2026-10-28T19:00:00Z',
    });

    final share = await service().create('brian-id', const ['allergies'], 4);

    expect(share.code, 'ABCD2345');
    final body = jsonDecode(fake.requestsTo('POST', 'rpc/create_record_share').single.body);
    expect(body, {'p_patient_id': 'brian-id', 'p_sections': ['allergies'], 'p_hours': 4});
  });

  test("the database's own message reaches the person as it is", () async {
    fake.routeRaw('/rest/v1/rpc/create_record_share',
        _dbError('P0001', 'There are already 10 active shares. Revoke one before making another.'));

    await expectLater(
      service().create('p1', const ['allergies'], 4),
      throwsA(isA<RecordShareException>()
          .having((e) => e.message, 'message', startsWith('There are already 10 active shares'))),
    );
  });

  test('before 044 is run, it says sharing is not switched on', () async {
    fake.routeRaw('/rest/v1/rpc/my_record_shares', _dbError('PGRST202', 'Could not find the function'));

    await expectLater(
      service().mine('p1'),
      throwsA(isA<RecordShareException>().having((e) => e.message, 'message', contains('not switched on'))),
    );
  });

  test('any other failure is a plain retry message, never the raw error', () async {
    fake.routeRaw('/rest/v1/rpc/my_record_shares', _dbError('42501', 'permission denied for table access_codes'));

    await expectLater(
      service().mine('p1'),
      throwsA(isA<RecordShareException>().having((e) => e.message, 'message', isNot(contains('permission')))),
    );
  });

  test('mine lists the shares of the profile asked for', () async {
    fake.routeJson('/rest/v1/rpc/my_record_shares', [
      {
        'id': 's1',
        'code': 'ABCD2345',
        'sections': ['allergies'],
        'created_at': '2026-10-28T15:00:00Z',
        'expires_at': '2026-10-28T19:00:00Z',
        'opened_by_name': 'Dr Otieno',
        'opened_at': '2026-10-28T15:30:00Z',
        'view_count': 1,
      }
    ]);

    final shares = await service().mine('brian-id');

    expect(shares.single.openedBy, 'Dr Otieno');
    expect(jsonDecode(fake.requestsTo('POST', 'rpc/my_record_shares').single.body), {'p_patient_id': 'brian-id'});
  });

  test('revoke is true only when something was stopped', () async {
    fake.routeJson('/rest/v1/rpc/revoke_record_share', true);
    expect(await service().revoke('s1'), isTrue);

    fake.routeJson('/rest/v1/rpc/revoke_record_share', false);
    expect(await service().revoke('s1'), isFalse);
  });

  test('open sends the code as the database stores it', () async {
    fake.routeJson('/rest/v1/rpc/open_record_share', {
      'share_id': 's1',
      'patient_id': 'p1',
      'patient_name': 'Mary Wanjiru',
      'sections': ['allergies'],
      'expires_at': '2026-10-28T19:00:00Z',
      'allergies': ['Penicillin'],
    });

    final record = await service().open(' abcd-2345 ');

    expect(record.allergies, ['Penicillin']);
    expect(jsonDecode(fake.requestsTo('POST', 'rpc/open_record_share').single.body), {'p_code': 'ABCD2345'});
  });
}
