/// A part of the record a patient can choose to share. The ids are the
/// ones migration 044 accepts; mental health is never one of them.
class ShareSection {
  const ShareSection(this.id, this.label);
  final String id;
  final String label;

  static const all = [
    ShareSection('basic_info', 'Basic info'),
    ShareSection('allergies', 'Allergies'),
    ShareSection('medications', 'Medicines'),
    ShareSection('medical_history', 'Medical history'),
    ShareSection('vital_signs', 'Vital signs'),
    ShareSection('lab_results', 'Lab results'),
  ];

  static String labelOf(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => ShareSection(id, id.replaceAll('_', ' '))).label;
}

enum ShareStatus { active, revoked, expired }

/// A share the patient made, as `my_record_shares()` returns it.
class RecordShare {
  const RecordShare({
    required this.id,
    required this.code,
    required this.sections,
    required this.createdAt,
    required this.expiresAt,
    this.revokedAt,
    this.openedAt,
    this.openedByName,
    this.openedByRole,
    this.lastViewedAt,
    this.viewCount = 0,
  });

  final String id;
  final String code;
  final List<String> sections;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime? openedAt;
  final String? openedByName;
  final String? openedByRole;
  final DateTime? lastViewedAt;
  final int viewCount;

  /// How long a share can last, in hours, as migration 044 accepts.
  static const durations = [(1, '1 hour'), (4, '4 hours'), (24, '24 hours'), (72, '3 days'), (168, '7 days')];

  static String durationLabel(int hours) =>
      durations.firstWhere((d) => d.$1 == hours, orElse: () => (hours, '$hours hours')).$2;

  factory RecordShare.fromJson(Map<String, dynamic> json) => RecordShare(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        sections: (json['sections'] as List? ?? const []).map((e) => e.toString()).toList(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
        revokedAt: _date(json['revoked_at']),
        openedAt: _date(json['opened_at']),
        openedByName: json['opened_by_name'] as String?,
        openedByRole: json['opened_by_role'] as String?,
        lastViewedAt: _date(json['last_viewed_at']),
        viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      );

  ShareStatus statusAt(DateTime now) {
    if (revokedAt != null) return ShareStatus.revoked;
    if (!expiresAt.isAfter(now)) return ShareStatus.expired;
    return ShareStatus.active;
  }

  bool isActiveAt(DateTime now) => statusAt(now) == ShareStatus.active;

  /// "Dr Otieno", or "a nurse" when the name is missing.
  String? get openedBy {
    if (openedAt == null) return null;
    final name = openedByName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return openedByRole == 'nurse' ? 'a nurse' : 'a doctor';
  }

  String get sectionLabels => sections.map(ShareSection.labelOf).join(', ');

  // ── Codes ─────────────────────────────────────────────────────

  /// "ABCD-2345": easier to read out than eight characters in a row.
  static String formatCode(String code) {
    final c = normaliseCode(code);
    return c.length == 8 ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
  }

  /// What was typed, as the database stores it: capitals, with spaces
  /// and dashes taken out.
  static String normaliseCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static const _qrPrefix = 'AFICARE-SHARE:';

  /// What a share's QR holds: the code, never the record itself.
  static String qrData(String code) => '$_qrPrefix${normaliseCode(code)}';

  /// The code in a scanned share QR, or null when [raw] isn't one.
  static String? codeFromQr(String raw) {
    final text = raw.trim();
    if (!text.toUpperCase().startsWith(_qrPrefix)) return null;
    final code = normaliseCode(text.substring(_qrPrefix.length));
    return code.length == 8 ? code : null;
  }
}

/// What a doctor or nurse sees after opening a share, as
/// `open_record_share()` returns it. A section that wasn't shared is null;
/// one that was shared but has nothing in it is empty.
class SharedRecord {
  const SharedRecord({
    required this.shareId,
    required this.patientId,
    required this.patientName,
    required this.sections,
    required this.expiresAt,
    this.medilinkId,
    this.isDependant = false,
    this.guardianName,
    this.relationship,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.allergies,
    this.prescribed,
    this.selfReportedMedicines,
    this.conditions,
    this.visits,
    this.vaccinations,
    this.vitals,
    this.labs,
  });

  final String shareId;
  final String patientId;
  final String patientName;
  final String? medilinkId;
  final bool isDependant;
  final String? guardianName;
  final String? relationship;
  final List<String> sections;
  final DateTime expiresAt;

  // basic_info
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodType;

  final List<String>? allergies;

  // medications
  final List<Map<String, dynamic>>? prescribed;
  final List<String>? selfReportedMedicines;

  // medical_history
  final List<String>? conditions;
  final List<Map<String, dynamic>>? visits;
  final List<Map<String, dynamic>>? vaccinations;

  /// Each: {'date': DateTime?, 'vital_signs': Map}.
  final List<Map<String, dynamic>>? vitals;
  final List<Map<String, dynamic>>? labs;

  bool has(String section) => sections.contains(section);

  factory SharedRecord.fromJson(Map<String, dynamic> json) {
    final basic = json['basic_info'] as Map?;
    final meds = json['medications'] as Map?;
    final history = json['medical_history'] as Map?;
    return SharedRecord(
      shareId: json['share_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: (json['patient_name'] as String?)?.trim().isNotEmpty == true
          ? (json['patient_name'] as String).trim()
          : 'Patient',
      medilinkId: json['medilink_id'] as String?,
      isDependant: json['is_dependant'] == true,
      guardianName: json['guardian_name'] as String?,
      relationship: json['relationship'] as String?,
      sections: (json['sections'] as List? ?? const []).map((e) => e.toString()).toList(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      dateOfBirth: basic == null ? null : DateTime.tryParse(basic['date_of_birth'] as String? ?? ''),
      gender: basic?['gender'] as String?,
      bloodType: basic?['blood_type'] as String?,
      allergies: _strings(json['allergies']),
      prescribed: meds == null ? null : _maps(meds['prescribed']),
      selfReportedMedicines: meds == null ? null : _strings(meds['self_reported']),
      conditions: history == null ? null : _strings(history['conditions']),
      visits: history == null ? null : _maps(history['visits']),
      vaccinations: history == null ? null : _maps(history['vaccinations']),
      vitals: _maps(json['vital_signs']),
      labs: _maps(json['lab_results']),
    );
  }

  /// Age in whole years on [today], when the date of birth was shared.
  int? ageOn(DateTime today) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  /// "Brian · Mary Wanjiru's child" for a dependant.
  String get whoseRecord {
    if (!isDependant) return patientName;
    final guardian = guardianName?.trim();
    if (guardian == null || guardian.isEmpty) return patientName;
    final rel = (relationship == null || relationship!.isEmpty) ? 'dependant' : relationship!;
    return "$patientName · $guardian's $rel";
  }

  /// One visit's vital signs on a line: "Temp 37.9 °C · BP 120/80 · …".
  static String vitalsLine(Map<String, dynamic> v) {
    String? n(String key) {
      final x = v[key];
      if (x is! num) return null;
      return x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
    }

    final sys = n('systolic_bp'), dia = n('diastolic_bp');
    return [
      if (n('temperature') != null) 'Temp ${n('temperature')} °C',
      if (sys != null || dia != null) 'BP ${sys ?? '–'}/${dia ?? '–'}',
      if (n('pulse_rate') != null) 'Pulse ${n('pulse_rate')}',
      if (n('respiratory_rate') != null) 'Breaths ${n('respiratory_rate')}/min',
      if (n('oxygen_saturation') != null) 'SpO₂ ${n('oxygen_saturation')}%',
      if (n('weight') != null) 'Weight ${n('weight')} kg',
      if (n('height') != null) 'Height ${n('height')} cm',
    ].join(' · ');
  }

  static List<String>? _strings(Object? v) =>
      v is List ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : null;

  static List<Map<String, dynamic>>? _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : null;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
