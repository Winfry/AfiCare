/// A row on the Billing & Clearance ledger — a `visits` record joined
/// client-side with the patient's display name/file number. Not a
/// persisted table: see 022_billing_clearance.sql and
/// FacilityPatientProvider.loadClearanceVisits.
class ClearanceRowModel {
  final String visitId;
  final String facilityPatientId;
  final String visitStatus;
  final String? payerType;
  final String eligibilityStatus;
  final DateTime occurredAt;
  final String patientName;
  final String? patientFileNumber;

  ClearanceRowModel({
    required this.visitId,
    required this.facilityPatientId,
    required this.visitStatus,
    this.payerType,
    required this.eligibilityStatus,
    required this.occurredAt,
    required this.patientName,
    this.patientFileNumber,
  });

  factory ClearanceRowModel.fromVisitJson(Map<String, dynamic> json, {String? patientName, String? patientFileNumber}) {
    return ClearanceRowModel(
      visitId: json['id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      visitStatus: json['status'] as String? ?? 'registered',
      payerType: json['payer_type'] as String?,
      eligibilityStatus: json['eligibility_status'] as String? ?? 'pending',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      patientName: patientName ?? 'Unknown',
      patientFileNumber: patientFileNumber,
    );
  }
}
