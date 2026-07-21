import 'dart:ui' show Color;

enum ReferralUrgency { routine, urgent, emergency }
enum ReferralStatus { pending, accepted, completed, declined }

class ReferralModel {
  final String id;
  final String patientId;
  final String fromProviderId;
  final String? fromFacility;
  final String toFacility;
  final String? toDepartment;
  final String? toSpecialist;
  final String reason;
  final String? clinicalNotes;
  final ReferralUrgency urgency;
  final ReferralStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseNotes;

  ReferralModel({
    required this.id,
    required this.patientId,
    required this.fromProviderId,
    this.fromFacility,
    required this.toFacility,
    this.toDepartment,
    this.toSpecialist,
    required this.reason,
    this.clinicalNotes,
    this.urgency = ReferralUrgency.routine,
    this.status = ReferralStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.responseNotes,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      fromProviderId: json['from_provider_id'] as String,
      fromFacility: json['from_facility'] as String?,
      toFacility: json['to_facility'] as String,
      toDepartment: json['to_department'] as String?,
      toSpecialist: json['to_specialist'] as String?,
      reason: json['reason'] as String,
      clinicalNotes: json['clinical_notes'] as String?,
      urgency: _urgencyFromString(json['urgency'] as String? ?? 'routine'),
      status: _statusFromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      responseNotes: json['response_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'from_provider_id': fromProviderId,
      'from_facility': fromFacility,
      'to_facility': toFacility,
      'to_department': toDepartment,
      'to_specialist': toSpecialist,
      'reason': reason,
      'clinical_notes': clinicalNotes,
      'urgency': _urgencyToString(urgency),
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'response_notes': responseNotes,
    };
  }

  Color get urgencyColor {
    switch (urgency) {
      case ReferralUrgency.emergency:
        return const Color(0xFFE53935);
      case ReferralUrgency.urgent:
        return const Color(0xFFFB8C00);
      case ReferralUrgency.routine:
        return const Color(0xFF43A047);
    }
  }

  Color get statusColor {
    switch (status) {
      case ReferralStatus.pending:
        return const Color(0xFFFB8C00);
      case ReferralStatus.accepted:
        return const Color(0xFF1E88E5);
      case ReferralStatus.completed:
        return const Color(0xFF43A047);
      case ReferralStatus.declined:
        return const Color(0xFFE53935);
    }
  }

  static ReferralUrgency _urgencyFromString(String s) {
    switch (s) {
      case 'urgent':
        return ReferralUrgency.urgent;
      case 'emergency':
        return ReferralUrgency.emergency;
      default:
        return ReferralUrgency.routine;
    }
  }

  static String _urgencyToString(ReferralUrgency u) {
    switch (u) {
      case ReferralUrgency.urgent:
        return 'urgent';
      case ReferralUrgency.emergency:
        return 'emergency';
      case ReferralUrgency.routine:
        return 'routine';
    }
  }

  static ReferralStatus _statusFromString(String s) {
    switch (s) {
      case 'accepted':
        return ReferralStatus.accepted;
      case 'completed':
        return ReferralStatus.completed;
      case 'declined':
        return ReferralStatus.declined;
      default:
        return ReferralStatus.pending;
    }
  }

  static String statusToString(ReferralStatus s) {
    switch (s) {
      case ReferralStatus.accepted:
        return 'accepted';
      case ReferralStatus.completed:
        return 'completed';
      case ReferralStatus.declined:
        return 'declined';
      case ReferralStatus.pending:
        return 'pending';
    }
  }

  static String _statusToString(ReferralStatus s) => statusToString(s);
}
