import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/disability_profile.dart';
import 'package:aficare_flutter/screens/patient/pwd_tab.dart';
import 'package:aficare_flutter/screens/patient/widgets/crisis_lines.dart';

import 'helpers/fake_supabase.dart';

Map<String, dynamic> _saved({
  required List<DisabilityType> types,
  DisabilitySeverity severity = DisabilitySeverity.severe,
  List<String> devices = const [],
  bool caregiverConsent = false,
}) =>
    DisabilityProfile(
      patientId: 'p1',
      disabilityTypes: types,
      severity: severity,
      assistiveDevices: devices,
      lastUpdated: DateTime(2026, 11, 1),
      updatedBy: 'patient',
      requiresCaregiverForConsent: caregiverConsent,
    ).toMap();

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> saved) async {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake.routeJson('/rest/v1/disability_profiles', saved);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PwdTab(patientId: 'p1'))));
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
}
