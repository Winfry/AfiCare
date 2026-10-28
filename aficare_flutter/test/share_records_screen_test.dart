import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aficare_flutter/models/dependent_profile_model.dart';
import 'package:aficare_flutter/models/record_share_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/screens/patient/share_records.dart';
import 'package:aficare_flutter/screens/provider/shared_record_view.dart';
import 'package:aficare_flutter/services/record_share_service.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'mary',
        email: 'mary@example.com',
        fullName: 'Mary Wanjiru',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
        medilinkId: 'ML-NBO-111111',
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
    medilinkId: 'ML-DEP-555555',
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
  @override
  List<DependentProfileModel> get dependents => [brian];
}

Map<String, dynamic> _share({String? openedBy, String? revokedAt}) {
  final now = DateTime.now().toUtc();
  return {
    'id': 's1',
    'code': 'ABCD2345',
    'sections': ['allergies', 'medications'],
    'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
    'expires_at': now.add(const Duration(hours: 3)).toIso8601String(),
    'revoked_at': revokedAt,
    'opened_at': openedBy == null ? null : now.subtract(const Duration(minutes: 30)).toIso8601String(),
    'opened_by_name': openedBy,
    'view_count': openedBy == null ? 0 : 1,
  };
}

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, {bool onBrian = false}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<DependentProvider>(create: (_) => _FakeDependants(onBrian: onBrian)),
        ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(body: ShareRecords(service: RecordShareService(Supabase.instance.client))),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Share Records (patient)', () {
    testWidgets('lists her shares and who opened them', (tester) async {
      fake.routeJson('/rest/v1/rpc/my_record_shares', [_share(openedBy: 'Dr Otieno')]);

      await pump(tester);

      expect(jsonDecode(fake.requestsTo('POST', 'rpc/my_record_shares').single.body), {'p_patient_id': 'mary'});
      expect(find.text('Opened by Dr Otieno'), findsOneWidget);
      expect(find.text('Allergies, Medicines'), findsOneWidget);
      expect(find.text('ML-NBO-111111'), findsOneWidget);
      // The old false promise is gone.
      expect(find.textContaining('nothing is shared until you approve'), findsNothing);
    });

    testWidgets("on Brian's profile it lists and shares Brian's records, not Mary's", (tester) async {
      fake.routeJson('/rest/v1/rpc/my_record_shares', <Object>[]);
      fake.routeJson('/rest/v1/rpc/create_record_share', _share());

      await pump(tester, onBrian: true);

      expect(jsonDecode(fake.requestsTo('POST', 'rpc/my_record_shares').single.body), {'p_patient_id': 'brian'});
      expect(find.text('ML-NBO-111111'), findsNothing, reason: "Mary's own QR must not show on Brian's profile");

      await tester.tap(find.text('+ New share').first);
      await tester.pumpAndSettle();
      expect(find.text("Share Brian's records"), findsOneWidget);
      await tester.tap(find.text('Create share'));
      await tester.pumpAndSettle();

      final body = jsonDecode(fake.requestsTo('POST', 'rpc/create_record_share').single.body) as Map;
      expect(body['p_patient_id'], 'brian');
      expect(body['p_sections'], ['basic_info', 'allergies']);
      expect(body['p_hours'], 4);
      expect(find.text('Share created'), findsOneWidget);
      expect(find.text('ABCD-2345'), findsOneWidget);
    });

    testWidgets('nothing picked: the reason shows in the sheet and nothing is sent', (tester) async {
      fake.routeJson('/rest/v1/rpc/my_record_shares', <Object>[]);

      await pump(tester);
      await tester.tap(find.text('+ New share').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic info'));
      await tester.tap(find.text('Allergies'));
      await tester.pump();
      await tester.tap(find.text('Create share'));
      await tester.pump();

      expect(find.text('Pick at least one thing to share.'), findsOneWidget);
      expect(fake.requestsTo('POST', 'rpc/create_record_share'), isEmpty);
    });

    testWidgets('stopping a share asks first, then stops it', (tester) async {
      fake.routeJson('/rest/v1/rpc/my_record_shares', [_share(openedBy: 'Dr Otieno')]);
      fake.routeJson('/rest/v1/rpc/revoke_record_share', true);

      await pump(tester);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dr Otieno can no longer open it'), findsOneWidget);
      await tester.tap(find.text('Stop sharing'));
      await tester.pumpAndSettle();

      expect(jsonDecode(fake.requestsTo('POST', 'rpc/revoke_record_share').single.body), {'p_share_id': 's1'});
    });

    testWidgets('a failed load says so, instead of "nothing is being shared"', (tester) async {
      fake.routeRaw('/rest/v1/rpc/my_record_shares',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));

      await pump(tester);

      expect(find.text('Nothing is being shared right now.'), findsNothing);
      expect(find.text('Could not load shares'), findsOneWidget);
    });
  });

  group('Shared record (doctor)', () {
    SharedRecord record(Map<String, dynamic> extra) => SharedRecord.fromJson({
          'share_id': 's1',
          'patient_id': 'mary',
          'patient_name': 'Mary Wanjiru',
          'medilink_id': 'ML-NBO-111111',
          'is_dependant': false,
          'sections': ['allergies', 'medications'],
          'expires_at': DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String(),
          'allergies': ['Penicillin'],
          'medications': {
            'prescribed': [
              {'medication_name': 'Salbutamol', 'dosage': '2 puffs', 'frequency': 'as needed'}
            ],
            'self_reported': <String>[],
          },
          ...extra,
        });

    Future<void> pumpView(WidgetTester tester, SharedRecord r, {VoidCallback? onConsult}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SharedRecordView(record: r, onBack: () {}, onStartConsultation: onConsult)),
      ));
    }

    testWidgets('shows only the shared parts, and names what was not shared', (tester) async {
      await pumpView(tester, record({}), onConsult: () {});

      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('Salbutamol 2 puffs'), findsOneWidget);
      expect(find.text('Lab results'), findsNothing);
      expect(find.text('Vital signs'), findsNothing);
      expect(find.textContaining('Not shared: Basic info, Medical history, Vital signs, Lab results'), findsOneWidget);
      expect(find.text('New Consultation'), findsOneWidget);
    });

    testWidgets('shared but empty allergies never reads as "no allergies"', (tester) async {
      await pumpView(tester, record({'allergies': <String>[]}));

      expect(find.textContaining('None recorded in AfiCare. Ask the patient.'), findsOneWidget);
      expect(find.textContaining('No known allergies'), findsNothing);
    });

    testWidgets("a dependant's record names the guardian and offers no consultation", (tester) async {
      await pumpView(
        tester,
        record({
          'patient_name': 'Brian',
          'is_dependant': true,
          'guardian_name': 'Mary Wanjiru',
          'relationship': 'child',
        }),
      );

      expect(find.text("Brian · Mary Wanjiru's child"), findsOneWidget);
      expect(find.textContaining('Shared by Mary Wanjiru'), findsOneWidget);
      expect(find.text('New Consultation'), findsNothing);
    });
  });
}
