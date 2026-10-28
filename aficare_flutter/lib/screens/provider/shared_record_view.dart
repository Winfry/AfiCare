import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/record_share_model.dart';
import '../../utils/theme.dart';

/// What a doctor or nurse sees after opening a patient's share code: only
/// the sections the patient chose (the database sends nothing else), and
/// a plain list of what was not shared, so an empty card is never mistaken
/// for "none".
class SharedRecordView extends StatelessWidget {
  const SharedRecordView({
    super.key,
    required this.record,
    required this.onBack,
    this.onStartConsultation,
  });

  final SharedRecord record;
  final VoidCallback onBack;

  /// Null hides the button (a dependant can't have a consultation yet).
  final VoidCallback? onStartConsultation;

  static final _day = DateFormat('d MMM yyyy');
  static final _dayTime = DateFormat('d MMM · HH:mm');

  @override
  Widget build(BuildContext context) {
    final r = record;
    final notShared = [
      for (final s in ShareSection.all)
        if (!r.has(s.id)) s.label,
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(r),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _notice(
                  icon: Icons.verified_user,
                  color: AfiCareTheme.primaryBlue,
                  text: 'Shared by ${r.isDependant ? (r.guardianName ?? 'the guardian') : 'the patient'} '
                      'until ${_dayTime.format(r.expiresAt)}. You see only the parts they chose. '
                      'This opening is logged and they can see it.',
                ),
                const SizedBox(height: 16),
                if (r.has('basic_info')) _basicInfo(r),
                if (r.has('allergies')) _allergies(r.allergies ?? const []),
                if (r.has('medications')) _medicines(r),
                if (r.has('medical_history')) _history(r),
                if (r.has('vital_signs')) _vitals(r.vitals ?? const []),
                if (r.has('lab_results')) _labs(r.labs ?? const []),
                if (notShared.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Text(
                      'Not shared: ${notShared.join(', ')}. Ask the patient if you need these.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    if (onStartConsultation != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onStartConsultation,
                          icon: const Icon(Icons.medical_services),
                          label: const Text('New Consultation'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AfiCareTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(SharedRecord r) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryBlue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              r.patientName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AfiCareTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            r.whoseRecord,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (r.medilinkId != null) ...[
            const SizedBox(height: 4),
            Text(r.medilinkId!, style: TextStyle(color: Colors.white.withOpacity(0.85))),
          ],
        ],
      ),
    );
  }

  Widget _notice({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _muted(String text) => Text(text, style: TextStyle(color: Colors.grey.shade600));

  Widget _line(String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _subheading(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
      );

  Widget _basicInfo(SharedRecord r) {
    final age = r.ageOn(DateTime.now());
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    return _section('Basic info', Icons.badge, AfiCareTheme.primaryBlue, [
      _line('Date of birth',
          r.dateOfBirth == null ? 'Not recorded' : '${_day.format(r.dateOfBirth!)}${age != null ? ' ($age years)' : ''}'),
      _line('Sex', (r.gender == null || r.gender!.isEmpty) ? 'Not recorded' : cap(r.gender!)),
      _line('Blood type', (r.bloodType == null || r.bloodType!.isEmpty) ? 'Not recorded' : r.bloodType!),
    ]);
  }

  Widget _allergies(List<String> allergies) {
    return _section('Allergies', Icons.warning_amber, Colors.orange.shade700, [
      if (allergies.isEmpty)
        _muted('None recorded in AfiCare. Ask the patient.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in allergies)
              Chip(
                backgroundColor: Colors.red.shade50,
                avatar: Icon(Icons.dangerous, size: 16, color: Colors.red.shade700),
                label: Text(a, style: TextStyle(color: Colors.red.shade700)),
              ),
          ],
        ),
    ]);
  }

  Widget _medicines(SharedRecord r) {
    final prescribed = r.prescribed ?? const [];
    final own = r.selfReportedMedicines ?? const [];
    return _section('Medicines', Icons.medication, AfiCareTheme.primaryGreen, [
      if (prescribed.isEmpty && own.isEmpty) _muted('No current medicines recorded in AfiCare.'),
      for (final p in prescribed)
        _line(
          [p['medication_name'], p['dosage']].whereType<String>().join(' '),
          [
            p['frequency'],
            p['duration'],
            if (p['provider_name'] != null) 'prescribed by ${p['provider_name']}',
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      if (own.isNotEmpty) ...[
        _subheading('Told us they take'),
        for (final m in own) _line(m),
      ],
    ]);
  }

  Widget _history(SharedRecord r) {
    final conditions = r.conditions ?? const [];
    final visits = r.visits ?? const [];
    final vaccines = r.vaccinations ?? const [];
    return _section('Medical history', Icons.history, AfiCareTheme.primaryBlue, [
      _subheading('Long-term conditions'),
      if (conditions.isEmpty) _muted('None recorded.') else for (final c in conditions) _line(c),
      _subheading('Recent visits'),
      if (visits.isEmpty)
        _muted('No visits recorded in AfiCare.')
      else
        for (final v in visits)
          _line(
            '${_date(v['date']) ?? ''} · ${v['chief_complaint'] ?? 'Visit'}',
            [
              if ((v['diagnoses'] as List?)?.isNotEmpty == true) (v['diagnoses'] as List).join(', '),
              if (v['provider_name'] != null) 'seen by ${v['provider_name']}',
            ].join(' · '),
          ),
      if (vaccines.isNotEmpty) ...[
        _subheading('Vaccinations'),
        for (final v in vaccines) _line('${v['vaccine_name']}', [_date(v['date_given']), v['status']].whereType<String>().join(' · ')),
      ],
    ]);
  }

  Widget _vitals(List<Map<String, dynamic>> entries) {
    return _section('Vital signs', Icons.monitor_heart, Colors.red, [
      if (entries.isEmpty)
        _muted('No vital signs recorded in AfiCare.')
      else
        for (final e in entries)
          _line(
            _date(e['date']) ?? 'Date unknown',
            e['vital_signs'] is Map ? SharedRecord.vitalsLine(Map<String, dynamic>.from(e['vital_signs'] as Map)) : '',
          ),
    ]);
  }

  Widget _labs(List<Map<String, dynamic>> labs) {
    return _section('Lab results', Icons.science, Colors.purple, [
      if (labs.isEmpty)
        _muted('No lab tests recorded in AfiCare.')
      else
        for (final l in labs)
          _line(
            '${l['test_name'] ?? 'Test'}${_date(l['ordered_at']) != null ? ' · ${_date(l['ordered_at'])}' : ''}',
            _labResult(l),
          ),
    ]);
  }

  static String _labResult(Map<String, dynamic> l) {
    final res = l['result'];
    if (res is! Map) return 'No result yet (${l['status'] ?? 'ordered'})';
    final value = [res['result_value'], res['result_unit']].whereType<String>().join(' ');
    final low = res['reference_range_low'], high = res['reference_range_high'];
    final range = (low != null || high != null) ? ' (normal ${low ?? '?'}–${high ?? '?'})' : '';
    final flag = res['result_flag'];
    return '$value$range${flag != null && flag != 'normal' ? ' · ${flag.toString().toUpperCase()}' : ''}';
  }

  static String? _date(Object? v) {
    final d = v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return d == null ? null : _day.format(d);
  }
}
