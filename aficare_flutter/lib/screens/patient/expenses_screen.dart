import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/medical_expense_model.dart';
import '../../utils/theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  ExpenseCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context.read<ExpenseProvider>().loadExpenses(user.id);
    }
  }

  List<MedicalExpenseModel> _filtered(List<MedicalExpenseModel> list) {
    if (_filterCategory == null) return list;
    return list.where((e) => e.category == _filterCategory).toList();
  }

  void _showExpenseForm({MedicalExpenseModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExpenseFormSheet(
        existing: existing,
        onSave: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Expenses'),
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_filterCategory != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _filterCategory = null),
            ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _filtered(provider.expenses);

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildSummary(provider)),
                SliverToBoxAdapter(child: _buildCategoryFilter()),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No expenses recorded yet',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Tap + to add your first expense',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = filtered[index];
                        return _buildExpenseTile(expense);
                      },
                      childCount: filtered.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseForm(),
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummary(ExpenseProvider provider) {
    final f = NumberFormat('#,##0');
    return Container(
      padding: const EdgeInsets.all(20),
      color: AfiCareTheme.primaryGreen.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Total Spent',
                  'KES ${f.format(provider.totalSpent)}',
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'This Month',
                  'KES ${f.format(provider.spentThisMonth)}',
                  Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.spendingByCategory.isNotEmpty)
            SizedBox(
              height: 120,
              child: _buildMiniPieChart(provider.spendingByCategory),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AfiCareTheme.primaryGreen, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMiniPieChart(Map<ExpenseCategory, double> data) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.grey,
    ];

    final sections = data.entries.map((e) {
      final idx = ExpenseCategory.values.indexOf(e.key);
      return PieChartSectionData(
        value: e.value,
        color: colors[idx % colors.length],
        radius: 30,
        title: '${(e.value / total * 100).round()}%',
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 20,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.map((e) {
            final idx = ExpenseCategory.values.indexOf(e.key);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[idx % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${e.key.label}  ${NumberFormat('#,##0').format(e.value)}',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, 'All'),
            ...ExpenseCategory.values.map((c) => _filterChip(c, c.label)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(ExpenseCategory? category, String label) {
    final selected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterCategory = category),
        selectedColor: AfiCareTheme.primaryGreen.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? AfiCareTheme.primaryGreen : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildExpenseTile(MedicalExpenseModel expense) {
    final f = NumberFormat('#,##0');
    final dateF = DateFormat('MMM d, yyyy');

    IconData categoryIcon;
    switch (expense.category) {
      case ExpenseCategory.medication:
        categoryIcon = Icons.medication;
      case ExpenseCategory.consultation:
        categoryIcon = Icons.local_hospital;
      case ExpenseCategory.labTest:
        categoryIcon = Icons.science;
      case ExpenseCategory.procedure:
        categoryIcon = Icons.biotech;
      case ExpenseCategory.hospitalStay:
        categoryIcon = Icons.bed;
      case ExpenseCategory.other:
        categoryIcon = Icons.receipt;
    }

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => context.read<ExpenseProvider>().deleteExpense(expense.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.1),
            child: Icon(categoryIcon, color: AfiCareTheme.primaryGreen),
          ),
          title: Text(expense.description,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${expense.category.label}  •  ${dateF.format(expense.date)}${expense.facilityName != null ? '  •  ${expense.facilityName}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            'KES ${f.format(expense.amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AfiCareTheme.primaryGreen,
            ),
          ),
          onTap: () => _showExpenseForm(existing: expense),
        ),
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  final MedicalExpenseModel? existing;
  final VoidCallback onSave;

  const _ExpenseFormSheet({this.existing, required this.onSave});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late ExpenseCategory _category;
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late DateTime _date;
  late TextEditingController _facilityCtrl;
  late TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? ExpenseCategory.medication;
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? DateTime.now();
    _facilityCtrl = TextEditingController(text: e?.facilityName ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _facilityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final expense = MedicalExpenseModel(
      id: widget.existing?.id ?? '',
      patientId: widget.existing?.patientId ?? user.id,
      category: _category,
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      description: _descCtrl.text.trim(),
      date: _date,
      facilityName: _facilityCtrl.text.trim().isEmpty
          ? null
          : _facilityCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    final provider = context.read<ExpenseProvider>();
    bool ok;
    if (widget.existing != null) {
      ok = await provider.updateExpense(expense);
    } else {
      ok = await provider.addExpense(expense);
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSave();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to save'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing != null ? 'Edit Expense' : 'Add Expense',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ExpenseCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ExpenseCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter amount';
                  }
                  if (double.tryParse(v.trim()) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('MMM d, yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _facilityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Facility / Provider (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_saving
                      ? 'Saving...'
                      : widget.existing != null
                          ? 'Update'
                          : 'Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
