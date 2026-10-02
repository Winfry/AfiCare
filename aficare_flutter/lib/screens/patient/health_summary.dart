import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/consultation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/patient_tokens.dart';
import 'medication_tracker_screen.dart';
import 'widgets/patient_ui.dart';

/// Health Records — the patient's own summary: a derived health score,
/// their latest visit and vitals, a trend across visits, and the way in
/// to lab results, prescriptions and visit history.
class HealthSummary extends StatelessWidget {
  const HealthSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final patient = context.watch<PatientProvider>();
    final profile = context.watch<PatientProfileProvider>().profile;

    final user = auth.currentUser;
    final consultations = List<ConsultationModel>.from(patient.consultations)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final latest = consultations.isEmpty ? null : consultations.first;
    final vitals = latest?.vitalSigns;
    final score = _healthScore(vitals);
    final allergies = profile?.allergies ?? const <String>[];

    return PDetailScaffold(
      eyebrow: 'Records',
      title: 'Health Records',
      subtitle: 'Your health summary, visits, results and prescriptions.',
      action: PButton(
        'Share summary',
        kind: PButtonKind.alt,
        icon: Icons.ios_share,
        onPressed: () => _share(user, vitals, score),
      ),
      children: [
        if (patient.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator(color: PT.teal)),
          )
        else ...[
          PGrid(
            columns: 3,
            children: [
              _scoreCard(score),
              _recentVisitCard(latest),
              _allergiesCard(allergies),
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

  Widget _scoreCard(int? score) {
    final (label, tone) = _scoreInfo(score);
    return PScore(
      label: 'Health score',
      value: score?.toString() ?? '—',
      badge: PBadge(label, tone: tone),
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

  Widget _allergiesCard(List<String> allergies) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allergies', style: PT.label()),
          const SizedBox(height: 7),
          if (allergies.isEmpty) ...[
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
          const PCardTitle('Health trend'),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
            ),
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
    final rows = <Widget>[
      if (v.temperature != null)
        _vitalRow('Temperature', '${v.temperature!.toStringAsFixed(1)} °C', _tempTone(v.temperature)),
      if (v.systolicBP != null && v.diastolicBP != null)
        _vitalRow('Blood pressure', '${v.bloodPressure} mmHg', _bpTone(v.systolicBP, v.diastolicBP)),
      if (v.pulseRate != null)
        _vitalRow('Heart rate', '${v.pulseRate} bpm', _hrTone(v.pulseRate)),
      if (v.oxygenSaturation != null)
        _vitalRow('Oxygen (SpO₂)', '${v.oxygenSaturation}%', _spo2Tone(v.oxygenSaturation)),
      if (_bmi(v) != null)
        _vitalRow('BMI', _bmi(v)!.toStringAsFixed(1), _bmiTone(_bmi(v))),
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

  Widget _vitalRow(String label, String value, (String, PTone) status) {
    return PRow(
      title: label,
      subtitle: value,
      trailing: [PBadge(status.$1, tone: status.$2)],
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

  int? _healthScore(VitalSigns? v) {
    if (v == null) return null;
    int checks = 0, passed = 0;
    void check(bool applicable, bool ok) {
      if (!applicable) return;
      checks++;
      if (ok) passed++;
    }

    check(v.temperature != null, v.temperature != null && v.temperature! >= 36.1 && v.temperature! <= 37.2);
    check(v.systolicBP != null, v.systolicBP != null && v.systolicBP! >= 90 && v.systolicBP! <= 120);
    check(v.diastolicBP != null, v.diastolicBP != null && v.diastolicBP! >= 60 && v.diastolicBP! <= 80);
    check(v.pulseRate != null, v.pulseRate != null && v.pulseRate! >= 60 && v.pulseRate! <= 100);
    check(v.oxygenSaturation != null, v.oxygenSaturation != null && v.oxygenSaturation! >= 95);

    if (checks == 0) return null;
    return ((passed / checks) * 100).round();
  }

  (String, PTone) _scoreInfo(int? score) {
    if (score == null) return ('No data', PTone.gray);
    if (score >= 80) return ('Excellent', PTone.ok);
    if (score >= 60) return ('Good', PTone.ok);
    if (score >= 40) return ('Fair', PTone.warn);
    return ('Needs attention', PTone.red);
  }

  (String, PTone) _tempTone(double? t) {
    if (t == null) return ('No data', PTone.gray);
    if (t < 36.1) return ('Low', PTone.blue);
    if (t <= 37.2) return ('Normal', PTone.ok);
    if (t <= 38.0) return ('Low fever', PTone.warn);
    return ('Fever', PTone.red);
  }

  (String, PTone) _bpTone(int? sys, int? dia) {
    if (sys == null || dia == null) return ('No data', PTone.gray);
    if (sys < 90 || dia < 60) return ('Low', PTone.blue);
    if (sys <= 120 && dia <= 80) return ('Normal', PTone.ok);
    if (sys <= 130) return ('Elevated', PTone.warn);
    return ('High', PTone.red);
  }

  (String, PTone) _hrTone(int? hr) {
    if (hr == null) return ('No data', PTone.gray);
    if (hr < 60) return ('Low', PTone.blue);
    if (hr <= 100) return ('Normal', PTone.ok);
    return ('High', PTone.red);
  }

  (String, PTone) _spo2Tone(double? s) {
    if (s == null) return ('No data', PTone.gray);
    if (s >= 95) return ('Normal', PTone.ok);
    if (s >= 90) return ('Low', PTone.warn);
    return ('Critical', PTone.red);
  }

  (String, PTone) _bmiTone(double? bmi) {
    if (bmi == null) return ('No data', PTone.gray);
    if (bmi < 18.5) return ('Underweight', PTone.blue);
    if (bmi < 25) return ('Normal', PTone.ok);
    if (bmi < 30) return ('Overweight', PTone.warn);
    return ('Obese', PTone.red);
  }

  double? _bmi(VitalSigns v) {
    if (v.weight == null || v.height == null || v.height! <= 0) return null;
    return v.weight! / (v.height! * v.height!);
  }

  String _vitalsSummary(VitalSigns v) {
    final parts = <String>[
      if (v.systolicBP != null && v.diastolicBP != null) 'BP ${v.bloodPressure}',
      if (v.weight != null) 'Weight ${v.weight!.toStringAsFixed(0)}kg',
      if (v.pulseRate != null) 'HR ${v.pulseRate}',
    ];
    return parts.isEmpty ? 'No vitals recorded' : parts.join(' · ');
  }

  void _share(UserModel? user, VitalSigns? v, int? score) {
    final sb = StringBuffer();
    sb.writeln('AfiCare MediLink — Health Summary');
    sb.writeln('Patient: ${user?.fullName ?? 'Unknown'}');
    sb.writeln('MediLink ID: ${user?.medilinkId ?? 'N/A'}');
    sb.writeln('Date: ${DateFormat('d MMM yyyy').format(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Health Score: ${score?.toString() ?? 'No data'}');
    if (v != null) {
      sb.writeln('');
      sb.writeln('Latest Vital Signs:');
      if (v.temperature != null) {
        sb.writeln('  Temperature: ${v.temperature!.toStringAsFixed(1)}°C');
      }
      sb.writeln('  Blood Pressure: ${v.bloodPressure} mmHg');
      if (v.pulseRate != null) sb.writeln('  Heart Rate: ${v.pulseRate} bpm');
      if (v.oxygenSaturation != null) sb.writeln('  SpO₂: ${v.oxygenSaturation}%');
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
