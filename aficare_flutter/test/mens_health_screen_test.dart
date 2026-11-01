import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/mens_health_tools.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/screens/patient/mens_health_screen.dart';
import 'package:aficare_flutter/services/mens_health_service.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'otieno',
        email: 'o@example.com',
        fullName: 'Peter Otieno',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
      );
}

/// Loads like the real service but every save fails.
class _SaveFails extends MensHealthService {
  @override
  Future<void> save({
    required String patientId,
    required MhTool tool,
    required Map<String, int> answers,
    required MhResult result,
  }) async =>
      throw Exception('offline');
}

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, {MensHealthService? service}) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _FakeAuth(),
      child: MaterialApp(home: Scaffold(body: MensHealthScreen(service: service))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// Sexual health answers giving 4+4+4+4+4 = 20: mild.
  Future<void> answerSexualHealth(WidgetTester tester) async {
    await tap(tester, 'High');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'Most times (much more than half the time)');
      if (i == 1) await tap(tester, 'Slightly difficult');
    }
  }

  testWidgets('Sexual health asks its own questions, saves under its own name, and shows the result',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Sexual health');

    expect(find.textContaining('IIEF-5'), findsWidgets);
    await tap(tester, 'Start');
    expect(find.text('Over the past 6 months:'), findsOneWidget);
    expect(find.textContaining('confidence that you could get and keep an erection'), findsOneWidget);
    expect(find.descendant(of: find.byType(MhQuestionnaire), matching: find.textContaining('cholesterol')),
        findsNothing, reason: 'not the heart questions');

    await answerSexualHealth(tester);

    final body = jsonDecode(fake.requestsTo('POST', 'mens_health_screenings').single.body) as Map;
    expect(body['patient_id'], 'otieno');
    expect(body['screening_type'], 'erectile');
    expect(body['risk_score'], 20);
    expect(body['risk_level'], 'mild');
    expect(body['responses'], {
      'answers': {'confidence': 4, 'hard_enough': 4, 'maintain': 4, 'to_completion': 4, 'satisfactory': 4},
    });

    expect(find.text('Mild'), findsOneWidget);
    expect(find.textContaining('Score 20 of 25'), findsOneWidget);
    expect(find.text('Worth a check-up'), findsOneWidget);
    expect(find.textContaining("couldn't be saved"), findsNothing);
  });

  testWidgets('Back returns to the previous question with its answer kept; Cancel saves nothing',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Sexual health');
    await tap(tester, 'Start');
    await tap(tester, 'High');
    expect(find.text('Question 2 of 5'), findsOneWidget);

    await tap(tester, 'Back');
    expect(find.text('Question 1 of 5'), findsOneWidget);
    final high = tester.widget<Text>(find.text('High'));
    expect(high.style?.fontWeight, FontWeight.w700, reason: 'the earlier answer shows as chosen');

    await tap(tester, 'Cancel');
    expect(find.text('Question 1 of 5'), findsNothing);
    expect(fake.requestsTo('POST', 'mens_health_screenings'), isEmpty);
  });

  testWidgets('Metabolic health takes "I don\'t know" and says what to find out', (tester) async {
    await pump(tester);
    await tap(tester, 'Metabolic health');
    await tap(tester, 'Start');
    await tap(tester, '94 cm or more');
    await tap(tester, 'I take medicine for high blood pressure');
    await tap(tester, "I don't know");
    await tap(tester, "I don't know");
    await tap(tester, "I don't know");

    final body = jsonDecode(fake.requestsTo('POST', 'mens_health_screenings').single.body) as Map;
    expect(body['screening_type'], 'metabolic');
    expect(body['risk_level'], 'unclear');
    expect(body['risk_score'], 2);
    expect(find.text("Can't tell yet"), findsWidgets);
    expect(find.text('Still to find out'), findsOneWidget);
  });

  testWidgets('Lifestyle skips the drinking questions for a non-drinker', (tester) async {
    await pump(tester);
    await tap(tester, 'Lifestyle');
    await tap(tester, 'Start');
    await tap(tester, 'No, never'); // tobacco
    expect(find.text('Question 2 of 10'), findsOneWidget);
    await tap(tester, 'Never'); // alcohol
    expect(find.text('Question 3 of 8'), findsOneWidget, reason: 'two drinking questions dropped');
    expect(find.textContaining('how many drinks'), findsNothing);
  });

  testWidgets('if saving fails, the result still shows and says it was not kept', (tester) async {
    await pump(tester, service: _SaveFails());
    await tap(tester, 'Sexual health');
    await tap(tester, 'Start');
    await answerSexualHealth(tester);

    expect(find.text('Worth a check-up'), findsOneWidget);
    expect(find.textContaining("couldn't be saved"), findsOneWidget);
  });

  testWidgets('a failed load says so instead of showing no results', (tester) async {
    fake.routeRaw('/rest/v1/mens_health_screenings',
        http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
    await pump(tester);

    expect(find.text('Could not load your past results'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing, reason: 'no technical text');
    expect(find.text('Sexual health'), findsOneWidget, reason: 'the check-ups still work');
  });

  testWidgets('past results: a new one reopens in full, an old list-style one just lists', (tester) async {
    fake.routeJson('/rest/v1/mens_health_screenings', [
      {
        'id': 'm1',
        'patient_id': 'otieno',
        'screening_type': 'metabolic',
        'responses': {
          'answers': {'waist': 1, 'blood_pressure': 1, 'fasting_glucose': 1, 'triglycerides': 0, 'hdl': 0},
        },
        'risk_score': 3,
        'risk_level': 'likely',
        'completed_at': '2026-10-30T07:00:00Z',
      },
      {
        'id': 'h1',
        'patient_id': 'otieno',
        'screening_type': 'cardiovascular',
        'responses': {'answers': [1, 2, 1, 0, 0, 2, 0]},
        'risk_score': 6,
        'risk_level': 'moderate',
        'completed_at': '2026-09-01T07:00:00Z',
      },
    ]);
    await pump(tester);

    expect(find.text('Likely metabolic syndrome · 3 of 5 signs'), findsOneWidget);
    expect(find.text('Moderate risk · Score 6'), findsOneWidget);
    expect(find.textContaining('Last: Likely metabolic syndrome'), findsOneWidget);

    await tester.tap(find.text('Likely metabolic syndrome · 3 of 5 signs'));
    await tester.pumpAndSettle();
    expect(find.text('Taken on 30/10/2026'), findsOneWidget);
    expect(find.text('Large waist'), findsOneWidget);
    await tap(tester, 'Close');

    await tester.tap(find.text('Moderate risk · Score 6'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Taken on'), findsNothing, reason: 'old rows cannot be reopened');
  });
}
