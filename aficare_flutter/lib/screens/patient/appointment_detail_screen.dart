import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/default_avatars.dart';
import '../../widgets/provider_avatar.dart';
import 'widgets/patient_ui.dart';

/// What the detail page asks the appointments list to do when it closes.
enum AppointmentDetailResult { reschedule }

/// B7 — Appointment Detail. Built from the patient UI pieces (cards, rows,
/// badges, buttons) like the rest of the app; it used to have its own
/// colours and Material buttons.
class AppointmentDetailScreen extends StatefulWidget {
  final AppointmentModel appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _facility;
  bool _loading = true;

  /// The clinician / facility details didn't load: say so, rather than
  /// "Facility not specified".
  bool _loadFailed = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    try {
      final prov = await client.from('users').select().eq('id', widget.appointment.providerId).maybeSingle();
      Map<String, dynamic>? fac;
      if (widget.appointment.facilityId != null) {
        fac = await client.from('facilities').select().eq('id', widget.appointment.facilityId!).maybeSingle();
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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _addToCalendar(AppointmentModel a) async {
    final start = a.scheduledAt;
    final end = start.add(Duration(minutes: a.durationMinutes > 0 ? a.durationMinutes : 30));
    final fmtStart = DateFormat("yyyyMMdd'T'HHmmss").format(start);
    final fmtEnd = DateFormat("yyyyMMdd'T'HHmmss").format(end);
    final providerName = _provider?['full_name'] ?? 'Provider';
    final title = Uri.encodeComponent('Appointment with $providerName');
    final details = Uri.encodeComponent(a.chiefComplaint ?? 'Medical appointment');
    final place = [
      _facility?['name'] as String?,
      _facility?['address'] as String?,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final url = Uri.parse('https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=$title&dates=$fmtStart/$fmtEnd&details=$details'
        '${place.isEmpty ? '' : '&location=${Uri.encodeComponent(place)}'}&sf=true');
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Opening the calendar failed: $e');
    }
    if (!opened && mounted) {
      pToast(context, "Couldn't open a calendar on this device.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final upcoming = a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed;
    final complaint = a.chiefComplaint?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const PSubPageBar(title: 'Appointment detail'),
      body: _loading
          ? const PLoadingPage()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: _statusBadge(a)),
                      const SizedBox(height: 10),
                      Text(DateFormat('EEEE d MMMM · HH:mm').format(a.scheduledAt), style: PT.section()),
                      const SizedBox(height: 4),
                      Text(
                        '${a.type == AppointmentType.inPerson ? 'In person' : 'Telehealth'} · '
                        '${a.durationMinutes > 0 ? a.durationMinutes : 30} minutes',
                        style: PT.sub(),
                      ),
                      const SizedBox(height: 18),
                      PCard(
                        child: Column(
                          children: [
                            PRow(
                              leading: _provider == null
                                  ? null
                                  : ProviderAvatar(
                                      name: _provider!['full_name'] as String? ?? 'Provider',
                                      role: DefaultAvatar.roleFrom(_provider!['role'] as String?),
                                      gender: _provider!['gender'] as String?,
                                      photoUrl: _provider!['photo_url'] as String?,
                                      radius: 20,
                                    ),
                              leadingEmoji: _provider == null ? '🩺' : null,
                              title: _provider?['full_name'] as String? ??
                                  (_loadFailed ? "Couldn't load the clinician's details" : 'Your clinician'),
                              subtitle: (_provider?['department'] as String?) ?? (_provider?['role'] as String?),
                            ),
                            PRow(
                              leadingEmoji: '🏥',
                              title: _facility?['name'] as String? ??
                                  (_loadFailed && a.facilityId != null
                                      ? "Couldn't load the facility's details"
                                      : 'No facility given'),
                              subtitle: _facility?['address'] as String?,
                            ),
                            PRow(
                              leadingEmoji: '📝',
                              title: complaint.isEmpty ? 'General consultation' : complaint,
                              subtitle: 'Reason for the visit',
                            ),
                          ],
                        ),
                      ),
                      if (a.notes != null && a.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        PCallout(title: 'Notes from your clinician', body: a.notes!.trim()),
                      ],
                      if (upcoming) ...[
                        const SizedBox(height: 22),
                        PButton('Add to calendar',
                            icon: Icons.event_available, expand: true, onPressed: () => _addToCalendar(a)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: PButton(
                                'Reschedule',
                                kind: PButtonKind.alt,
                                expand: true,
                                // Opens the reschedule sheet on the list; it
                                // used to say "tap a card", which did nothing.
                                onPressed: _cancelling
                                    ? null
                                    : () => Navigator.pop(context, AppointmentDetailResult.reschedule),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PButton(
                                _cancelling ? 'Cancelling…' : 'Cancel visit',
                                kind: PButtonKind.red,
                                expand: true,
                                onPressed: _cancelling ? null : () => _cancel(a),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statusBadge(AppointmentModel a) => switch (a.status) {
        AppointmentStatus.confirmed => const PBadge('Confirmed', tone: PTone.ok),
        AppointmentStatus.pending when a.scheduledAt.isBefore(DateTime.now()) =>
          const PBadge('Never confirmed', tone: PTone.gray),
        AppointmentStatus.pending => const PBadge('Waiting for the clinic to confirm', tone: PTone.warn),
        AppointmentStatus.completed => const PBadge('Completed', tone: PTone.blue),
        AppointmentStatus.cancelled => const PBadge('Cancelled', tone: PTone.gray),
      };

  Future<void> _cancel(AppointmentModel a) async {
    final confirm = await showPModal<bool>(
      context: context,
      title: 'Cancel this visit?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('The clinic will be told. You can book again at any time.', style: PT.sub()),
          const SizedBox(height: 18),
          PButton('Yes, cancel it', kind: PButtonKind.red, expand: true, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 8),
          PButton('Keep it', kind: PButtonKind.alt, expand: true, onPressed: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    final ok = await Provider.of<AppointmentProvider>(context, listen: false).cancelAppointment(a.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    pToast(context, ok ? 'Appointment cancelled' : "Couldn't cancel. Check your connection and try again.");
    if (ok) Navigator.pop(context);
  }
}
