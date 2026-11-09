import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/disability_profile.dart';
import 'package:aficare_flutter/screens/patient/pwd_tab.dart';
import 'package:aficare_flutter/screens/patient/widgets/crisis_lines.dart';

import 'helpers/fake_supabase.dart';

Map<String, dynamic> _saved({
  required List<DisabilityType> types,
  DisabilitySeverity severity = DisabilitySeverity.severe,
  List<String> devices = const [],
  bool caregiverConsent = false,
  CaregiverDesignation? oldCaregiver,
}) =>
    DisabilityProfile(
      patientId: 'p1',
      disabilityTypes: types,
      severity: severity,
      assistiveDevices: devices,
      lastUpdated: DateTime(2026, 11, 1),
      updatedBy: 'patient',
      requiresCaregiverForConsent: caregiverConsent,
      caregiver: oldCaregiver,
    ).toMap();

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> saved, {bool isOwnRecord = true}) async {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake.routeJson('/rest/v1/disability_profiles', saved);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: PwdTab(patientId: 'p1', isOwnRecord: isOwnRecord)),
      ),
      GoRoute(
        path: PwdTab.caregiverRoute,
        builder: (context, __) => Scaffold(
          body: Column(children: [
            const Text('Caregiver page'),
            TextButton(onPressed: () => context.pop(), child: const Text('Back')),
          ]),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// No clinician wording or priority badge anywhere on the page.
  void expectNoClinicianWords() {
    for (final word in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'Recommended for You']) {
      expect(find.text(word), findsNothing, reason: word);
    }
    for (final phrase in ['Suicide', 'Columbia', 'Document', 'Provider has assessed', 'educate patient', 'Provider Note']) {
      expect(find.textContaining(phrase), findsNothing, reason: phrase);
    }
  }

  testWidgets('James (severe mental health) gets support first, not a red label', (tester) async {
    await pump(tester, _saved(types: [DisabilityType.mentalHealth]));

    expectNoClinicianWords();
    expect(find.text("You don't have to carry this alone"), findsOneWidget);
    expect(find.byType(CrisisLines), findsOneWidget);
    expect(find.text('1199'), findsOneWidget);

    // The support box comes before the suggestions.
    final support = tester.getTopLeft(find.text("You don't have to carry this alone")).dy;
    final heading = tester.getTopLeft(find.text('Things to ask your clinic about')).dy;
    expect(support, lessThan(heading));

    expect(find.text('Keep taking your medicines'), findsOneWidget);
    expect(find.text('Talk to your doctor before making any change to your medicines.'), findsOneWidget);
  });

  testWidgets('Daniel (needs a guardian for decisions): kind wording, and the count matches the cards',
      (tester) async {
    await pump(tester, _saved(types: [DisabilityType.cognitive], caregiverConsent: true));

    expectNoClinicianWords();
    expect(find.text('Bring your carer or guardian'), findsOneWidget);
    expect(find.text("You don't have to carry this alone"), findsNothing, reason: 'no mental health condition');

    // Six suggestions for him (the doctor-only note is not one of them),
    // and the number beside the heading says six.
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(6));
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('a wheelchair and catheter user sees the skin and infection advice first', (tester) async {
    await pump(tester, _saved(types: [DisabilityType.mobility], devices: ['Wheelchair', 'Catheter']));

    expectNoClinicianWords();
    expect(find.text('Protecting your skin from pressure sores'), findsOneWidget);
    expect(find.text('Catheter care and urine infections'), findsOneWidget);
    final skin = tester.getTopLeft(find.text('Protecting your skin from pressure sores')).dy;
    final physio = tester.getTopLeft(find.text('Physiotherapy')).dy;
    expect(skin, lessThan(physio), reason: 'the most important comes first');
  });

  testWidgets('no profile: no suggestions and no support box', (tester) async {
    await pump(tester, _saved(types: const []));
    expect(find.text('Things to ask your clinic about'), findsNothing);
    expect(find.byType(CrisisLines), findsNothing);
  });

  group('caregiver access', () {
    const grantsPath = '/rest/v1/rpc/my_caregiver_grants';
    final now = DateTime.now().toUtc();

    Map<String, dynamic> grant({
      required String id,
      String code = 'ABCD2345',
      String level = 'medical_only',
      String? relationship,
      bool active = true,
      String? redeemedBy,
      Duration expiresIn = const Duration(hours: 40),
    }) =>
        {
          'id': id,
          'access_code': code,
          'access_level': level,
          'relationship': relationship,
          'is_active': active,
          'granted_at': now.subtract(const Duration(hours: 8)).toIso8601String(),
          'code_expires_at': now.add(expiresIn).toIso8601String(),
          'redeemed_at': redeemedBy == null ? null : now.subtract(const Duration(hours: 2)).toIso8601String(),
          'caregiver_name': redeemedBy,
        };

    final mobility = _saved(types: [DisabilityType.mobility]);

    testWidgets('no made-up code any more: it says plainly that no one has access', (tester) async {
      fake.routeJson(grantsPath, <Object?>[]);
      await pump(tester, mobility);

      expect(find.text('Caregiver access'), findsOneWidget);
      expect(find.text('No one has caregiver access right now.'), findsOneWidget);
      expect(find.text('Share with a caregiver'), findsOneWidget);
      for (final old in ['Add Caregiver', 'Change Caregiver', 'Caregiver / Guardian Access', 'Generate']) {
        expect(find.textContaining(old), findsNothing, reason: old);
      }
    });

    testWidgets('shows who really can see the record, and codes still waiting', (tester) async {
      fake.routeJson(grantsPath, [
        grant(id: 'a', relationship: 'parent', redeemedBy: 'Wanjiru Kamau'),
        grant(id: 'b', code: 'WXYZ6789', level: 'emergency_only'),
        grant(id: 'c', code: 'GONE2345', active: false, redeemedBy: 'Old Friend'),
        grant(id: 'd', code: 'LATE2345', expiresIn: const Duration(hours: -1)),
      ]);
      await pump(tester, mobility);

      expect(find.text('Wanjiru Kamau · Parent'), findsOneWidget);
      expect(find.text('Can see: Medicines, lab results and emergency details'), findsOneWidget);
      expect(find.text('Code WXYZ-6789'), findsOneWidget);
      expect(find.textContaining('Not entered yet · works until'), findsOneWidget);
      expect(find.textContaining('Old Friend'), findsNothing, reason: 'stopped');
      expect(find.textContaining('LATE'), findsNothing, reason: 'expired');
      expect(find.text('Manage caregiver access'), findsOneWidget);
    });

    testWidgets('the button opens the real caregiver page, and the list is fresh on return', (tester) async {
      fake.routeJson(grantsPath, <Object?>[]);
      await pump(tester, mobility);
      expect(fake.requestsTo('POST', 'rpc/my_caregiver_grants'), hasLength(1));

      await tester.tap(find.text('Share with a caregiver'));
      await tester.pumpAndSettle();
      expect(find.text('Caregiver page'), findsOneWidget);

      fake.routeJson(grantsPath, [grant(id: 'a', redeemedBy: 'Wanjiru Kamau')]);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(fake.requestsTo('POST', 'rpc/my_caregiver_grants'), hasLength(2));
      expect(find.text('Wanjiru Kamau'), findsOneWidget);
    });

    testWidgets('if the check fails it says so, and Try again works', (tester) async {
      fake.routeRaw(grantsPath,
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await pump(tester, mobility);

      expect(find.text("Couldn't check who you share with."), findsOneWidget);
      expect(find.text('No one has caregiver access right now.'), findsNothing, reason: 'unknown is not none');
      expect(find.textContaining('boom'), findsNothing);

      fake.clearRoute(grantsPath);
      fake.routeJson(grantsPath, <Object?>[]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No one has caregiver access right now.'), findsOneWidget);
    });

    testWidgets('someone noted here before is told it gave them no access', (tester) async {
      fake.routeJson(grantsPath, <Object?>[]);
      await pump(
        tester,
        _saved(
          types: [DisabilityType.mobility],
          oldCaregiver: CaregiverDesignation(
            name: 'Wanjiru Kamau',
            phone: '0700000000',
            relationship: 'Parent',
            permissions: const ['Known allergies'],
            designatedAt: DateTime(2026, 6, 1),
            accessCode: 'QWERTY',
            codeExpiry: DateTime(2026, 6, 2),
          ),
        ),
      );

      expect(find.textContaining('You noted Wanjiru Kamau as your caregiver on this page before'), findsOneWidget);
      expect(find.textContaining('QWERTY'), findsNothing, reason: 'the old made-up code is never shown');
    });

    testWidgets('the note goes once that person really has access', (tester) async {
      fake.routeJson(grantsPath, [grant(id: 'a', redeemedBy: 'Wanjiru Kamau')]);
      await pump(
        tester,
        _saved(
          types: [DisabilityType.mobility],
          oldCaregiver: CaregiverDesignation(
            name: 'Wanjiru Kamau',
            phone: '0700000000',
            relationship: 'Parent',
            permissions: const [],
            designatedAt: DateTime(2026, 6, 1),
          ),
        ),
      );
      expect(find.textContaining('You noted'), findsNothing);
    });

    testWidgets("on a child's profile there is no caregiver section, and nothing is asked of the server",
        (tester) async {
      await pump(tester, mobility, isOwnRecord: false);

      expect(find.text('Caregiver access'), findsNothing);
      expect(find.text('Share with a caregiver'), findsNothing);
      expect(fake.requestsTo('POST', 'rpc/my_caregiver_grants'), isEmpty);
      expect(find.text('Protecting your skin from pressure sores'), findsOneWidget, reason: 'the rest of the page is there');
    });

    testWidgets('opening the page writes nothing', (tester) async {
      fake.routeJson(grantsPath, <Object?>[]);
      await pump(tester, mobility);
      expect(fake.requestsTo('POST', 'disability_profiles'), isEmpty);
      expect(fake.requestsTo('PATCH', 'disability_profiles'), isEmpty);
    });
  });

  group('4d: her answers only, and "No" really clears them', () {
    testWidgets("saving sends only her own answers, never the doctor's notes", (tester) async {
      final saved = _saved(types: [DisabilityType.mobility])
        ..['provider_notes'] = 'Seen 3 Nov: uses a frame'
        ..['clinical_diagnosis'] = 'Cerebral palsy';
      await pump(tester, saved);
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final body = fake.requestsTo('POST', 'disability_profiles').single.body;
      expect(body, isNot(contains('provider_notes')));
      expect(body, isNot(contains('clinical_diagnosis')));
      expect(body, contains('disability_types'));
    });

    testWidgets('a profile that failed to load is not shown as an empty form to save over', (tester) async {
      tester.view.physicalSize = const Size(1000, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake.routeRaw('/rest/v1/disability_profiles',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PwdTab(patientId: 'p1', isOwnRecord: false))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Could not load your disability profile'), findsOneWidget);
      expect(find.text('Save Profile'), findsNothing);
    });

    testWidgets('"No / Prefer not to say" asks, then clears her saved answers', (tester) async {
      await pump(tester, _saved(types: [DisabilityType.mobility]));
      await tester.tap(find.text('No / Prefer not to say'));
      await tester.pumpAndSettle();
      expect(find.text('Remove what you saved?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final patch = fake.requestsTo('PATCH', 'disability_profiles').single;
      expect(patch.body, contains('"disability_types":[]'));
      expect(patch.body, isNot(contains('provider_notes')), reason: "the doctor's notes stay");
    });
  });
}

