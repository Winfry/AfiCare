class MedicationReminder {
  final String id;
  final String patientId;
  final String medicationName;
  final String dosage;
  final String frequency; // 'once_daily', 'twice_daily', 'three_times', 'four_times', 'as_needed'
  final List<ReminderTime> times;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final String? prescriptionId;
  final DateTime createdAt;

  MedicationReminder({
    required this.id,
    required this.patientId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    this.times = const [],
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.notes,
    this.prescriptionId,
    required this.createdAt,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'once_daily',
      times: json['times'] != null
          ? (json['times'] as List).map((t) => ReminderTime.fromJson(t)).toList()
          : <ReminderTime>[],
      isActive: json['is_active'] as bool? ?? true,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      notes: json['notes'] as String?,
      prescriptionId: json['prescription_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'medication_name': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'times': times.map((t) => t.toJson()).toList(),
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'prescription_id': prescriptionId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String frequencyLabel(String frequency) {
    switch (frequency) {
      case 'once_daily': return 'Once daily';
      case 'twice_daily': return 'Twice daily';
      case 'three_times': return '3 times daily';
      case 'four_times': return '4 times daily';
      case 'as_needed': return 'As needed';
      default: return frequency;
    }
  }

  static String frequencyIcon(String frequency) {
    switch (frequency) {
      case 'once_daily': return '💊';
      case 'twice_daily': return '💊💊';
      case 'three_times': return '💊💊💊';
      case 'four_times': return '💊💊💊💊';
      case 'as_needed': return '📦';
      default: return '💊';
    }
  }
}

class ReminderTime {
  final int hour;
  final int minute;
  final String? label;

  ReminderTime({required this.hour, required this.minute, this.label});

  factory ReminderTime.fromJson(Map<String, dynamic> json) {
    return ReminderTime(
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'hour': hour, 'minute': minute, 'label': label};
  }

  String get formatted {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  String get shortLabel {
    if (label != null) return label!;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }
}
