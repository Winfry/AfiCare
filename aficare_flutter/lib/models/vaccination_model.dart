class VaccinationRecord {
  final String id;
  final String patientId;
  final String vaccineName;
  final String? vaccineType;
  final DateTime dateGiven;
  final DateTime? nextDueDate;
  final String? facility;
  final String? batchNumber;
  final String? administeredBy;
  final String status; // 'completed', 'due', 'overdue', 'skipped'
  final String? notes;

  VaccinationRecord({
    required this.id,
    required this.patientId,
    required this.vaccineName,
    this.vaccineType,
    required this.dateGiven,
    this.nextDueDate,
    this.facility,
    this.batchNumber,
    this.administeredBy,
    this.status = 'completed',
    this.notes,
  });

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    return VaccinationRecord(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      vaccineName: json['vaccine_name'] as String? ?? '',
      vaccineType: json['vaccine_type'] as String?,
      dateGiven: json['date_given'] != null
          ? DateTime.tryParse(json['date_given'] as String) ?? DateTime.now()
          : DateTime.now(),
      nextDueDate: json['next_due_date'] != null
          ? DateTime.tryParse(json['next_due_date'] as String)
          : null,
      facility: json['facility'] as String?,
      batchNumber: json['batch_number'] as String?,
      administeredBy: json['administered_by'] as String?,
      status: json['status'] as String? ?? 'completed',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'vaccine_name': vaccineName,
      'vaccine_type': vaccineType,
      'date_given': dateGiven.toIso8601String(),
      'next_due_date': nextDueDate?.toIso8601String(),
      'facility': facility,
      'batch_number': batchNumber,
      'administered_by': administeredBy,
      'status': status,
      'notes': notes,
    };
  }
}

class VaccineSchedule {
  final String name;
  final String type;
  final int minAgeWeeks;
  final int? maxAgeWeeks;
  final String description;
  final String category; // 'child', 'adolescent', 'adult', 'maternal'

  const VaccineSchedule({
    required this.name,
    required this.type,
    required this.minAgeWeeks,
    this.maxAgeWeeks,
    required this.description,
    required this.category,
  });
}

class VaccinationSchedule {
  static const List<VaccineSchedule> kenyaEPI = [
    // Birth
    VaccineSchedule(name: 'BCG', type: 'BCG', minAgeWeeks: 0, maxAgeWeeks: 1,
        description: 'Tuberculosis', category: 'child'),
    VaccineSchedule(name: 'OPV 0', type: 'OPV', minAgeWeeks: 0, maxAgeWeeks: 2,
        description: 'Oral Polio Vaccine - Birth dose', category: 'child'),
    VaccineSchedule(name: 'HepB 0', type: 'HepB', minAgeWeeks: 0, maxAgeWeeks: 2,
        description: 'Hepatitis B - Birth dose', category: 'child'),

    // 6 weeks
    VaccineSchedule(name: 'OPV 1', type: 'OPV', minAgeWeeks: 6, maxAgeWeeks: 8,
        description: 'Oral Polio Vaccine', category: 'child'),
    VaccineSchedule(name: 'Penta 1', type: 'Pentavalent', minAgeWeeks: 6, maxAgeWeeks: 8,
        description: 'DPT + HepB + Hib', category: 'child'),
    VaccineSchedule(name: 'PCV 1', type: 'PCV', minAgeWeeks: 6, maxAgeWeeks: 8,
        description: 'Pneumococcal Conjugate Vaccine', category: 'child'),
    VaccineSchedule(name: 'Rota 1', type: 'Rotavirus', minAgeWeeks: 6, maxAgeWeeks: 8,
        description: 'Rotavirus Vaccine', category: 'child'),

    // 10 weeks
    VaccineSchedule(name: 'OPV 2', type: 'OPV', minAgeWeeks: 10, maxAgeWeeks: 12,
        description: 'Oral Polio Vaccine', category: 'child'),
    VaccineSchedule(name: 'Penta 2', type: 'Pentavalent', minAgeWeeks: 10, maxAgeWeeks: 12,
        description: 'DPT + HepB + Hib', category: 'child'),
    VaccineSchedule(name: 'PCV 2', type: 'PCV', minAgeWeeks: 10, maxAgeWeeks: 12,
        description: 'Pneumococcal Conjugate Vaccine', category: 'child'),
    VaccineSchedule(name: 'Rota 2', type: 'Rotavirus', minAgeWeeks: 10, maxAgeWeeks: 12,
        description: 'Rotavirus Vaccine', category: 'child'),

    // 14 weeks
    VaccineSchedule(name: 'OPV 3', type: 'OPV', minAgeWeeks: 14, maxAgeWeeks: 16,
        description: 'Oral Polio Vaccine', category: 'child'),
    VaccineSchedule(name: 'Penta 3', type: 'Pentavalent', minAgeWeeks: 14, maxAgeWeeks: 16,
        description: 'DPT + HepB + Hib', category: 'child'),
    VaccineSchedule(name: 'PCV 3', type: 'PCV', minAgeWeeks: 14, maxAgeWeeks: 16,
        description: 'Pneumococcal Conjugate Vaccine', category: 'child'),
    VaccineSchedule(name: 'IPV', type: 'IPV', minAgeWeeks: 14, maxAgeWeeks: 16,
        description: 'Inactivated Polio Vaccine', category: 'child'),

    // 9 months
    VaccineSchedule(name: 'Measles-Rubella 1', type: 'MR', minAgeWeeks: 36, maxAgeWeeks: 44,
        description: 'Measles-Rubella Vaccine', category: 'child'),
    VaccineSchedule(name: 'Yellow Fever', type: 'YF', minAgeWeeks: 36, maxAgeWeeks: 44,
        description: 'Yellow Fever Vaccine', category: 'child'),
    VaccineSchedule(name: 'Malaria (R21)', type: 'R21', minAgeWeeks: 36, maxAgeWeeks: 44,
        description: 'Malaria Vaccine (where available)', category: 'child'),

    // 18 months
    VaccineSchedule(name: 'Measles-Rubella 2', type: 'MR', minAgeWeeks: 72, maxAgeWeeks: 80,
        description: 'Measles-Rubella Booster', category: 'child'),
  ];

  static List<VaccineSchedule> getDueSchedules(int ageWeeks) {
    return kenyaEPI.where((v) {
      if (ageWeeks < v.minAgeWeeks) return false;
      if (v.maxAgeWeeks != null && ageWeeks > v.maxAgeWeeks! + 4) return false;
      return true;
    }).toList();
  }

  /// The schedule above is for babies and young children. From 5 years
  /// old nothing in it is shown as due: an adult has not "missed" their
  /// 6-week polio dose.
  static const childScheduleEndsWeeks = 5 * 52;

  /// Other ways the same dose gets written on a record ("Pentavalent 1",
  /// "MR 1", "Measles Rubella 1", "R21").
  static const _otherNames = {
    'Penta 1': ['Pentavalent 1', 'DPT HepB Hib 1'],
    'Penta 2': ['Pentavalent 2', 'DPT HepB Hib 2'],
    'Penta 3': ['Pentavalent 3', 'DPT HepB Hib 3'],
    'Rota 1': ['Rotavirus 1'],
    'Rota 2': ['Rotavirus 2'],
    'Measles-Rubella 1': ['MR 1', 'Measles 1', 'MR1'],
    'Measles-Rubella 2': ['MR 2', 'Measles 2', 'MR2'],
    'Yellow Fever': ['YF'],
    'Malaria (R21)': ['R21', 'Malaria', 'Malaria 1'],
    'IPV': ['IPV 1'],
  };

  /// Lower case letters and digits only, without the words "vaccine" and
  /// "dose", so "OPV-1", "opv 1" and "OPV dose 1" all read the same.
  static String _key(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'\b(vaccines?|vaccination|dose)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Whether [schedule] — that exact dose — is one of [givenNames].
  /// "OPV 0" being given does not tick OPV 1, 2 and 3.
  static bool isGiven(VaccineSchedule schedule, Iterable<String> givenNames) {
    final mine = {
      _key(schedule.name),
      for (final other in _otherNames[schedule.name] ?? const <String>[]) _key(other),
    };
    return givenNames.any((n) => mine.contains(_key(n)));
  }

  /// The names on records that were actually given (not just planned or
  /// skipped).
  static List<String> givenNames(Iterable<VaccinationRecord> records) =>
      [for (final r in records) if (r.status == 'completed') r.vaccineName];

  /// Where [schedule] stands for someone [ageWeeks] old.
  static VaccineState stateFor(VaccineSchedule schedule, {required int? ageWeeks, required Iterable<String> given}) {
    if (isGiven(schedule, given)) return VaccineState.given;
    if (ageWeeks == null || ageWeeks >= childScheduleEndsWeeks) return VaccineState.notApplicable;
    if (ageWeeks < schedule.minAgeWeeks) return VaccineState.notYet;
    final lateAfter = schedule.maxAgeWeeks ?? schedule.minAgeWeeks + 4;
    return ageWeeks > lateAfter ? VaccineState.overdue : VaccineState.due;
  }

  /// Doses due or overdue now. Empty when the age is unknown or the
  /// person is past the childhood schedule.
  static List<VaccineSchedule> dueNow({required int? ageWeeks, required Iterable<String> given}) => [
        for (final v in kenyaEPI)
          if (const [VaccineState.due, VaccineState.overdue]
              .contains(stateFor(v, ageWeeks: ageWeeks, given: given)))
            v,
      ];

  /// The next dose in the same series ("OPV 1" → "OPV 2"); null for the
  /// last one or a single-dose vaccine.
  static VaccineSchedule? nextInSeries(String vaccineName) {
    final i = kenyaEPI.indexWhere((v) => v.name == vaccineName);
    if (i < 0) return null;
    final type = kenyaEPI[i].type;
    for (final v in kenyaEPI.skip(i + 1)) {
      if (v.type == type) return v;
    }
    return null;
  }

  /// When the next dose after [vaccineName] (given on [given]) is due:
  /// at the age the schedule sets for it, and never sooner than 4 weeks
  /// after this dose. Without a date of birth, the schedule's gap between
  /// the two doses is counted from [given].
  static DateTime? nextDueDate(String vaccineName, {required DateTime given, DateTime? dateOfBirth}) {
    final next = nextInSeries(vaccineName);
    final current = kenyaEPI.where((v) => v.name == vaccineName).firstOrNull;
    if (next == null || current == null) return null;
    final day = DateTime(given.year, given.month, given.day);
    final earliest = day.add(const Duration(days: 28));
    if (dateOfBirth == null) {
      final gapWeeks = next.minAgeWeeks - current.minAgeWeeks;
      final byGap = day.add(Duration(days: gapWeeks * 7));
      return byGap.isAfter(earliest) ? byGap : earliest;
    }
    final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
    final byAge = dob.add(Duration(days: next.minAgeWeeks * 7));
    return byAge.isAfter(earliest) ? byAge : earliest;
  }
}

enum VaccineState {
  given,
  /// Not old enough yet.
  notYet,
  due,
  overdue,
  /// Age unknown, or past the childhood schedule.
  notApplicable,
}
