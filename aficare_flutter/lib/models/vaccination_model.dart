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
}
