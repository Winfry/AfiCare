import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/prescription_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../utils/theme.dart';
import 'prescription_detail_screen.dart';

/// B10 — Prescriptions Full List
class PrescriptionsListScreen extends StatefulWidget {
  const PrescriptionsListScreen({super.key});

  @override
  State<PrescriptionsListScreen> createState() =>
      _PrescriptionsListScreenState();
}

class _PrescriptionsListScreenState extends State<PrescriptionsListScreen> {
  bool _isLoading = true;
  int _filter = 0; // 0 = All, 1 = Active, 2 = Past
  final Map<String, String> _prescriberNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final rx = Provider.of<PrescriptionProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id != null) {
      await rx.loadPrescriptions(id);
      await _loadPrescriberNames(rx.prescriptions);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPrescriberNames(List<PrescriptionModel> list) async {
    final ids = list.map((p) => p.providerId).toSet().toList();
    if (ids.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id, full_name')
          .inFilter('id', ids);
      for (final j in (res as List)) {
        _prescriberNames[j['id'] as String] = j['full_name'] as String;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prescriptions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<PrescriptionProvider>(
              builder: (context, rx, _) {
                final all = rx.prescriptions;
                final filtered = _filter == 0
                    ? all
                    : _filter == 1
                        ? all
                            .where((p) =>
                                p.status == PrescriptionStatus.active)
                            .toList()
                        : all
                            .where((p) =>
                                p.status != PrescriptionStatus.active)
                            .toList();
                return Column(
                  children: [
                    _filterTabs(),
                    Expanded(
                      child: filtered.isEmpty
                          ? _emptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _card(filtered[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _filterTabs() {
    final labels = ['All', 'Active', 'Past'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(labels.length, (i) {
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
        }),
      ),
    );
  }

  Widget _card(PrescriptionModel p) {
    final active = p.status == PrescriptionStatus.active;
    final prescriber = _prescriberNames[p.providerId] ?? 'Provider';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrescriptionDetailScreen(
                prescription: p, prescriberName: prescriber),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.medicationName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  _statusBadge(p.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${p.dosage} • ${p.frequency}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15)),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _labelValue('PRESCRIBER', prescriber),
                  ),
                  Expanded(
                    child: _labelValue(
                        active ? 'PRESCRIBED ON' : 'COMPLETED ON',
                        _formatDate(p.issuedAt)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statusBadge(PrescriptionStatus status) {
    Color color;
    String label;
    switch (status) {
      case PrescriptionStatus.active:
        color = AfiCareTheme.primaryGreen;
        label = 'Active';
        break;
      case PrescriptionStatus.completed:
        color = Colors.grey;
        label = 'Past';
        break;
      case PrescriptionStatus.cancelled:
        color = Colors.red;
        label = 'Discontinued';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No prescriptions yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
