import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lab_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/lab_provider.dart';
import '../../utils/theme.dart';

/// B17 — Lab Results (Patient View)
class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({super.key});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  bool _isLoading = true;
  int _filter = 0; // All, Pending, Completed, Critical

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final lab = Provider.of<LabProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id != null) await lab.loadOrders(id);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lab Results')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<LabProvider>(
              builder: (context, lab, _) {
                final list = _apply(lab);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Review your clinical reports and diagnostic history.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    _filterTabs(),
                    Expanded(
                      child: list.isEmpty
                          ? _empty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: list.length,
                                itemBuilder: (_, i) => _card(list[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<LabOrderModel> _apply(LabProvider lab) {
    switch (_filter) {
      case 1:
        return lab.pending;
      case 2:
        return lab.completed;
      case 3:
        return lab.critical;
      default:
        return lab.orders;
    }
  }

  Widget _filterTabs() {
    final labels = ['All', 'Pending', 'Completed', 'Critical'];
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final selected = _filter == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => setState(() => _filter = i),
              selectedColor: AfiCareTheme.primaryGreen,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.grey.shade200,
            ),
          );
        },
      ),
    );
  }

  Widget _card(LabOrderModel o) {
    final critical = o.isCritical;
    final completed = o.isCompleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: critical ? Colors.red : Colors.grey.shade200,
            width: critical ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (critical) ...[
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  const Text('CRITICAL RESULT',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ] else
                  _statusChip(o),
                const Spacer(),
                if (o.result != null) _flagBadge(o.result!.flag),
              ],
            ),
            const SizedBox(height: 8),
            Text(o.testName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_dateTime(o.orderedAt),
                style: TextStyle(color: Colors.grey[600])),
            if (o.isPending && !completed) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: o.status == LabOrderStatus.processing ? 0.6 : 0.25,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: AfiCareTheme.primaryGreen,
                ),
              ),
            ],
            const Divider(height: 24),
            InkWell(
              onTap: () => _showDetail(o),
              child: Row(
                children: [
                  if (critical) ...[
                    const Icon(Icons.notifications_active,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Requires Immediate Action',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600)),
                    ),
                  ] else
                    const Expanded(child: Text('View details')),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(LabOrderModel o) {
    final completed = o.isCompleted;
    return Row(
      children: [
        Icon(completed ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: completed ? Colors.green : AfiCareTheme.primaryGreen),
        const SizedBox(width: 4),
        Text(
          completed
              ? 'Completed'
              : o.status == LabOrderStatus.processing
                  ? 'Processing'
                  : 'Pending',
          style: TextStyle(
              color:
                  completed ? Colors.green : AfiCareTheme.primaryGreen,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _flagBadge(LabResultFlag flag) {
    Color color;
    String label;
    switch (flag) {
      case LabResultFlag.critical:
        color = Colors.red;
        label = 'CRITICAL';
        break;
      case LabResultFlag.abnormal:
        color = Colors.orange;
        label = 'ABNORMAL';
        break;
      case LabResultFlag.normal:
        color = Colors.grey;
        label = 'NORMAL';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showDetail(LabOrderModel o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(o.testName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${o.testCategory} • ${_dateTime(o.orderedAt)}',
                style: TextStyle(color: Colors.grey[600])),
            const Divider(height: 28),
            if (o.result != null) ...[
              _detailRow('Result',
                  '${o.result!.resultValue ?? '—'} ${o.result!.resultUnit ?? ''}'),
              _detailRow('Reference Range', o.result!.referenceRange),
              _detailRow('Flag', o.result!.flag.name.toUpperCase()),
              if (o.result!.performedBy != null)
                _detailRow('Performed By', o.result!.performedBy!),
              if (o.result!.notes != null)
                _detailRow('Notes', o.result!.notes!),
            ] else
              Text('Results are not yet available for this test.',
                  style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No lab results',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _dateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}
