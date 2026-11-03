import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/dependent_profile_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/referral_provider.dart';
import 'package:aficare_flutter/screens/patient/referral_screen.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'mary',
        email: 'mary@example.com',
        fullName: 'Mary Wanjiru',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
      );
}

/// Mary, optionally looking at her son Brian's profile.
class _FakeDependants extends DependentProvider {
  _FakeDependants({required this.onBrian});
  final bool onBrian;

  static final brian = DependentProfileModel(
    id: 'brian',
    guardianId: 'mary',
    fullName: 'Brian Otieno',
    relationship: 'child',
    createdAt: DateTime(2026, 1, 1),
  );

  @override
  String? get ownId => 'mary';
  @override
  String? get activePatientId => onBrian ? 'brian' : 'mary';
  @override
  bool get isViewingDependent => onBrian;
  @override
  DependentProfileModel? get activeDependent => onBrian ? brian : null;
}

Map<String, dynamic> _row(String id, {required String status, String? by, String? reason = 'Chest pain'}) => {
      'id': id,
      'patient_id': 'ML-DEP-555555',
      'from_provider_id': 'dr',
      'from_provider_name': by,
      'from_facility': null,
      'to_facility': 'Kenyatta National Hospital',
      'to_department': null,
      'to_specialist': null,
      'reason': reason,
      'urgency': 'urgent',
      'status': status,
      'created_at': '2026-10-30T07:00:00Z',
      'responded_at': status == 'pending' ? null : '2026-10-31T07:00:00Z',
      'response_notes': null,
    };

void main() {
  final fake = FakeSupabase();
  const rpc = '/rest/v1/rpc/my_referrals';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, {bool onBrian = false}) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<DependentProvider>(create: (_) => _FakeDependants(onBrian: onBrian)),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: PatientReferralScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets("on Brian's profile, Mary sees Brian's referral, who sent it, and where it is", (tester) async {
    fake.routeJson(rpc, [_row('r1', status: 'accepted', by: 'Dr Kamau')]);
    await pump(tester, onBrian: true);

    expect(jsonDecode(fake.requestsTo('POST', 'rpc/my_referrals').single.body), {'p_patient_id': 'brian'});
    expect(find.text('Kenyatta National Hospital'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Facility accepted'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Referred by Dr Kamau'), findsOneWidget);
    expect(find.text('No referrals yet'), findsNothing);
  });

  testWidgets('a pending referral does not promise a notification', (tester) async {
    fake.routeJson(rpc, [_row('r1', status: 'pending', by: null, reason: null)]);
    await pump(tester);

    expect(jsonDecode(fake.requestsTo('POST', 'rpc/my_referrals').single.body), {'p_patient_id': 'mary'});
    expect(find.textContaining('Their response will show here'), findsOneWidget);
    expect(find.textContaining('notified'), findsNothing);
    expect(find.text('Reason not given'), findsOneWidget);
    expect(find.text('Referred by your doctor'), findsOneWidget);
  });

  testWidgets('no referrals says so', (tester) async {
    fake.routeJson(rpc, <Object?>[]);
    await pump(tester);
    expect(find.text('No referrals yet'), findsOneWidget);
  });

  testWidgets('a failed load says so, and never "No referrals yet"', (tester) async {
    fake.routeRaw(rpc, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
    await pump(tester);
    expect(find.text('Could not load your referrals'), findsOneWidget);
    expect(find.text('No referrals yet'), findsNothing);
    expect(find.textContaining('boom'), findsNothing);

    fake.clearRoute(rpc);
    fake.routeJson(rpc, [_row('r1', status: 'completed', by: 'Dr Kamau')]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Could not load your referrals'), findsNothing);
  });
}
