enum AdherenceStatus { pending, taken, skipped }

class AdherenceLogModel {
  final String id;
  final String prescriptionId;
  final String patientId;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final String? skippedReason;
  final AdherenceStatus status;
  final DateTime notedAt;

  // Optional joined medication name (from prescriptions)
  final String? medicationName;
  final String? dosage;

  AdherenceLogModel({
    required this.id,
    required this.prescriptionId,
    required this.patientId,
    required this.scheduledTime,
    this.takenTime,
    this.skippedReason,
    this.status = AdherenceStatus.pending,
    required this.notedAt,
    this.medicationName,
    this.dosage,
  });

  factory AdherenceLogModel.fromJson(Map<String, dynamic> json) {
    String? medName;
    String? dose;
    final rx = json['prescriptions'];
    if (rx is Map<String, dynamic>) {
      medName = rx['medication_name'] as String?;
      dose = rx['dosage'] as String?;
    }
    return AdherenceLogModel(
      id: json['id'] as String,
      prescriptionId: json['prescription_id'] as String,
      patientId: json['patient_id'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      takenTime: json['taken_time'] != null
          ? DateTime.parse(json['taken_time'] as String)
          : null,
      skippedReason: json['skipped_reason'] as String?,
      status: _statusFromString(json['status'] as String? ?? 'pending'),
      notedAt: json['noted_at'] != null
          ? DateTime.parse(json['noted_at'] as String)
          : DateTime.now(),
      medicationName: medName ?? json['medication_name'] as String?,
      dosage: dose ?? json['dosage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescription_id': prescriptionId,
      'patient_id': patientId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'taken_time': takenTime?.toIso8601String(),
      'skipped_reason': skippedReason,
      'status': _statusToString(status),
      'noted_at': notedAt.toIso8601String(),
    };
  }

  AdherenceLogModel copyWith({
    AdherenceStatus? status,
    DateTime? takenTime,
    String? skippedReason,
  }) {
    return AdherenceLogModel(
      id: id,
      prescriptionId: prescriptionId,
      patientId: patientId,
      scheduledTime: scheduledTime,
      takenTime: takenTime ?? this.takenTime,
      skippedReason: skippedReason ?? this.skippedReason,
      status: status ?? this.status,
      notedAt: notedAt,
      medicationName: medicationName,
      dosage: dosage,
    );
  }

  static AdherenceStatus _statusFromString(String s) {
    switch (s) {
      case 'taken':
        return AdherenceStatus.taken;
      case 'skipped':
        return AdherenceStatus.skipped;
      default:
        return AdherenceStatus.pending;
    }
  }

  static String _statusToString(AdherenceStatus s) {
    switch (s) {
      case AdherenceStatus.taken:
        return 'taken';
      case AdherenceStatus.skipped:
        return 'skipped';
      case AdherenceStatus.pending:
        return 'pending';
    }
  }
}
