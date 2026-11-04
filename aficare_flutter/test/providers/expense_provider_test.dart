import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/medical_expense_model.dart';
import 'package:aficare_flutter/providers/expense_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> expenseRow({
    String id = 'e1',
    double amount = 500.0,
    String category = 'medication',
    String date = '2026-08-01',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'category': category,
      'amount': amount,
      'currency': 'KES',
      'description': 'Payment',
      'date': date,
      'facility_name': null,
      'notes': null,
      'created_at': '2026-08-01T09:00:00.000Z',
    };
  }

  group('ExpenseProvider.loadExpenses', () {
    test('maps expenses and aggregates totals', () async {
      fake.routeJson('/rest/v1/medical_expenses', [
        expenseRow(id: 'e1', amount: 1000.0, category: 'medication'),
        expenseRow(id: 'e2', amount: 500.0, category: 'labTest'),
        expenseRow(id: 'e3', amount: 250.0, category: 'medication'),
      ]);

      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.expenses, hasLength(3));
      expect(provider.totalSpent, 1750.0);
      expect(provider.spendingByCategory[ExpenseCategory.medication], 1250.0);
      expect(
          provider.spendingByCategory[ExpenseCategory.labTest], 500.0);
    });

    test('handles empty expense list', () async {
      fake.routeJson('/rest/v1/medical_expenses', <Object?>[]);

      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');

      expect(provider.expenses, isEmpty);
      expect(provider.totalSpent, 0);
    });

    test('a failed load is marked as such, and is not shown as "no expenses"', () async {
      fake.routeRaw(
        '/rest/v1/medical_expenses',
        http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}),
      );

      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');

      expect(provider.loadError, 'Could not load your expenses.');
      expect(provider.error, isNull, reason: 'save errors are kept apart');
      expect(provider.expenses, isEmpty);
    });

    test('totals are exact to the cent', () async {
      fake.routeJson('/rest/v1/medical_expenses', [
        for (var i = 0; i < 10; i++) expenseRow(id: 'e$i', amount: 0.1),
        expenseRow(id: 'big', amount: 150.55, category: 'labTest'),
      ]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');
      expect(provider.totalSpent, 151.55, reason: 'ten times 0.10 is exactly 1.00');
      expect(provider.spendingByCategory[ExpenseCategory.medication], 1.0);
    });
  });

  group('ExpenseProvider.addExpense', () {
    MedicalExpenseModel newExpense() => MedicalExpenseModel(
          id: 'e-new',
          patientId: 'p1',
          category: ExpenseCategory.consultation,
          amount: 300.5,
          description: 'Clinic visit',
          date: DateTime(2026, 8, 2),
        );

    test('inserts without id, confirmed by the database, and reloads', () async {
      // The database's reply to "insert one and return it".
      fake.routeJson('/rest/v1/medical_expenses', expenseRow(id: 'e-new', amount: 300.5));

      final provider = ExpenseProvider();
      final ok = await provider.addExpense(newExpense());
      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'medical_expenses').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body, containsPair('amount', 300.5));
      expect(body, containsPair('category', 'consultation'));
      expect(body, containsPair('date', '2026-08-02'));
    });

    test('a failure says so in plain words', () async {
      fake.routeRaw('/rest/v1/medical_expenses',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      final provider = ExpenseProvider();
      expect(await provider.addExpense(newExpense()), isFalse);
      expect(provider.error, contains("couldn't save this expense"));
      expect(provider.error, isNot(contains('boom')));
    });
  });

  group('ExpenseProvider.updateExpense', () {
    test('never changes who it belongs to, and is confirmed by the database', () async {
      fake.routeJson('/rest/v1/medical_expenses', [expenseRow()]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');
      final edited = provider.expenses.single.copyWith(amount: 150.5);

      expect(await provider.updateExpense(edited), isTrue);
      final patch = fake.requestsTo('PATCH', 'medical_expenses').single;
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body.containsKey('patient_id'), isFalse);
      expect(body['amount'], 150.5);
      expect(patch.url.queryParameters['id'], 'eq.e1');
      expect(provider.expenses.single.amount, 150.5);
    });

    test('a change the database quietly refused is a failure, and nothing changes', () async {
      fake.routeJson('/rest/v1/medical_expenses', [expenseRow()]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');
      fake.routeJson('/rest/v1/medical_expenses', <Object?>[]);

      expect(await provider.updateExpense(provider.expenses.single.copyWith(amount: 1)), isFalse);
      expect(provider.expenses.single.amount, 500.0);
      expect(provider.error, contains("couldn't save your changes"));
    });
  });

  group('ExpenseProvider.deleteExpense', () {
    test('deletes once the database confirms, and removes it from the list', () async {
      fake.routeJson('/rest/v1/medical_expenses', [expenseRow()]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');

      final ok = await provider.deleteExpense('e1');

      expect(ok, isTrue);
      final del = fake.requestsTo('DELETE', 'medical_expenses').single;
      expect(del.url.queryParameters['id'], 'eq.e1');
      expect(provider.expenses, isEmpty);
    });

    test('if nothing was deleted, it stays in the list and she is told', () async {
      fake.routeJson('/rest/v1/medical_expenses', [expenseRow()]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');
      fake.routeJson('/rest/v1/medical_expenses', <Object?>[]);

      expect(await provider.deleteExpense('e1'), isFalse);
      expect(provider.expenses, hasLength(1));
      expect(provider.error, contains('nothing was removed'));
    });

    test('a failed delete keeps it in the list', () async {
      fake.routeJson('/rest/v1/medical_expenses', [expenseRow()]);
      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');
      fake.routeRaw('/rest/v1/medical_expenses',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));

      expect(await provider.deleteExpense('e1'), isFalse);
      expect(provider.expenses, hasLength(1));
    });
  });
}
