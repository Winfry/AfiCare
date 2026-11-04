import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medical_expense_model.dart';
import '../config/supabase_config.dart';
import '../utils/money.dart';

class ExpenseProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<MedicalExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _error;
  String? _loadError;

  List<MedicalExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;

  /// What went wrong with the last save or delete, in plain words.
  String? get error => _error;

  /// Set when the last load failed, so a list that did not arrive is
  /// never shown as "no expenses".
  String? get loadError => _loadError;

  // Totals are added up in cents (see Money), so they are exact.
  double get totalSpent => Money.sum(_expenses.map((e) => e.amount));

  double get spentThisMonth {
    final now = DateTime.now();
    return Money.sum(_expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .map((e) => e.amount));
  }

  Map<ExpenseCategory, double> get spendingByCategory {
    final cents = <ExpenseCategory, int>{};
    for (final e in _expenses) {
      cents[e.category] = (cents[e.category] ?? 0) + Money.toCents(e.amount);
    }
    return {for (final entry in cents.entries) entry.key: entry.value / 100};
  }

  Future<void> loadExpenses(String patientId) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from(SupabaseConfig.expensesTable)
          .select()
          .eq('patient_id', patientId)
          .order('date', ascending: false);

      _expenses = (response as List)
          .map((json) => MedicalExpenseModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Loading expenses failed: $e');
      // What was loaded before stays on screen, marked as not current.
      _loadError = 'Could not load your expenses.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense(MedicalExpenseModel expense) async {
    _error = null;
    try {
      final data = expense.toJson()
        ..remove('id')
        ..remove('created_at');
      await _supabase.from(SupabaseConfig.expensesTable).insert(data).select('id').single();
      await loadExpenses(expense.patientId);
      return true;
    } catch (e) {
      debugPrint('Adding an expense failed: $e');
      _error = "We couldn't save this expense. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  /// Saves changes to [expense]. Who it belongs to is never changed.
  Future<bool> updateExpense(MedicalExpenseModel expense) async {
    _error = null;
    try {
      final data = expense.toJson()
        ..remove('id')
        ..remove('patient_id')
        ..remove('created_at');
      // .select() so a change the database quietly refused is caught.
      final rows = await _supabase
          .from(SupabaseConfig.expensesTable)
          .update(data)
          .eq('id', expense.id)
          .select('id');
      if ((rows as List).isEmpty) throw StateError('No expense was changed');
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) _expenses[idx] = expense;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Updating an expense failed: $e');
      _error = "We couldn't save your changes. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  /// Deletes the expense [id]. It leaves the list only once the database
  /// confirms it is gone.
  Future<bool> deleteExpense(String id) async {
    _error = null;
    try {
      final rows = await _supabase
          .from(SupabaseConfig.expensesTable)
          .delete()
          .eq('id', id)
          .select('id');
      if ((rows as List).isEmpty) throw StateError('No expense was deleted');
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Deleting an expense failed: $e');
      _error = "We couldn't delete this expense, so nothing was removed. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }
}
