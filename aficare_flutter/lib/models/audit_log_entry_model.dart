/// One row from `audit_log`, scoped to a facility via the RLS policy in
/// 027_facility_audit_notifications.sql (there is no facility_id COLUMN
/// on this table -- it lives inside `details`, a raw JSONB blob whose
/// shape varies per action, so it's kept as a plain Map rather than
/// typed fields). Humanized labels and any inline extra text (a name,
/// a new_status, etc.) are extracted in the screen, not here -- same
/// convention as every other screen's local status-label maps.
class AuditLogEntryModel {
  final String id;
  final String action;
  final String? userId;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  AuditLogEntryModel({
    required this.id,
    required this.action,
    required this.userId,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogEntryModel.fromJson(Map<String, dynamic> json) {
    return AuditLogEntryModel(
      id: json['id'] as String,
      action: json['action'] as String,
      userId: json['user_id'] as String?,
      details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
