class VisitModel {
  final String id;
  final String facilityId;
  final String facilityPatientId;
  final String status;
  final String priority;
  final String? providerId;
  final String? chiefComplaint;
  final String? notes;
  final DateTime occurredAt;
  final DateTime statusChangedAt;
  final String? createdBy;
  final DateTime createdAt;

  VisitModel({
    required this.id,
    required this.facilityId,
    required this.facilityPatientId,
    this.status = 'registered',
    this.priority = 'routine',
    this.providerId,
    this.chiefComplaint,
    this.notes,
    required this.occurredAt,
    DateTime? statusChangedAt,
    this.createdBy,
    required this.createdAt,
  }) : statusChangedAt = statusChangedAt ?? occurredAt;

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      status: json['status'] as String? ?? 'registered',
      priority: json['priority'] as String? ?? 'routine',
      providerId: json['provider_id'] as String?,
      chiefComplaint: json['chief_complaint'] as String?,
      notes: json['notes'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      statusChangedAt: json['status_changed_at'] != null
          ? DateTime.parse(json['status_changed_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_id': facilityId,
      'facility_patient_id': facilityPatientId,
      'status': status,
      'priority': priority,
      'provider_id': providerId,
      'chief_complaint': chiefComplaint,
      'notes': notes,
      'occurred_at': occurredAt.toIso8601String(),
      'status_changed_at': statusChangedAt.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
