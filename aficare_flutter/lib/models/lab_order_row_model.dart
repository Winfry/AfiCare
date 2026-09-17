/// A row on the Laboratory board — a `visit_lab_orders` record joined
/// client-side with the patient's display name/file number and the
/// ordering provider's name. Not a persisted table shape by itself: see
/// 024_visit_lab_orders.sql and FacilityPatientProvider.loadLabOrders.
class LabOrderRowModel {
  final String labOrderId;
  final String visitId;
  final String facilityPatientId;
  final String testName;
  final String status;
  final DateTime orderedAt;
  final DateTime statusChangedAt;
  final String patientName;
  final String? patientFileNumber;
  final String orderedByName;

  LabOrderRowModel({
    required this.labOrderId,
    required this.visitId,
    required this.facilityPatientId,
    required this.testName,
    required this.status,
    required this.orderedAt,
    required this.statusChangedAt,
    required this.patientName,
    this.patientFileNumber,
    required this.orderedByName,
  });

  factory LabOrderRowModel.fromJson(Map<String, dynamic> json, {String? patientName, String? patientFileNumber, String? orderedByName}) {
    return LabOrderRowModel(
      labOrderId: json['id'] as String,
      visitId: json['visit_id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      testName: json['test_name'] as String,
      status: json['status'] as String? ?? 'pending',
      orderedAt: DateTime.parse(json['ordered_at'] as String),
      statusChangedAt: DateTime.parse(json['status_changed_at'] as String),
      patientName: patientName ?? 'Unknown',
      patientFileNumber: patientFileNumber,
      orderedByName: orderedByName ?? 'Unassigned',
    );
  }
}
