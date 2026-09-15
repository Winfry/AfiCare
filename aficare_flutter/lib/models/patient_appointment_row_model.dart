/// A row on a facility_patient's Appointments sub-tab — an `appointments`
/// record joined client-side with the provider's display name. Not a
/// persisted table: see FacilityPatientProvider.loadPatientAppointments.
class PatientAppointmentRowModel {
  final String id;
  final DateTime scheduledAt;
  final String status;
  final String providerName;

  PatientAppointmentRowModel({
    required this.id,
    required this.scheduledAt,
    required this.status,
    required this.providerName,
  });

  factory PatientAppointmentRowModel.fromJson(Map<String, dynamic> json, {String? providerName}) {
    return PatientAppointmentRowModel(
      id: json['id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String? ?? 'pending',
      providerName: providerName ?? 'Unknown',
    );
  }
}
