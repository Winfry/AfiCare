import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/active_patient.dart';
import '../../models/consultation_model.dart';
import '../../models/vital_readings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/patient_tokens.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// Health Records — the patient's own summary: the readings from their
/// latest visit, that visit, a trend across visits, and the way in to lab
/// results, prescriptions and visit history.
class HealthSummary extends StatefulWidget {
  const HealthSummary({super.key});

  @override
  State<HealthSummary> createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // The shell loads this data, but the screen needs its own load so it
    // has something to retry with when that load failed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final patient = Provider.of<PatientProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id == null) return;
    await patient.loadConsultations(id);
    // Captured now: `error` is shared with access-code generation.
    if (mounted) setState(() => _loadFailed = patient.error != null);
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final profileProvider = context.watch<PatientProfileProvider>();

    // Whose record this is. Everything personal on this screen must come
    // from here: the consultations below are already scoped to the active
    // patient, so reading allergies from the account holder's profile —
    // as this screen used to — blended two people into one chart.
    final subject = ActivePatient.of(context);

    // The cached-copy notice belongs to the account holder's profile, so
    // it must not be shown while a dependant's record is on screen.
    final safetyFromCacheAt =
        subject.isDependent ? null : profileProvider.profileFromCacheAt;

    final consultations = List<ConsultationModel>.from(patient.consultations)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final latest = consultations.isEmpty ? null : consultations.first;
    final vitals = latest?.vitalSigns;

    return PDetailScaffold(
      eyebrow: 'Records',
      title: 'Health Records',
      subtitle: subject.isDependent
          ? "${subject.fullName}'s summary, visits, results and prescriptions."
          : 'Your health summary, visits, results and prescriptions.',
      action: PButton(
        'Share summary',
        kind: PButtonKind.alt,
        icon: Icons.ios_share,
        onPressed: () => _share(subject, latest),
      ),
      children: [
        if (patient.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator(color: PT.teal)),
          )
        else if (_loadFailed && consultations.isEmpty && safetyFromCacheAt == null)
          PLoadError(what: 'your health records', onRetry: _load)
        else ...[
          // Allergies and blood type below may be the saved copy; say so
          // rather than let them pass as current.
          if (safetyFromCacheAt != null) ...[
            POfflineBanner(savedAt: safetyFromCacheAt, onRetry: _load),
            const SizedBox(height: 16),
          ],
          PGrid(
            columns: 3,
            children: [
              _latestReadingsCard(latest),
              _recentVisitCard(latest),
              _allergiesCard(subject),
            ],
          ),
          const SizedBox(height: 16),
          PGrid(
            columns: 2,
            children: [
              _trendCard(consultations),
              _categoriesCard(context, consultations),
            ],
          ),
          if (vitals != null) ...[
            const SizedBox(height: 16),
            _vitalsCard(vitals),
          ],
          if (latest != null && latest.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _recommendationsCard(latest.recommendations),
          ],
          ..._followUpSection(consultations),
        ],
      ],
    );
  }

  // ── Top row ───────────────────────────────────────────────────────────

  /// What the latest visit's readings were, each on its own. Not a score:
  /// one visit's readings are not a measure of overall health, and adding
  /// them up hid a dangerous one among normal ones.
  Widget _latestReadingsCard(ConsultationModel? latest) {
    final readings = latest == null ? const <VitalReading>[] : VitalReadings.of(latest.vitalSigns);
    if (latest == null || readings.isEmpty) {
      return PCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest readings', style: PT.label()),
            const SizedBox(height: 7),
            Text('None recorded yet', style: PT.h3()),
            const SizedBox(height: 4),
            Text(
              latest == null
                  ? 'Readings like blood pressure and temperature appear here after a visit.'
                  : 'No readings were recorded at your last visit.',
              style: PT.sub(),
            ),
          ],
        ),
      );
    }

    final unusual = VitalReadings.unusual(latest.vitalSigns);
    final now = DateTime.now();
    final ago = VitalReadings.howLongAgo(latest.timestamp, now);
    final stale = now.difference(latest.timestamp).inDays > VitalReadings.staleAfterDays;
    final headline = unusual.isEmpty
        ? (readings.length == 1 ? 'In the usual range' : 'All in the usual range')
        : unusual.length == 1
            ? 'One outside the usual range'
            : '${unusual.length} outside the usual range';

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest readings', style: PT.label()),
          const SizedBox(height: 7),
          Text(headline, style: PT.h3()),
          if (unusual.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final r in unusual) PBadge('${r.name}: ${r.status}', tone: _tone(r.level))],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'From your visit on ${DateFormat('d MMM yyyy').format(latest.timestamp)}'
            '${ago == null ? '' : ' ($ago)'}.${stale ? ' These may be out of date.' : ''}',
            style: PT.sub(),
          ),
          const SizedBox(height: 4),
          Text('Readings from one visit, not a measure of your overall health.', style: PT.rowSub()),
        ],
      ),
    );
  }

  Widget _recentVisitCard(ConsultationModel? latest) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent visit', style: PT.label()),
          const SizedBox(height: 7),
          if (latest == null)
            Text('No visits recorded yet', style: PT.h3())
          else ...[
            Text(DateFormat('d MMM').format(latest.timestamp), style: PT.h3()),
            const SizedBox(height: 4),
            Text(
              latest.chiefComplaint.isEmpty ? 'General consultation' : latest.chiefComplaint,
              style: PT.sub(),
            ),
            const SizedBox(height: 6),
            Text(_vitalsSummary(latest.vitalSigns), style: PT.sub()),
          ],
        ],
      ),
    );
  }

  /// Three distinct states, and conflating any two of them is a safety
  /// problem: we know of none; we could not load them; or this profile
  /// cannot hold them at all. Only the first may read as "none".
  Widget _allergiesCard(ActivePatient subject) {
    final allergies = subject.allergies;
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allergies', style: PT.label()),
          const SizedBox(height: 7),
          if (allergies == null) ...[
            // Saying "none recorded" here would be a safety claim we
            // cannot stand behind — the record simply didn't arrive.
            Text('Not available', style: PT.h3()),
            const SizedBox(height: 4),
            Text("We couldn't load this. Don't rely on it being empty.", style: PT.sub()),
          ] else if (allergies.isEmpty) ...[
            Text('None recorded', style: PT.h3()),
            const SizedBox(height: 4),
            Text('Add these with your provider so they are on file.', style: PT.sub()),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final a in allergies) PBadge(a, tone: PTone.red)],
            ),
            const SizedBox(height: 8),
            Text('Keep this current.', style: PT.sub()),
          ],
        ],
      ),
    );
  }

  // ── Trend + categories ────────────────────────────────────────────────

  /// Systolic blood pressure across the last 7 visits, oldest to newest.
  Widget _trendCard(List<ConsultationModel> consultations) {
    final chronological = List<ConsultationModel>.from(consultations)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final recent = chronological.length > 7
        ? chronological.sublist(chronological.length - 7)
        : chronological;
    final points = recent.where((c) => c.vitalSigns.systolicBP != null).toList();

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Blood pressure trend'),
          if (points.length < 2)
            const PEmpty(
              emoji: '📈',
              title: 'Not enough visits yet',
              body: 'Once you have a couple of recorded visits, your blood-pressure trend appears here.',
            )
          else
            _BarChart(
              values: [for (final c in points) c.vitalSigns.systolicBP!.toDouble()],
              labels: [for (final c in points) DateFormat('d/M').format(c.timestamp)],
            ),
          if (points.length >= 2) ...[
            const SizedBox(height: 10),
            Text('Systolic blood pressure (mmHg) across your last visits', style: PT.rowSub()),
          ],
        ],
      ),
    );
  }

  Widget _categoriesCard(BuildContext context, List<ConsultationModel> consultations) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Record categories'),
          PRow(
            leadingEmoji: '🧪',
            title: 'Lab results',
            subtitle: 'Tests and results',
            trailing: const [Icon(Icons.chevron_right, size: 18, color: PT.muted)],
            onTap: () => context.go('/patient/labs'),
          ),
          PRow(
            leadingEmoji: '💊',
            title: 'Prescriptions',
            subtitle: 'Current and past',
            trailing: const [Icon(Icons.chevron_right, size: 18, color: PT.muted)],
            onTap: () => context.go(PatientRoutes.medications),
          ),
          PRow(
            leadingEmoji: '🩺',
            title: 'Visit summaries',
            subtitle: consultations.isEmpty
                ? 'No visits yet'
                : '${consultations.length} recorded visit${consultations.length == 1 ? '' : 's'}',
            trailing: const [Icon(Icons.chevron_right, size: 18, color: PT.muted)],
            onTap: consultations.isEmpty ? null : () => _showVisits(context, consultations),
          ),
        ],
      ),
    );
  }

  void _showVisits(BuildContext context, List<ConsultationModel> consultations) {
    showPModal<void>(
      context: context,
      title: 'Visit summaries',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in consultations)
            PRow(
              leadingEmoji: '🩺',
              title: c.chiefComplaint.isEmpty ? 'Consultation' : c.chiefComplaint,
              subtitle: DateFormat('EEEE, d MMM yyyy').format(c.timestamp),
              extraSubtitle: _vitalsSummary(c.vitalSigns),
            ),
        ],
      ),
    );
  }

  // ── Detail cards ──────────────────────────────────────────────────────

  Widget _vitalsCard(VitalSigns v) {
    final rows = [
      for (final r in VitalReadings.of(v))
        PRow(title: r.name, subtitle: r.value, trailing: [PBadge(r.status, tone: _tone(r.level))]),
    ];

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Latest vitals'),
          if (rows.isEmpty)
            const PEmpty(emoji: '🩺', title: 'No vitals recorded at your last visit')
          else
            ...rows,
        ],
      ),
    );
  }

  Widget _recommendationsCard(List<String> recommendations) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('From your last visit'),
          for (final r in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: PT.teal),
                  ),
                  Expanded(child: Text(r, style: PT.body())),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _followUpSection(List<ConsultationModel> consultations) {
    final now = DateTime.now();
    final upcoming = consultations
        .where((c) => c.followUpRequired && c.followUpDate != null && c.followUpDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    if (upcoming.isEmpty) return const [];

    return [
      const SizedBox(height: 16),
      PCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PCardTitle('Follow-ups due'),
            for (final c in upcoming)
              PRow(
                leadingEmoji: '📅',
                title: c.chiefComplaint.isEmpty ? 'Follow-up' : c.chiefComplaint,
                subtitle: DateFormat('EEEE, d MMM yyyy').format(c.followUpDate!),
                trailing: const [PBadge('Scheduled', tone: PTone.blue)],
              ),
          ],
        ),
      ),
    ];
  }

  // ── Derived values ────────────────────────────────────────────────────

  static PTone _tone(ReadingLevel level) => switch (level) {
        ReadingLevel.usual => PTone.ok,
        ReadingLevel.low => PTone.blue,
        ReadingLevel.watch => PTone.warn,
        ReadingLevel.high => PTone.red,
      };

  String _vitalsSummary(VitalSigns v) {
    final parts = <String>[
      if (v.systolicBP != null && v.diastolicBP != null) 'BP ${v.bloodPressure}',
      if (v.weight != null) 'Weight ${v.weight!.toStringAsFixed(0)}kg',
      if (v.pulseRate != null) 'HR ${v.pulseRate}',
    ];
    return parts.isEmpty ? 'No vitals recorded' : parts.join(' · ');
  }

  /// Headed with the *active* patient. Sharing a dependant's vitals under
  /// the guardian's name and MediLink ID would hand a clinician a
  /// mislabelled record.
  void _share(ActivePatient subject, ConsultationModel? latest) {
    final sb = StringBuffer();
    sb.writeln('AfiCare MediLink — Health Summary');
    sb.writeln('Patient: ${subject.fullName.isEmpty ? 'Unknown' : subject.fullName}');
    sb.writeln('MediLink ID: ${subject.medilinkId ?? 'N/A'}');
    sb.writeln('Date: ${DateFormat('d MMM yyyy').format(DateTime.now())}');
    final readings = latest == null ? const <VitalReading>[] : VitalReadings.of(latest.vitalSigns);
    if (latest != null && readings.isNotEmpty) {
      sb.writeln('');
      sb.writeln('Latest readings (visit on ${DateFormat('d MMM yyyy').format(latest.timestamp)}):');
      for (final r in readings) {
        sb.writeln('  ${r.name}: ${r.value} (${r.status})');
      }
    }
    Share.share(sb.toString());
  }
}

/// Simple proportional bar chart matching the spec's `.chart`/`.bar`.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    // Keep bars readable when every reading is similar.
    final floor = (minV - 10).clamp(0, double.infinity);
    final span = (maxV - floor) == 0 ? 1 : (maxV - floor);

    return Column(
      children: [
        SizedBox(
          height: 145,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(values[i].toStringAsFixed(0), style: PT.rowSub().copyWith(fontSize: 10)),
                      const SizedBox(height: 4),
                      Container(
                        height: (((values[i] - floor) / span) * 110).clamp(6, 110).toDouble(),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [PT.teal, Color(0xFFB4E0D8)],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(7),
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: PT.rowSub().copyWith(fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
