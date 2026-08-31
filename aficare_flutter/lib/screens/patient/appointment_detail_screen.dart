import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../utils/snackbar_utils.dart';

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
    } catch (e) {
      debugPrint('appointment_detail_screen: loading appointment detail failed: $e');
      showErrorSnackBar(context, 'Could not load appointment details');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCalendar(AppointmentModel a) async {
    final start = a.scheduledAt;
    final end = start.add(const Duration(hours: 1));
    final fmtStart = DateFormat("yyyyMMdd'T'HHmmss").format(start);
    final fmtEnd = DateFormat("yyyyMMdd'T'HHmmss").format(end);
    final providerName = _provider?['full_name'] ?? 'Provider';
    final title = Uri.encodeComponent('Appointment with $providerName');
    final details =
        Uri.encodeComponent(a.chiefComplaint ?? 'Medical appointment');
    final url = Uri.parse(
        'https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=$title&dates=$fmtStart/$fmtEnd&details=$details&sf=true');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final upcoming = a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const SizedBox(width: 4),
              Text(
                'Appointment Detail',
                style: GoogleFonts.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusBadge(a.status),
                      const SizedBox(height: 12),
                      Text(
                        _formatDateTime(a.scheduledAt),
                        style: GoogleFonts.fraunces(
                            fontSize: 26, fontWeight: FontWeight.w700),
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
                        title:
                            _facility?['name'] ?? 'Facility not specified',
                        subtitle:
                            (_facility?['address'] as String?) ?? '',
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
              ),
            ),
    );
  }

  Widget _statusBadge(AppointmentStatus status) {
    Color color;
    Color bgColor;
    String label;
    IconData icon;
    switch (status) {
      case AppointmentStatus.confirmed:
        color = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFEAF5EC);
        label = 'CONFIRMED';
        icon = Icons.check_circle;
        break;
      case AppointmentStatus.pending:
        color = const Color(0xFFF57F17);
        bgColor = const Color(0xFFFEF3E0);
        label = 'PENDING';
        icon = Icons.schedule;
        break;
      case AppointmentStatus.completed:
        color = const Color(0xFF55708A);
        bgColor = const Color(0xFFEEF2F7);
        label = 'COMPLETED';
        icon = Icons.done_all;
        break;
      case AppointmentStatus.cancelled:
        color = const Color(0xFFB71C1C);
        bgColor = const Color(0xFFFCEAEA);
        label = 'CANCELLED';
        icon = Icons.cancel;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8EDF3),
            child: Icon(icon, color: const Color(0xFF1D3557)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF55708A),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Color(0xFF55708A))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonCard(AppointmentModel a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REASON FOR VISIT',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF55708A),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROVIDER NOTES',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF55708A),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(notes,
              style: const TextStyle(
                  fontStyle: FontStyle.italic, height: 1.4)),
        ],
      ),
    );
  }

  Widget _actions(AppointmentModel a) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _addToCalendar(a),
            icon: const Icon(Icons.event_available),
            label: const Text('Add to Calendar'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D3557),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Rescheduling is done from your appointments list — tap a card to reschedule')));
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Reschedule'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D3557),
                  side: const BorderSide(color: Color(0xFF1D3557)),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancel(a),
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFB71C1C)),
                label: const Text('Cancel',
                    style: TextStyle(color: Color(0xFFB71C1C))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB71C1C),
                  side: const BorderSide(color: Color(0xFFB71C1C)),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Color(0xFFB71C1C)))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final provider = Provider.of<AppointmentProvider>(context, listen: false);
    final ok =
        await provider.updateStatus(a.id, AppointmentStatus.cancelled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Appointment cancelled' : 'Could not cancel'),
        backgroundColor: ok ? const Color(0xFF1D3557) : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} \u2022 $hour:$min $amPm';
  }
}
