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

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/medical_expenses',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = ExpenseProvider();
      await provider.loadExpenses('p1');

      expect(provider.error, isNotNull);
      expect(provider.expenses, isEmpty);
    });
  });

  group('ExpenseProvider.addExpense', () {
    test('inserts without id and reloads', () async {
      fake.routeJson('/rest/v1/medical_expenses', []);

      final provider = ExpenseProvider();
      final expense = MedicalExpenseModel(
        id: 'e-new',
        patientId: 'p1',
        category: ExpenseCategory.consultation,
        amount: 300.0,
        description: 'Clinic visit',
        date: DateTime(2026, 8, 2),
      );

      final ok = await provider.addExpense(expense);
      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'medical_expenses').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body, containsPair('amount', 300.0));
      expect(body, containsPair('category', 'consultation'));
    });
  });

  group('ExpenseProvider.deleteExpense', () {
    test('deletes and removes from state', () async {
      fake.routeJson('/rest/v1/medical_expenses', []);

      final provider = ExpenseProvider();
      final ok = await provider.deleteExpense('e1');

      expect(ok, isTrue);
      final del = fake.requestsTo('DELETE', 'medical_expenses').single;
      expect(del.url.queryParameters['id'], 'eq.e1');
    });
  });
}
