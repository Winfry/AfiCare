import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/lab_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/lab_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// Lab Results — patient view. Shows readable status first; the detailed
/// values open on demand so the landing view doesn't read like a
/// laboratory spreadsheet.
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

  @override
  Widget build(BuildContext context) {
    return PDetailScaffold(
      eyebrow: 'Clinical',
      title: 'Lab Results',
      subtitle: 'Results shared with your AfiCare record.',
      children: [
        PTabs(
          tabs: const ['All', 'Pending', 'Completed', 'Critical'],
          selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator(color: PT.teal)),
          )
        else
          Consumer<LabProvider>(
            builder: (context, lab, _) {
              // Copy before sorting: LabProvider.orders hands back its
              // own internal list, and sorting it in place would mutate
              // provider state from inside build.
              final list = List<LabOrderModel>.from(_apply(lab))
                ..sort((a, b) => _at(b).compareTo(_at(a)));

              if (list.isEmpty) {
                return PCard(
                  child: PEmpty(
                    emoji: '🧪',
                    title: 'No lab results',
                    body: _filter == 0
                        ? 'Tests ordered for you will appear here once a facility shares them.'
                        : 'Nothing matches this filter right now.',
                  ),
                );
              }

              final latest = list.first;
              final previous = list.skip(1).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _latestCard(latest),
                  if (previous.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PCardTitle('Previous results'),
                          for (final o in previous)
                            PRow(
                              leadingEmoji: '🧪',
                              title: o.testName,
                              subtitle:
                                  '${o.testCategory} · ${DateFormat('d MMM yyyy').format(_at(o))}',
                              trailing: [_statusBadge(o)],
                              onTap: () => _showDetail(o),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _latestCard(LabOrderModel o) {
    final hasResult = o.result != null;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle('Latest result', trailing: _statusBadge(o)),
          PRow(
            leadingEmoji: o.isCritical ? '⚠️' : (hasResult ? '✓' : '⏳'),
            title: '${o.testName} · ${DateFormat('d MMM yyyy').format(_at(o))}',
            subtitle: _summaryLine(o),
            trailing: [
              PButton(
                hasResult ? 'View result' : 'Details',
                dense: true,
                onPressed: () => _showDetail(o),
              ),
            ],
          ),
          if (o.isCritical) ...[
            const SizedBox(height: 8),
            const PCallout(
              title: 'Requires immediate action',
              body: 'This result was flagged critical. Contact your care team as soon as you can.',
              tone: PTone.red,
            ),
          ],
        ],
      ),
    );
  }

  String _summaryLine(LabOrderModel o) {
    final r = o.result;
    if (r == null) {
      switch (o.status) {
        case LabOrderStatus.processing:
          return 'Sample is being processed';
        case LabOrderStatus.collected:
          return 'Sample collected, awaiting processing';
        case LabOrderStatus.cancelled:
          return 'This test was cancelled';
        default:
          return 'Ordered, awaiting sample collection';
      }
    }
    switch (r.flag) {
      case LabResultFlag.critical:
        return 'Critical value — needs urgent review';
      case LabResultFlag.abnormal:
        return 'Some values outside the normal range';
      case LabResultFlag.normal:
        return 'All values within normal range';
    }
  }

  Widget _statusBadge(LabOrderModel o) {
    final r = o.result;
    if (r != null) {
      return switch (r.flag) {
        LabResultFlag.critical => const PBadge('Critical', tone: PTone.red),
        LabResultFlag.abnormal => const PBadge('Abnormal', tone: PTone.warn),
        LabResultFlag.normal => const PBadge('Normal', tone: PTone.ok),
      };
    }
    return switch (o.status) {
      LabOrderStatus.processing => const PBadge('Processing', tone: PTone.blue),
      LabOrderStatus.collected => const PBadge('Collected', tone: PTone.blue),
      LabOrderStatus.cancelled => const PBadge('Cancelled', tone: PTone.gray),
      _ => const PBadge('Pending', tone: PTone.gray),
    };
  }

  /// Results are ordered by when the patient could actually see them.
  DateTime _at(LabOrderModel o) => o.result?.resultedAt ?? o.orderedAt;

  void _showDetail(LabOrderModel o) {
    final r = o.result;
    showPModal<void>(
      context: context,
      title: o.testName,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${o.testCategory} · ${DateFormat('d MMM yyyy · HH:mm').format(_at(o))}',
            style: PT.sub(),
          ),
          const SizedBox(height: 16),
          if (r == null)
            const PCallout(body: 'Results are not yet available for this test.')
          else ...[
            _detailRow('Result', '${r.resultValue ?? '—'} ${r.resultUnit ?? ''}'.trim()),
            _detailRow('Reference range', r.referenceRange),
            _detailRow('Flag', r.flag.name.toUpperCase()),
            if (r.performedBy != null) _detailRow('Performed by', r.performedBy!),
            if (r.notes != null) _detailRow('Notes', r.notes!),
          ],
          const SizedBox(height: 18),
          PButton('Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: PT.label())),
          Expanded(child: Text(value, style: PT.rowTitle())),
        ],
      ),
    );
  }
}
