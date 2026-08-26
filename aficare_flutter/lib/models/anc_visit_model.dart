class AncVisit {
  final String id;
  final String patientId;
  final int visitNumber;
  final int gestationalWeeks;
  final String trimester; // 'first', 'second', 'third'
  final DateTime visitDate;
  final double? fundalHeight;
  final int? fetalHeartRate;
  final int? systolicBP;
  final int? diastolicBP;
  final double? weight;
  final double? hemoglobin;
  final String? urineProtein;
  final String? urineGlucose;
  final bool? hivTested;
  final String? hivResult;
  final String? notes;
  final List<String> dangerSigns;
  final String? nextVisitDate;
  final String facility;

  AncVisit({
    required this.id,
    required this.patientId,
    required this.visitNumber,
    required this.gestationalWeeks,
    required this.trimester,
    required this.visitDate,
    this.fundalHeight,
    this.fetalHeartRate,
    this.systolicBP,
    this.diastolicBP,
    this.weight,
    this.hemoglobin,
    this.urineProtein,
    this.urineGlucose,
    this.hivTested,
    this.hivResult,
    this.notes,
    this.dangerSigns = const [],
    this.nextVisitDate,
    this.facility = '',
  });

  factory AncVisit.fromJson(Map<String, dynamic> json) {
    return AncVisit(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      visitNumber: json['visit_number'] as int? ?? 1,
      gestationalWeeks: json['gestational_weeks'] as int? ?? 0,
      trimester: json['trimester'] as String? ?? 'first',
      visitDate: json['visit_date'] != null
          ? DateTime.tryParse(json['visit_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      fundalHeight: (json['fundal_height'] as num?)?.toDouble(),
      fetalHeartRate: json['fetal_heart_rate'] as int?,
      systolicBP: json['systolic_bp'] as int?,
      diastolicBP: json['diastolic_bp'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      hemoglobin: (json['hemoglobin'] as num?)?.toDouble(),
      urineProtein: json['urine_protein'] as String?,
      urineGlucose: json['urine_glucose'] as String?,
      hivTested: json['hiv_tested'] as bool?,
      hivResult: json['hiv_result'] as String?,
      notes: json['notes'] as String?,
      dangerSigns: json['danger_signs'] != null
          ? List<String>.from(json['danger_signs'] as List)
          : <String>[],
      nextVisitDate: json['next_visit_date'] as String?,
      facility: json['facility'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'visit_number': visitNumber,
      'gestational_weeks': gestationalWeeks,
      'trimester': trimester,
      'visit_date': visitDate.toIso8601String(),
      'fundal_height': fundalHeight,
      'fetal_heart_rate': fetalHeartRate,
      'systolic_bp': systolicBP,
      'diastolic_bp': diastolicBP,
      'weight': weight,
      'hemoglobin': hemoglobin,
      'urine_protein': urineProtein,
      'urine_glucose': urineGlucose,
      'hiv_tested': hivTested,
      'hiv_result': hivResult,
      'notes': notes,
      'danger_signs': dangerSigns,
      'next_visit_date': nextVisitDate,
      'facility': facility,
    };
  }

  static String trimesterFromWeeks(int weeks) {
    if (weeks <= 12) return 'first';
    if (weeks <= 27) return 'second';
    return 'third';
  }

  static String trimesterLabel(String trimester) {
    switch (trimester) {
      case 'first': return '1st Trimester (Weeks 1-12)';
      case 'second': return '2nd Trimester (Weeks 13-27)';
      case 'third': return '3rd Trimester (Weeks 28-40)';
      default: return trimester;
    }
  }

  static const List<String> dangerSignsList = [
    'Severe headache',
    'Blurred vision',
    'Severe abdominal pain',
    'Vaginal bleeding',
    'Reduced fetal movement',
    'Severe vomiting',
    'Swelling of face/hands',
    'Fever > 38°C',
    'Foul-smelling vaginal discharge',
    'Convulsions/seizures',
    'Difficulty breathing',
    'Feeling faint/unconscious',
  ];
}
