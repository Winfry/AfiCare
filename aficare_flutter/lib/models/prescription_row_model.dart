/// A row on the Pharmacy & Stock "Prescriptions" board — a
/// `visit_prescriptions` record joined client-side with the patient's
/// display name/file number and the prescribing provider's name. Not a
/// persisted table shape by itself: see 025_pharmacy_stock.sql and
/// FacilityPatientProvider.loadPrescriptions.
class PrescriptionRowModel {
  final String prescriptionId;
  final String visitId;
  final String facilityPatientId;
  final String drugStockId;
  final String medicationLabel;
  final String status;
  final DateTime prescribedAt;
  final DateTime statusChangedAt;
  final String patientName;
  final String? patientFileNumber;
  final String prescribedByName;

  PrescriptionRowModel({
    required this.prescriptionId,
    required this.visitId,
    required this.facilityPatientId,
    required this.drugStockId,
    required this.medicationLabel,
    required this.status,
    required this.prescribedAt,
    required this.statusChangedAt,
    required this.patientName,
    this.patientFileNumber,
    required this.prescribedByName,
  });

  factory PrescriptionRowModel.fromJson(Map<String, dynamic> json, {String? patientName, String? patientFileNumber, String? prescribedByName}) {
    return PrescriptionRowModel(
      prescriptionId: json['id'] as String,
      visitId: json['visit_id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      drugStockId: json['drug_stock_id'] as String,
      medicationLabel: json['medication_label'] as String,
      status: json['status'] as String? ?? 'pending',
      prescribedAt: DateTime.parse(json['prescribed_at'] as String),
      statusChangedAt: DateTime.parse(json['status_changed_at'] as String),
      patientName: patientName ?? 'Unknown',
      patientFileNumber: patientFileNumber,
      prescribedByName: prescribedByName ?? 'Unassigned',
    );
  }
}
