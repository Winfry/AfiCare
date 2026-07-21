enum RadiologyPriority { routine, urgent, stat }
enum RadiologyStatus { ordered, scheduled, performed, reported, cancelled }

class RadiologyOrderModel {
  final String id;
  final String patientId;
  final String providerId;
  final String? consultationId;
  final String studyType;
  final String bodyPart;
  final String? clinicalIndication;
  final RadiologyPriority priority;
  final RadiologyStatus status;
  final DateTime orderedAt;
  final DateTime? scheduledAt;
  final String? notes;

  // Embedded report
  final RadiologyReportModel? report;

  RadiologyOrderModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.consultationId,
    required this.studyType,
    required this.bodyPart,
    this.clinicalIndication,
    this.priority = RadiologyPriority.routine,
    this.status = RadiologyStatus.ordered,
    required this.orderedAt,
    this.scheduledAt,
    this.notes,
    this.report,
  });

  bool get isReported => status == RadiologyStatus.reported;
  bool get isPending =>
      status == RadiologyStatus.ordered ||
      status == RadiologyStatus.scheduled ||
      status == RadiologyStatus.performed;

  factory RadiologyOrderModel.fromJson(Map<String, dynamic> json) {
    RadiologyReportModel? report;
    final rawReport = json['radiology_reports'];
    if (rawReport is List && rawReport.isNotEmpty) {
      report = RadiologyReportModel.fromJson(rawReport.first as Map<String, dynamic>);
    } else if (json['report'] is Map<String, dynamic>) {
      report = RadiologyReportModel.fromJson(json['report'] as Map<String, dynamic>);
    }

    return RadiologyOrderModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      consultationId: json['consultation_id'] as String?,
      studyType: json['study_type'] as String,
      bodyPart: json['body_part'] as String,
      clinicalIndication: json['clinical_indication'] as String?,
      priority: _priorityFromString(json['priority'] as String? ?? 'routine'),
      status: _statusFromString(json['status'] as String? ?? 'ordered'),
      orderedAt: DateTime.parse(json['ordered_at'] as String),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      notes: json['notes'] as String?,
      report: report,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'consultation_id': consultationId,
      'study_type': studyType,
      'body_part': bodyPart,
      'clinical_indication': clinicalIndication,
      'priority': _priorityToString(priority),
      'status': _statusToString(status),
      'ordered_at': orderedAt.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'notes': notes,
    };
  }

  static RadiologyPriority _priorityFromString(String s) {
    switch (s) {
      case 'urgent':
        return RadiologyPriority.urgent;
      case 'stat':
        return RadiologyPriority.stat;
      default:
        return RadiologyPriority.routine;
    }
  }

  static String _priorityToString(RadiologyPriority p) {
    switch (p) {
      case RadiologyPriority.urgent:
        return 'urgent';
      case RadiologyPriority.stat:
        return 'stat';
      case RadiologyPriority.routine:
        return 'routine';
    }
  }

  static RadiologyStatus _statusFromString(String s) {
    switch (s) {
      case 'scheduled':
        return RadiologyStatus.scheduled;
      case 'performed':
        return RadiologyStatus.performed;
      case 'reported':
        return RadiologyStatus.reported;
      case 'cancelled':
        return RadiologyStatus.cancelled;
      default:
        return RadiologyStatus.ordered;
    }
  }

  static String _statusToString(RadiologyStatus s) {
    switch (s) {
      case RadiologyStatus.scheduled:
        return 'scheduled';
      case RadiologyStatus.performed:
        return 'performed';
      case RadiologyStatus.reported:
        return 'reported';
      case RadiologyStatus.cancelled:
        return 'cancelled';
      case RadiologyStatus.ordered:
        return 'ordered';
    }
  }
}

class RadiologyReportModel {
  final String id;
  final String radiologyOrderId;
  final String? findings;
  final String? impression;
  final String? recommendations;
  final String? performedBy;
  final String? reportedBy;
  final DateTime? performedAt;
  final DateTime? reportedAt;

  RadiologyReportModel({
    required this.id,
    required this.radiologyOrderId,
    this.findings,
    this.impression,
    this.recommendations,
    this.performedBy,
    this.reportedBy,
    this.performedAt,
    this.reportedAt,
  });

  factory RadiologyReportModel.fromJson(Map<String, dynamic> json) {
    return RadiologyReportModel(
      id: json['id'] as String,
      radiologyOrderId: json['radiology_order_id'] as String,
      findings: json['findings'] as String?,
      impression: json['impression'] as String?,
      recommendations: json['recommendations'] as String?,
      performedBy: json['performed_by'] as String?,
      reportedBy: json['reported_by'] as String?,
      performedAt: json['performed_at'] != null
          ? DateTime.parse(json['performed_at'] as String)
          : null,
      reportedAt: json['reported_at'] != null
          ? DateTime.parse(json['reported_at'] as String)
          : null,
    );
  }
}
