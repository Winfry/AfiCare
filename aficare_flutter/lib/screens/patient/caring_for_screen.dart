import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/caregiver_model.dart';
import '../../services/caregiver_service.dart';
import '../../theme/patient_tokens.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// A record someone has shared with the signed-in person through a
/// caregiver code. Read-only by design: nothing here writes, and the
/// database only hands over the sections the patient chose (see
/// `caregiver_view()` in migration 036). Mental health is never included.
class CaringForScreen extends StatefulWidget {
  const CaringForScreen({super.key, required this.accessId});

  final String accessId;

  @override
  State<CaringForScreen> createState() => _CaringForScreenState();
}

class _CaringForScreenState extends State<CaringForScreen> {
  final _service = CaregiverService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.view(widget.accessId);
      if (mounted) setState(() => _data = data);
    } on CaregiverException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _back() => context.go(PatientRoutes.dependents);

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _data == null) return const PLoadingPage();

    final data = _data;
    if (data == null) {
      return PDetailScaffold(
        eyebrow: 'Caring for',
        title: 'Shared record',
        onBack: _back,
        children: [
          PCallout(
            tone: PTone.red,
            title: "Couldn't open this record",
            body: _error ?? 'Please try again.',
            trailing: PButton('Retry', kind: PButtonKind.alt, dense: true, onPressed: _load),
          ),
        ],
      );
    }

    final name = (data['patient_name'] as String?)?.trim();
    final shownName = (name == null || name.isEmpty) ? 'Shared record' : name;
    final firstName = shownName.split(' ').first;
    final level = data['access_level'] as String? ?? '';
    final since = DateTime.tryParse(data['since'] as String? ?? '')?.toLocal();
    final medilinkId = data['medilink_id'] as String?;

    final emergency = data['emergency'] is Map ? Map<String, dynamic>.from(data['emergency'] as Map) : null;
    final appointments = _maps(data['appointments']);
    final medicines = _maps(data['medicines']);
    final labs = _maps(data['lab_orders']);

    return PSliverPage(
      eyebrow: 'Caring for',
      title: shownName,
      subtitle: [
        CaregiverAccess.accessLevelScope(level),
        if (since != null) 'shared with you since ${DateFormat('d MMM yyyy').format(since)}',
      ].join(' · '),
      action: PButton(_isLoading ? 'Refreshing…' : 'Refresh',
          kind: PButtonKind.alt, icon: Icons.refresh_rounded, onPressed: _isLoading ? null : _load),
      onBack: _back,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PViewingBanner(
                message: "You're looking at what $firstName chose to share. "
                    "You can't change anything or make medical decisions for $firstName, "
                    'and $firstName can stop sharing at any time.',
              ),
              if (_error != null) ...[
                PCallout(tone: PTone.red, body: _error!),
                const SizedBox(height: 16),
              ],
              if (emergency != null) ...[
                const PHeading('Emergency details'),
                _EmergencySection(emergency: emergency, medilinkId: medilinkId),
                const SizedBox(height: 29),
              ],
              if (appointments != null) ...[
                const PHeading('Appointments'),
                _AppointmentsSection(appointments: appointments, firstName: firstName),
                const SizedBox(height: 29),
              ],
              if (medicines != null) ...[
                const PHeading('Medicines'),
                _MedicinesSection(medicines: medicines, firstName: firstName),
                const SizedBox(height: 29),
              ],
              if (labs != null) ...[
                const PHeading('Lab results'),
                _LabsSection(labs: labs, firstName: firstName),
                const SizedBox(height: 29),
              ],
              Text(
                'Only the parts $firstName chose are shown. Mental health check-ins are never shared. '
                'If something worries you, talk to $firstName or their care team.',
                style: PT.rowSub(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  /// Null when the section wasn't shared (or isn't available), so it is
  /// left out rather than shown as empty.
  static List<Map<String, dynamic>>? _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : null;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toList() : const [];

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ═══════════════════════════════════════════════════════════════════════
// Emergency details
// ═══════════════════════════════════════════════════════════════════════

class _EmergencySection extends StatelessWidget {
  const _EmergencySection({required this.emergency, required this.medilinkId});

  final Map<String, dynamic> emergency;
  final String? medilinkId;

  Future<void> _call(BuildContext context, String number) async {
    final dialable = number.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: dialable))) return;
    } catch (e) {
      debugPrint('Could not start call: $e');
    }
    if (context.mounted) pToast(context, "Couldn't start a call here. Dial $number from your phone.");
  }

  @override
  Widget build(BuildContext context) {
    final blood = (emergency['blood_type'] as String?)?.trim();
    final allergies = _strings(emergency['allergies']);
    final conditions = _strings(emergency['conditions']);
    final notes = (emergency['notes'] as String?)?.trim();
    final contacts = (emergency['contacts'] is List ? emergency['contacts'] as List : const [])
        .whereType<Map>()
        .where((c) => '${c['phone'] ?? ''}'.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PGrid(
          columns: 3,
          children: [
            _Fact(label: 'Blood type', value: (blood == null || blood.isEmpty) ? 'Not set' : blood, large: blood != null && blood.isNotEmpty),
            _Fact(label: 'Conditions', value: conditions.isEmpty ? 'None listed' : conditions.join(', ')),
            _Fact(
              label: 'Allergies',
              value: allergies.isEmpty ? 'None on file' : '${allergies.length} on file',
              below: allergies.isEmpty
                  ? null
                  : Wrap(spacing: 6, runSpacing: 6, children: [for (final a in allergies) PBadge(a, tone: PTone.red)]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              if (contacts.isEmpty)
                const PRow(
                  leading: PSoftIcon(Icons.contact_phone_outlined),
                  title: 'No emergency contacts on file',
                )
              else
                for (final c in contacts)
                  PRow(
                    leading: const PSoftIcon(Icons.contact_phone_outlined),
                    title: '${c['name'] ?? ''}'.trim().isEmpty ? 'Emergency contact' : '${c['name']}',
                    subtitle: [
                      if ('${c['relationship'] ?? ''}'.trim().isNotEmpty) '${c['relationship']}',
                      '${c['phone']}',
                    ].join(' · '),
                    trailing: [
                      PButton('Call', kind: PButtonKind.alt, dense: true, icon: Icons.call_outlined,
                          onPressed: () => _call(context, '${c['phone']}')),
                    ],
                  ),
              if (medilinkId != null && medilinkId!.isNotEmpty)
                PRow(
                  leading: const PSoftIcon(Icons.badge_outlined),
                  title: 'MediLink ID $medilinkId',
                  subtitle: 'Give this to a clinic or responder so they can find the record.',
                ),
              if (notes != null && notes.isNotEmpty)
                PRow(
                  leading: const PSoftIcon(Icons.sticky_note_2_outlined),
                  title: 'Notes for responders',
                  subtitle: notes,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.large = false, this.below});

  final String label;
  final String value;
  final bool large;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PT.label()),
          const SizedBox(height: 12),
          Text(value, style: PT.metric().copyWith(fontSize: large ? 38 : 22, height: 1.1)),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Appointments
// ═══════════════════════════════════════════════════════════════════════

class _AppointmentsSection extends StatelessWidget {
  const _AppointmentsSection({required this.appointments, required this.firstName});

  final List<Map<String, dynamic>> appointments;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    final recent = <Map<String, dynamic>>[];
    for (final a in appointments) {
      final at = _date(a['scheduled_at']);
      if (at == null) continue;
      (at.isAfter(now) && a['status'] != 'completed' ? upcoming : recent).add(a);
    }

    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isEmpty)
            PRow(
              leading: const PSoftIcon(Icons.event_available_outlined),
              title: 'Nothing booked',
              subtitle: '$firstName has no upcoming appointments.',
            )
          else
            for (final a in upcoming) _row(a),
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text('In the last week', style: PT.label()),
            ),
            for (final a in recent.reversed) _row(a),
          ],
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> a) {
    final at = _date(a['scheduled_at'])!;
    final status = a['status'] as String? ?? '';
    final (label, tone) = switch (status) {
      'confirmed' => ('Confirmed', PTone.ok),
      'pending' => ('Requested', PTone.warn),
      'completed' => ('Done', PTone.gray),
      'cancelled' => ('Cancelled', PTone.gray),
      _ => (_cap(status), PTone.gray),
    };
    final provider = (a['provider_name'] as String?)?.trim();
    final facility = (a['facility_name'] as String?)?.trim();
    final where = [
      if (provider != null && provider.isNotEmpty) provider,
      if (a['type'] == 'telehealth') 'Video call' else if (facility != null && facility.isNotEmpty) facility,
    ].join(' · ');

    return PRow(
      leading: PSoftIcon(a['type'] == 'telehealth' ? Icons.videocam_outlined : Icons.calendar_today_outlined),
      title: DateFormat('EEE d MMM · HH:mm').format(at),
      subtitle: where.isEmpty ? null : where,
      trailing: [PBadge(label, tone: tone)],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Medicines
// ═══════════════════════════════════════════════════════════════════════

class _MedicinesSection extends StatelessWidget {
  const _MedicinesSection({required this.medicines, required this.firstName});

  final List<Map<String, dynamic>> medicines;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          if (medicines.isEmpty)
            PRow(
              leading: const PSoftIcon(Icons.medication_outlined),
              title: 'No current prescriptions',
              subtitle: "Nothing $firstName's clinicians have prescribed is active right now.",
            )
          else
            for (final m in medicines)
              PRow(
                leading: const PSoftIcon(Icons.medication_outlined),
                title: [
                  '${m['medication_name'] ?? 'Medicine'}',
                  if ('${m['dosage'] ?? ''}'.trim().isNotEmpty) '${m['dosage']}',
                ].join(' '),
                subtitle: [
                  if ('${m['frequency'] ?? ''}'.trim().isNotEmpty) '${m['frequency']}',
                  if ('${m['duration'] ?? ''}'.trim().isNotEmpty) 'for ${m['duration']}',
                ].join(' · '),
                extraSubtitle: _extra(m),
              ),
        ],
      ),
    );
  }

  String? _extra(Map<String, dynamic> m) {
    final instructions = '${m['instructions'] ?? ''}'.trim();
    final provider = '${m['provider_name'] ?? ''}'.trim();
    final issued = _date(m['issued_at']);
    final by = [
      if (provider.isNotEmpty) 'From $provider',
      if (issued != null) DateFormat('d MMM yyyy').format(issued),
    ].join(', ');
    final parts = [if (instructions.isNotEmpty) instructions, if (by.isNotEmpty) by];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Lab results
// ═══════════════════════════════════════════════════════════════════════

class _LabsSection extends StatelessWidget {
  const _LabsSection({required this.labs, required this.firstName});

  final List<Map<String, dynamic>> labs;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          if (labs.isEmpty)
            PRow(
              leading: const PSoftIcon(Icons.science_outlined),
              title: 'No lab tests yet',
              subtitle: "Tests ordered for $firstName will appear here.",
            )
          else
            for (final o in labs) _row(o),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> o) {
    final result = o['result'] is Map ? Map<String, dynamic>.from(o['result'] as Map) : null;
    final ordered = _date(o['ordered_at']);
    final resulted = _date(result?['resulted_at']);

    String? value;
    if (result != null && '${result['result_value'] ?? ''}'.trim().isNotEmpty) {
      final low = '${result['reference_range_low'] ?? ''}'.trim();
      final high = '${result['reference_range_high'] ?? ''}'.trim();
      value = [
        '${result['result_value']} ${result['result_unit'] ?? ''}'.trim(),
        if (low.isNotEmpty && high.isNotEmpty) 'normal range $low–$high',
      ].join(' · ');
    }

    final (label, tone) = result == null
        ? switch (o['status']) {
            'cancelled' => ('Cancelled', PTone.gray),
            'collected' || 'processing' => ('Being tested', PTone.blue),
            _ => ('Waiting', PTone.blue),
          }
        : switch (result['result_flag']) {
            'critical' => ('Needs attention', PTone.red),
            'abnormal' => ('Outside range', PTone.warn),
            _ => ('Normal', PTone.ok),
          };

    final when = resulted ?? ordered;
    return PRow(
      leading: const PSoftIcon(Icons.science_outlined),
      title: '${o['test_name'] ?? 'Lab test'}',
      subtitle: value ?? (result == null ? 'No result yet' : 'Result recorded'),
      extraSubtitle: when == null ? null : '${resulted != null ? 'Result' : 'Ordered'} ${DateFormat('d MMM yyyy').format(when)}',
      trailing: [PBadge(label, tone: tone)],
    );
  }
}
