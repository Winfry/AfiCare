import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/screens/patient/mental_health_screen.dart';

import 'helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  testWidgets('the page promises only what is true: only she can see it', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MentalHealthScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Only you can see your moods and check-ins'), findsOneWidget);
    expect(find.textContaining('not your doctors, not other staff, not caregivers'), findsOneWidget);
    expect(find.textContaining('unless you choose to share it'), findsNothing,
        reason: 'there is no way to share it, so the page must not suggest one');
  });
}
