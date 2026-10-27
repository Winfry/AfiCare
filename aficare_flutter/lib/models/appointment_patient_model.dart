import 'package:supabase_flutter/supabase_flutter.dart';

/// Who an appointment is for, as the doctor, the facility's admin or the
/// patient/guardian is allowed to know it: an account holder, or a
/// dependant together with their guardian.
///
/// Comes from `appointment_patient_names()` (migration 040). Providers
/// can't read dependant profiles directly, and an appointment's
/// patient_id may be a dependant's, so neither a `users` lookup nor a
/// `users(...)` embed can name the patient.
class AppointmentPatient {
  const AppointmentPatient({
    required this.appointmentId,
    required this.name,
    this.isDependant = false,
    this.guardianName,
    this.relationship,
  });

  final String appointmentId;
  final String name;
  final bool isDependant;
  final String? guardianName;

  /// The dependant's relationship to their guardian: child, grandchild,
  /// sibling or other.
  final String? relationship;

  factory AppointmentPatient.fromJson(Map<String, dynamic> json) {
    return AppointmentPatient(
      appointmentId: json['appointment_id'] as String,
      name: (json['patient_name'] as String?)?.trim().isNotEmpty == true
          ? (json['patient_name'] as String).trim()
          : 'Patient',
      isDependant: json['is_dependant'] as bool? ?? false,
      guardianName: json['guardian_name'] as String?,
      relationship: json['relationship'] as String?,
    );
  }

  /// "Brian Wanjiru · Mary Wanjiru's child", or just the name for an
  /// account holder.
  String get label {
    final guardian = guardianName?.trim();
    if (!isDependant || guardian == null || guardian.isEmpty) return name;
    final rel = switch (relationship) {
      'child' || 'grandchild' || 'sibling' => relationship,
      _ => null,
    };
    return rel == null ? '$name · cared for by $guardian' : "$name · $guardian's $rel";
  }

  /// Looks up who each of [appointmentIds] is for, keyed by appointment
  /// id. Appointments the caller may not see are simply missing.
  static Future<Map<String, AppointmentPatient>> fetch(
    SupabaseClient client,
    Iterable<String> appointmentIds,
  ) async {
    final ids = appointmentIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await client.rpc('appointment_patient_names', params: {'p_appointment_ids': ids});
    return {
      for (final r in rows as List)
        (r as Map)['appointment_id'] as String: AppointmentPatient.fromJson(Map<String, dynamic>.from(r)),
    };
  }
}
