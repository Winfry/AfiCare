enum LabPriority { routine, urgent, stat }

enum LabOrderStatus { ordered, collected, processing, completed, cancelled }

enum LabResultFlag { normal, abnormal, critical }

/// Represents a lab order together with its (optional) result.
/// Backed by the `lab_orders` table joined to `lab_results`.
class LabOrderModel {
  final String id;
  final String patientId;
  final String providerId;
  final String? consultationId;
  final String testName;
  final String testCategory;
  final LabPriority priority;
  final LabOrderStatus status;
  final DateTime orderedAt;
  final String? notes;

  // Optional embedded result
  final LabResultModel? result;

  LabOrderModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.consultationId,
    required this.testName,
    this.testCategory = 'other',
    this.priority = LabPriority.routine,
    this.status = LabOrderStatus.ordered,
    required this.orderedAt,
    this.notes,
    this.result,
  });

  bool get isCompleted => status == LabOrderStatus.completed;
  bool get isPending =>
      status == LabOrderStatus.ordered ||
      status == LabOrderStatus.collected ||
      status == LabOrderStatus.processing;
  bool get isCritical => result?.flag == LabResultFlag.critical;

  factory LabOrderModel.fromJson(Map<String, dynamic> json) {
    // Supabase embedded select may return lab_results as a list.
    LabResultModel? result;
    final rawResults = json['lab_results'];
    if (rawResults is List && rawResults.isNotEmpty) {
      result = LabResultModel.fromJson(rawResults.first as Map<String, dynamic>);
    } else if (rawResults is Map<String, dynamic>) {
      result = LabResultModel.fromJson(rawResults);
    } else if (json['result'] is Map<String, dynamic>) {
      result = LabResultModel.fromJson(json['result'] as Map<String, dynamic>);
    }

    return LabOrderModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      consultationId: json['consultation_id'] as String?,
      testName: json['test_name'] as String,
      testCategory: json['test_category'] as String? ?? 'other',
      priority: _priorityFromString(json['priority'] as String? ?? 'routine'),
      status: _statusFromString(json['status'] as String? ?? 'ordered'),
      orderedAt: DateTime.parse(json['ordered_at'] as String),
      notes: json['notes'] as String?,
      result: result,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'consultation_id': consultationId,
      'test_name': testName,
      'test_category': testCategory,
      'priority': _priorityToString(priority),
      'status': _statusToString(status),
      'ordered_at': orderedAt.toIso8601String(),
      'notes': notes,
    };
  }

  static LabPriority _priorityFromString(String s) {
    switch (s) {
      case 'urgent':
        return LabPriority.urgent;
      case 'stat':
        return LabPriority.stat;
      default:
        return LabPriority.routine;
    }
  }

  static String _priorityToString(LabPriority p) {
    switch (p) {
      case LabPriority.urgent:
        return 'urgent';
      case LabPriority.stat:
        return 'stat';
      case LabPriority.routine:
        return 'routine';
    }
  }

  static LabOrderStatus _statusFromString(String s) {
    switch (s) {
      case 'collected':
        return LabOrderStatus.collected;
      case 'processing':
        return LabOrderStatus.processing;
      case 'completed':
        return LabOrderStatus.completed;
      case 'cancelled':
        return LabOrderStatus.cancelled;
      default:
        return LabOrderStatus.ordered;
    }
  }

  static String _statusToString(LabOrderStatus s) {
    switch (s) {
      case LabOrderStatus.collected:
        return 'collected';
      case LabOrderStatus.processing:
        return 'processing';
      case LabOrderStatus.completed:
        return 'completed';
      case LabOrderStatus.cancelled:
        return 'cancelled';
      case LabOrderStatus.ordered:
        return 'ordered';
    }
  }
}

class LabResultModel {
  final String id;
  final String labOrderId;
  final String? resultValue;
  final String? resultUnit;
  final String? referenceRangeLow;
  final String? referenceRangeHigh;
  final LabResultFlag flag;
  final String? performedBy;
  final DateTime? resultedAt;
  final String? notes;

  LabResultModel({
    required this.id,
    required this.labOrderId,
    this.resultValue,
    this.resultUnit,
    this.referenceRangeLow,
    this.referenceRangeHigh,
    this.flag = LabResultFlag.normal,
    this.performedBy,
    this.resultedAt,
    this.notes,
  });

  String get referenceRange {
    if (referenceRangeLow != null && referenceRangeHigh != null) {
      return '$referenceRangeLow – $referenceRangeHigh';
    }
    return referenceRangeLow ?? referenceRangeHigh ?? '—';
  }

  factory LabResultModel.fromJson(Map<String, dynamic> json) {
    return LabResultModel(
      id: json['id'] as String,
      labOrderId: json['lab_order_id'] as String,
      resultValue: json['result_value'] as String?,
      resultUnit: json['result_unit'] as String?,
      referenceRangeLow: json['reference_range_low'] as String?,
      referenceRangeHigh: json['reference_range_high'] as String?,
      flag: _flagFromString(json['result_flag'] as String? ?? 'normal'),
      performedBy: json['performed_by'] as String?,
      resultedAt: json['resulted_at'] != null
          ? DateTime.parse(json['resulted_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  static LabResultFlag _flagFromString(String s) {
    switch (s) {
      case 'abnormal':
        return LabResultFlag.abnormal;
      case 'critical':
        return LabResultFlag.critical;
      default:
        return LabResultFlag.normal;
    }
  }
}
