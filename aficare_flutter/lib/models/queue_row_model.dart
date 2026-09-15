/// A row on the OPD Queue board — a `visits` record (visitId ->
/// facility_patient_id) joined client-side with the patient's display
/// name/file number. Not a persisted table: see 021_opd_queue.sql and
/// FacilityPatientProvider.loadActiveVisits.
class QueueRowModel {
  final String visitId;
  final String facilityPatientId;
  final String status;
  final String priority;
  final String? chiefComplaint;
  final DateTime statusChangedAt;
  final String patientName;
  final String? patientFileNumber;

  QueueRowModel({
    required this.visitId,
    required this.facilityPatientId,
    required this.status,
    required this.priority,
    this.chiefComplaint,
    required this.statusChangedAt,
    required this.patientName,
    this.patientFileNumber,
  });

  factory QueueRowModel.fromVisitJson(Map<String, dynamic> json, {String? patientName, String? patientFileNumber}) {
    return QueueRowModel(
      visitId: json['id'] as String,
      facilityPatientId: json['facility_patient_id'] as String,
      status: json['status'] as String? ?? 'waiting',
      priority: json['priority'] as String? ?? 'routine',
      chiefComplaint: json['chief_complaint'] as String?,
      statusChangedAt: DateTime.parse(json['status_changed_at'] as String),
      patientName: patientName ?? 'Unknown',
      patientFileNumber: patientFileNumber,
    );
  }
}
