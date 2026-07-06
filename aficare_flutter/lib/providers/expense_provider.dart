import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medical_expense_model.dart';
import '../config/supabase_config.dart';

class ExpenseProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<MedicalExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _error;

  List<MedicalExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalSpent =>
      _expenses.fold(0.0, (sum, e) => sum + e.amount);

  double get spentThisMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<ExpenseCategory, double> get spendingByCategory {
    final map = <ExpenseCategory, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> loadExpenses(String patientId) async {
    _isLoading = true;
    _error = null;
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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense(MedicalExpenseModel expense) async {
    try {
      final data = expense.toJson();
      data.remove('id');
      data.remove('created_at');
      await _supabase
          .from(SupabaseConfig.expensesTable)
          .insert(data);
      await loadExpenses(expense.patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExpense(MedicalExpenseModel expense) async {
    try {
      await _supabase
          .from(SupabaseConfig.expensesTable)
          .update(expense.toJson())
          .eq('id', expense.id);
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        _expenses[idx] = expense;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.expensesTable)
          .delete()
          .eq('id', id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
