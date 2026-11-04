import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/expense_provider.dart';
import 'package:aficare_flutter/screens/patient/expenses_screen.dart';
import 'package:aficare_flutter/utils/money.dart';

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

Map<String, dynamic> _row(String id, double amount, {String description = 'Panadol', String date = '2026-11-02'}) => {
      'id': id,
      'patient_id': 'mary',
      'category': 'medication',
      'amount': amount,
      'currency': 'KES',
      'description': description,
      'date': date,
      'facility_name': 'Tamia Pharmacy',
      'notes': null,
      'created_at': '2026-11-02T09:00:00Z',
    };

void main() {
  group('Money', () {
    test('shows cents only when there are any', () {
      expect(Money.kes(1500), 'KES 1,500');
      expect(Money.kes(150.5), 'KES 150.50');
      expect(Money.kes(150.55), 'KES 150.55');
      expect(Money.kes(1234567.8), 'KES 1,234,567.80');
      expect(Money.kes(0), 'KES 0');
    });

    test('an amount to edit is never rounded', () {
      expect(Money.forEditing(150.5), '150.50');
      expect(Money.forEditing(150.55), '150.55');
      expect(Money.forEditing(1500), '1500');
    });

    test('reads what people type', () {
      expect(Money.parse('1500'), 1500);
      expect(Money.parse('1,500'), 1500);
      expect(Money.parse(' 1 500 '), 1500);
      expect(Money.parse('150.50'), 150.5);
      expect(Money.parse('KES 1,500'), 1500);
      expect(Money.parse('Ksh. 200'), 200);
      expect(Money.parse('ksh200'), 200);
      expect(Money.parse('150.555'), isNull, reason: 'no fractions of a cent');
      expect(Money.parse('-50'), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('1.2.3'), isNull);
      expect(Money.parse(''), isNull);
    });

    test('says what is wrong with an amount', () {
      expect(Money.problemWith(''), 'Enter the amount');
      expect(Money.problemWith('0'), 'The amount must be more than 0');
      expect(Money.problemWith('0.00'), 'The amount must be more than 0');
      expect(Money.problemWith('-5'), 'Enter an amount like 1500 or 150.50');
      expect(Money.problemWith('200000000'), contains('Please check the amount'));
      expect(Money.problemWith('1,500.25'), isNull);
    });

    test('adds up exactly', () {
      expect(Money.sum(List.filled(10, 0.1)), 1.0);
      expect(Money.sum([0.1, 0.2]), 0.3);
    });
  });

  group('Expenses page', () {
    final fake = FakeSupabase();
    const path = '/rest/v1/medical_expenses';

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await initSupabase(fake);
    });

    setUp(() => fake.reset());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: ExpensesScreen())),
      ));
      await tester.pump();
      await tester.pumpAndSettle();
    }

    Future<void> swipe(WidgetTester tester, String description) async {
      await tester.drag(find.text(description), const Offset(-700, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('amounts keep their cents, and totals add up exactly', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5), _row('e2', 1000, description: 'Clinic visit')]);
      await pump(tester);
      expect(find.text('KES 150.50'), findsOneWidget);
      expect(find.text('KES 1,000'), findsOneWidget);
      expect(find.text('KES 1,150.50'), findsWidgets, reason: 'the total');
    });

    testWidgets('swiping asks first; "Keep it" deletes nothing', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5)]);
      await pump(tester);
      await swipe(tester, 'Panadol');

      expect(find.text('Delete this expense?'), findsOneWidget);
      expect(find.textContaining('Panadol · KES 150.50 · 2 Nov 2026'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(fake.requestsTo('DELETE', path), isEmpty);
      expect(find.text('Panadol'), findsOneWidget, reason: 'it slides back');
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirming deletes it once the database says so', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5), _row('e2', 1000, description: 'Clinic visit')]);
      await pump(tester);
      await swipe(tester, 'Panadol');
      fake.routeJson(path, [_row('e1', 150.5)]); // the deleted row, returned
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fake.requestsTo('DELETE', path).single.url.queryParameters['id'], 'eq.e1');
      expect(find.text('Panadol'), findsNothing);
      expect(find.text('Clinic visit'), findsOneWidget);
      expect(find.text('Expense deleted.'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the list does not break');
    });

    testWidgets('if the delete fails, the expense stays and she is told', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5)]);
      await pump(tester);
      await swipe(tester, 'Panadol');
      fake.routeRaw(path, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Panadol'), findsOneWidget, reason: 'nothing was removed');
      expect(find.textContaining('nothing was removed'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing keeps the cents, and saves exactly what she typed', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5)]);
      await pump(tester);
      await tester.tap(find.text('Panadol'));
      await tester.pumpAndSettle();

      final amountBox = find.widgetWithText(TextFormField, 'Amount (KES)');
      expect(tester.widget<TextFormField>(amountBox).controller!.text, '150.50', reason: 'not 151');

      await tester.enterText(amountBox, '1,250.75');
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      final body = jsonDecode(fake.requestsTo('PATCH', path).single.body) as Map;
      expect(body['amount'], 1250.75);
      expect(find.text('Changes saved.'), findsOneWidget);
      expect(find.text('KES 1,250.75'), findsWidgets);
    });

    testWidgets('a wrong amount is explained, and nothing is saved', (tester) async {
      fake.routeJson(path, <Object?>[]);
      await pump(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (KES)'), '0');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Panadol');
      await tester.tap(find.text('Add Expense').last);
      await tester.pumpAndSettle();
      expect(find.text('The amount must be more than 0'), findsOneWidget);
      expect(fake.requestsTo('POST', path), isEmpty);
    });

    testWidgets('if saving fails, it says so inside the form and keeps what she typed', (tester) async {
      fake.routeJson(path, <Object?>[]);
      await pump(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (KES)'), '300');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Lab test');
      fake.routeRaw(path, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await tester.tap(find.text('Add Expense').last);
      await tester.pumpAndSettle();

      expect(find.textContaining("We couldn't save this expense"), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Lab test'), findsOneWidget, reason: 'still in the form');
    });

    testWidgets('the form has a Delete button too, which asks first', (tester) async {
      fake.routeJson(path, [_row('e1', 150.5)]);
      await pump(tester);
      await tester.tap(find.text('Panadol'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete this expense'));
      await tester.tap(find.text('Delete this expense'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this expense?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fake.requestsTo('DELETE', path), hasLength(1));
      expect(find.text('Expense deleted.'), findsOneWidget);
      expect(find.text('Panadol'), findsNothing);
    });

    testWidgets('offline, it says the expenses could not load, never "no expenses"', (tester) async {
      fake.routeRaw(path, http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      await pump(tester);
      expect(find.text('Could not load your expenses'), findsOneWidget);
      expect(find.text('No expenses recorded yet'), findsNothing);

      fake.clearRoute(path);
      fake.routeJson(path, [_row('e1', 150.5)]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Panadol'), findsOneWidget);
    });
  });
}
