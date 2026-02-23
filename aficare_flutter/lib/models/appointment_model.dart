enum AppointmentType { inPerson, telehealth }

enum AppointmentStatus { pending, confirmed, completed, cancelled }

class AppointmentModel {
  final String id;
  final String patientId;
  final String providerId;
  final String? facilityId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final AppointmentType type;
  final AppointmentStatus status;
  final String? chiefComplaint;
  final String? notes;
  final bool isFollowUp;
  final String? consultationId;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.facilityId,
    required this.scheduledAt,
    this.durationMinutes = 30,
    required this.type,
    required this.status,
    this.chiefComplaint,
    this.notes,
    this.isFollowUp = false,
    this.consultationId,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      facilityId: json['facility_id'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: (json['duration_minutes'] as int?) ?? 30,
      type: _typeFromString(json['type'] as String),
      status: _statusFromString(json['status'] as String),
      chiefComplaint: json['chief_complaint'] as String?,
      notes: json['notes'] as String?,
      isFollowUp: (json['is_follow_up'] as bool?) ?? false,
      consultationId: json['consultation_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'facility_id': facilityId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'type': _typeToString(type),
      'status': _statusToString(status),
      'chief_complaint': chiefComplaint,
      'notes': notes,
      'is_follow_up': isFollowUp,
      'consultation_id': consultationId,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? providerId,
    String? facilityId,
    DateTime? scheduledAt,
    int? durationMinutes,
    AppointmentType? type,
    AppointmentStatus? status,
    String? chiefComplaint,
    String? notes,
    bool? isFollowUp,
    String? consultationId,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      facilityId: facilityId ?? this.facilityId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      status: status ?? this.status,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      notes: notes ?? this.notes,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      consultationId: consultationId ?? this.consultationId,
    );
  }

  static AppointmentType _typeFromString(String s) {
    switch (s) {
      case 'telehealth':
        return AppointmentType.telehealth;
      default:
        return AppointmentType.inPerson;
    }
  }

  static String _typeToString(AppointmentType t) {
    switch (t) {
      case AppointmentType.telehealth:
        return 'telehealth';
      case AppointmentType.inPerson:
        return 'in-person';
    }
  }

  static AppointmentStatus _statusFromString(String s) {
    switch (s) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.pending;
    }
  }

  static String _statusToString(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed:
        return 'confirmed';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.pending:
        return 'pending';
    }
  }
}
