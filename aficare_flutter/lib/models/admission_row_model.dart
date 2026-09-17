class AdmissionRowModel {
  final String admissionId;
  final String visitId;
  final String facilityPatientId;
  final String wardId;
  final String bedNumber;
  final DateTime admittedAt;
  final DateTime? dischargedAt;
  final String patientName;
  final String patientFileNumber;
  final String wardName;
  final String? attendingProviderName;
  final String? eligibilityStatus;

  AdmissionRowModel({
    required this.admissionId,
    required this.visitId,
    required this.facilityPatientId,
    required this.wardId,
    required this.bedNumber,
    required this.admittedAt,
    required this.dischargedAt,
    required this.patientName,
    required this.patientFileNumber,
    required this.wardName,
    required this.attendingProviderName,
    required this.eligibilityStatus,
  });

  bool get isDischarged => dischargedAt != null;

  factory AdmissionRowModel.fromJson(
    Map<String, dynamic> json, {
    required String patientName,
    required String patientFileNumber,
    required String wardName,
    String? attendingProviderName,
    String? eligibilityStatus,
  }) {
    return AdmissionRowModel(
      admissionId: json['id'] as String,
      visitId: json['visit_id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      wardId: json['ward_id'] as String,
      bedNumber: json['bed_number'] as String,
      admittedAt: DateTime.parse(json['admitted_at'] as String),
      dischargedAt: json['discharged_at'] == null
          ? null
          : DateTime.parse(json['discharged_at'] as String),
      patientName: patientName,
      patientFileNumber: patientFileNumber,
      wardName: wardName,
      attendingProviderName: attendingProviderName,
      eligibilityStatus: eligibilityStatus,
    );
  }
}
