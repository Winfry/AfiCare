import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/prescription_model.dart';
import '../../providers/prescription_provider.dart';
import '../../utils/theme.dart';

class PrescriptionsTab extends StatefulWidget {
  final String patientId;

  const PrescriptionsTab({super.key, required this.patientId});

  @override
  State<PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<PrescriptionsTab> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrescriptions());
  }

  Future<void> _loadPrescriptions() async {
    if (!mounted) return;
    final provider = Provider.of<PrescriptionProvider>(context, listen: false);
    await provider.loadPrescriptions(widget.patientId);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<PrescriptionProvider>(
      builder: (context, provider, _) {
        final active = provider.getActivePrescriptions();
        final past = provider.prescriptions
            .where((p) => p.status != PrescriptionStatus.active)
            .toList();

        if (provider.prescriptions.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active.isNotEmpty) ...[
                const Text(
                  'Active Prescriptions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...active.map((p) => _buildPrescriptionCard(p)),
                const SizedBox(height: 20),
              ],
              if (past.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    'Past Prescriptions (${past.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(Icons.history),
                  children: past
                      .map((p) => _buildPrescriptionCard(p, greyed: true))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No prescriptions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'They will appear here after a provider issues them during a consultation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(PrescriptionModel p, {bool greyed = false}) {
    final textColor = greyed ? Colors.grey[600]! : Colors.black87;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medication,
                  color: greyed ? Colors.grey : AfiCareTheme.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.medicationName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                _buildStatusBadge(p.status),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.scale, 'Dosage', p.dosage, textColor),
            _infoRow(Icons.repeat, 'Frequency', p.frequency, textColor),
            _infoRow(Icons.schedule, 'Duration', p.duration, textColor),
            if (p.instructions != null && p.instructions!.isNotEmpty)
              _infoRow(Icons.info_outline, 'Instructions', p.instructions!, textColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Issued: ${_formatDate(p.issuedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                if (p.expiresAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.event_busy, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Expires: ${_formatDate(p.expiresAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PrescriptionStatus status) {
    Color color;
    String label;
    switch (status) {
      case PrescriptionStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case PrescriptionStatus.completed:
        color = Colors.grey;
        label = 'Completed';
        break;
      case PrescriptionStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
