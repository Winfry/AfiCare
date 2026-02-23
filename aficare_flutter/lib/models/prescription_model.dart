enum PrescriptionStatus { active, completed, cancelled }

class PrescriptionModel {
  final String id;
  final String patientId;
  final String providerId;
  final String? consultationId;
  final String medicationName;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final PrescriptionStatus status;

  PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.consultationId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
    required this.issuedAt,
    this.expiresAt,
    required this.status,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      consultationId: json['consultation_id'] as String?,
      medicationName: json['medication_name'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String,
      instructions: json['instructions'] as String?,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      status: _statusFromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'consultation_id': consultationId,
      'medication_name': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'status': _statusToString(status),
    };
  }

  PrescriptionModel copyWith({
    String? id,
    String? patientId,
    String? providerId,
    String? consultationId,
    String? medicationName,
    String? dosage,
    String? frequency,
    String? duration,
    String? instructions,
    DateTime? issuedAt,
    DateTime? expiresAt,
    PrescriptionStatus? status,
  }) {
    return PrescriptionModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      consultationId: consultationId ?? this.consultationId,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      instructions: instructions ?? this.instructions,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  static PrescriptionStatus _statusFromString(String s) {
    switch (s) {
      case 'completed':
        return PrescriptionStatus.completed;
      case 'cancelled':
        return PrescriptionStatus.cancelled;
      default:
        return PrescriptionStatus.active;
    }
  }

  static String _statusToString(PrescriptionStatus s) {
    switch (s) {
      case PrescriptionStatus.completed:
        return 'completed';
      case PrescriptionStatus.cancelled:
        return 'cancelled';
      case PrescriptionStatus.active:
        return 'active';
    }
  }
}
