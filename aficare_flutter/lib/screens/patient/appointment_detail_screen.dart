import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../utils/theme.dart';

/// B7 — Appointment Detail
class AppointmentDetailScreen extends StatefulWidget {
  final AppointmentModel appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _facility;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    try {
      final prov = await client
          .from('users')
          .select()
          .eq('id', widget.appointment.providerId)
          .maybeSingle();
      Map<String, dynamic>? fac;
      if (widget.appointment.facilityId != null) {
        fac = await client
            .from('facilities')
            .select()
            .eq('id', widget.appointment.facilityId!)
            .maybeSingle();
      }
      if (mounted) {
        setState(() {
          _provider = prov;
          _facility = fac;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final upcoming = a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment Detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusBadge(a.status),
                  const SizedBox(height: 12),
                  Text(
                    _formatDateTime(a.scheduledAt),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _infoCard(
                    icon: Icons.person,
                    label: 'PROVIDER INFO',
                    title: _provider?['full_name'] ?? 'Provider',
                    subtitle: (_provider?['department'] as String?) ??
                        (_provider?['role'] as String? ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    icon: Icons.local_hospital,
                    label: 'FACILITY INFO',
                    title: _facility?['name'] ?? 'Facility not specified',
                    subtitle: (_facility?['address'] as String?) ?? '',
                  ),
                  const SizedBox(height: 12),
                  _reasonCard(a),
                  if (a.notes != null && a.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _notesCard(a.notes!),
                  ],
                  const SizedBox(height: 24),
                  if (upcoming) _actions(a),
                ],
              ),
            ),
    );
  }

  Widget _statusBadge(AppointmentStatus status) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case AppointmentStatus.confirmed:
        color = Colors.green;
        label = 'CONFIRMED';
        icon = Icons.check_circle;
        break;
      case AppointmentStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        icon = Icons.schedule;
        break;
      case AppointmentStatus.completed:
        color = Colors.grey;
        label = 'COMPLETED';
        icon = Icons.done_all;
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        icon = Icons.cancel;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.1),
              child: Icon(icon, color: AfiCareTheme.primaryGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonCard(AppointmentModel a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REASON FOR VISIT',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.chiefComplaint?.isNotEmpty == true
                      ? a.chiefComplaint!
                      : 'General consultation',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesCard(String notes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PROVIDER NOTES',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text(notes,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _actions(AppointmentModel a) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Added to calendar')));
            },
            icon: const Icon(Icons.event_available),
            label: const Text('Add to Calendar'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Reschedule coming soon')));
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Reschedule'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancel(a),
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text('Cancel',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _cancel(AppointmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final provider = Provider.of<AppointmentProvider>(context, listen: false);
    final ok = await provider.updateStatus(a.id, AppointmentStatus.cancelled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Appointment cancelled' : 'Could not cancel'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  String _formatDateTime(DateTime dt) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} • $hour:$min $amPm';
  }
}
