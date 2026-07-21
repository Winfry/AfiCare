import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/prescription_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/theme.dart';
import 'adherence_log_screen.dart';

/// B11 — Prescription Detail (with today's adherence check-in)
class PrescriptionDetailScreen extends StatefulWidget {
  final PrescriptionModel prescription;
  final String prescriberName;
  const PrescriptionDetailScreen({
    super.key,
    required this.prescription,
    this.prescriberName = 'Provider',
  });

  @override
  State<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends State<PrescriptionDetailScreen> {
  String? _todayStatus; // 'taken' | 'skipped' | null
  int _takenThisWeek = 0;
  int _totalThisWeek = 7;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  Future<void> _loadWeek() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final res = await Supabase.instance.client
          .from('adherence_log')
          .select()
          .eq('prescription_id', widget.prescription.id)
          .gte('scheduled_time', since.toIso8601String());
      final list = res as List;
      final taken =
          list.where((j) => j['status'] == 'taken').length;
      // Today's entry
      final now = DateTime.now();
      String? todayStatus;
      for (final j in list) {
        final t = DateTime.tryParse(j['scheduled_time'] as String? ?? '');
        if (t != null &&
            t.year == now.year &&
            t.month == now.month &&
            t.day == now.day) {
          todayStatus = j['status'] as String?;
        }
      }
      if (mounted) {
        setState(() {
          _takenThisWeek = taken;
          _totalThisWeek = list.isEmpty ? 7 : list.length;
          _todayStatus = todayStatus;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkIn(String status) async {
    setState(() => _saving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final patientId = dep.activePatientId ?? auth.currentUser?.id;
    try {
      await Supabase.instance.client.from('adherence_log').insert({
        'prescription_id': widget.prescription.id,
        'patient_id': patientId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'taken_time':
            status == 'taken' ? DateTime.now().toIso8601String() : null,
        'status': status,
      });
      if (mounted) {
        setState(() {
          _todayStatus = status;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'taken'
              ? 'Marked as taken'
              : 'Marked as skipped'),
          backgroundColor:
              status == 'taken' ? Colors.green : Colors.orange,
        ));
        _loadWeek();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save check-in')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prescription;
    final active = p.status == PrescriptionStatus.active;
    final pct = _totalThisWeek == 0
        ? 0
        : ((_takenThisWeek / _totalThisWeek) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Details'),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.medicationName,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AfiCareTheme.primaryGreen)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AfiCareTheme.primaryGreen
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(active ? 'Active' : 'Past',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text('${p.dosage} • ${p.frequency}',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 20),

            // Weekly adherence
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AfiCareTheme.primaryGreen.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weekly Adherence',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('$pct%',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AfiCareTheme.primaryGreen)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      color: AfiCareTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$_takenThisWeek of $_totalThisWeek doses taken this week',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Today's Check-in",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _checkInCard(
                    label: 'Mark as Taken',
                    icon: Icons.check,
                    color: Colors.green,
                    selected: _todayStatus == 'taken',
                    onTap: _saving ? null : () => _checkIn('taken'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _checkInCard(
                    label: 'Mark as Skipped',
                    icon: Icons.close,
                    color: Colors.orange,
                    selected: _todayStatus == 'skipped',
                    onTap: _saving ? null : () => _checkIn('skipped'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _sectionCard(
              icon: Icons.access_time,
              title: 'Dosage',
              child: Text(
                p.instructions?.isNotEmpty == true
                    ? p.instructions!
                    : 'Take ${p.dosage}, ${p.frequency.toLowerCase()} for ${p.duration}.',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.medical_services_outlined,
              title: 'Prescriber',
              child: Text(widget.prescriberName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.refresh,
              title: 'Refills',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Duration: ', style: TextStyle(fontSize: 15)),
                  Text(p.duration,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (p.expiresAt != null)
                    Text('Expires: ${_formatDate(p.expiresAt!)}',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdherenceLogScreen()),
                ),
                icon: const Text('View Adherence Log'),
                label: const Icon(Icons.arrow_forward, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1),
          color: selected ? color.withOpacity(0.08) : Colors.transparent,
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AfiCareTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AfiCareTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}
