import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/screens/provider/patient_access.dart';
import 'package:aficare_flutter/services/record_share_service.dart';

import 'helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pumpOnCodeTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: PatientAccess(shareService: RecordShareService(Supabase.instance.client))),
    ));
    await tester.tap(find.text('Access Code'));
    await tester.pumpAndSettle();
  }

  testWidgets('a doctor types the 8-character code and sees only what was shared', (tester) async {
    fake.routeJson('/rest/v1/rpc/open_record_share', {
      'share_id': 's1',
      'patient_id': 'mary',
      'patient_name': 'Mary Wanjiru',
      'sections': ['allergies'],
      'expires_at': DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String(),
      'allergies': ['Penicillin'],
    });

    await pumpOnCodeTab(tester);
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();

    expect(jsonDecode(fake.requestsTo('POST', 'rpc/open_record_share').single.body), {'p_code': 'ABCD2345'});
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.textContaining('Not shared:'), findsOneWidget);
  });

  testWidgets("the database's reason is shown when a code can't be opened", (tester) async {
    fake.routeRaw(
      '/rest/v1/rpc/open_record_share',
      http.Response(
        jsonEncode({'code': 'P0001', 'message': 'This share has expired. Ask the patient for a new code.'}),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await pumpOnCodeTab(tester);
    await tester.enterText(find.byType(TextField), 'ABCD2345');
    await tester.pumpAndSettle();

    expect(find.text('This share has expired. Ask the patient for a new code.'), findsOneWidget);
  });
}
