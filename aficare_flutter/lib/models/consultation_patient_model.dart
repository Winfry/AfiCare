import 'package:supabase_flutter/supabase_flutter.dart';

/// The patient a consultation is for, confirmed before anything is saved.
///
/// consultations, prescriptions and appointments store the patient's
/// account id (a UUID), while doctors know patients by MediLink ID
/// (ML-NBO-123456). Saving the MediLink ID itself failed every time, and
/// took the consultation's prescriptions and follow-up with it.
class ConsultationPatient {
  const ConsultationPatient({
    required this.id,
    required this.name,
    this.medilinkId,
    this.gender,
    this.dateOfBirth,
  });

  /// The account id: what gets saved.
  final String id;
  final String name;
  final String? medilinkId;

  /// 'male', 'female' or 'other', when known.
  final String? gender;
  final DateTime? dateOfBirth;

  /// Completed years on [today], when the date of birth is known.
  int? ageOn(DateTime today) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
    return age < 0 ? null : age;
  }

  /// "Mary Wanjiru · ML-NBO-123456"
  String get label => medilinkId == null ? name : '$name · $medilinkId';

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Why [input] can't be looked up as it stands, or null when it can.
  static String? problemWith(String input) {
    final id = input.trim().toUpperCase();
    if (id.isEmpty) return "Enter the patient's MediLink ID.";
    if (id.startsWith('ML-DEP-')) {
      return "That is a dependant's MediLink ID (a child, or someone without their own account). "
          "Consultations for dependants aren't available yet.";
    }
    return null;
  }

  /// Finds the patient with MediLink ID [input], or with account id
  /// [input] when coming from their record. Returns the patient, or a
  /// reason in plain words why there isn't one.
  static Future<(ConsultationPatient?, String?)> find(SupabaseClient client, String input) async {
    final problem = problemWith(input);
    if (problem != null) return (null, problem);
    final raw = input.trim();
    final byAccountId = _uuid.hasMatch(raw);

    try {
      final user = await client
          .from('users')
          .select('id, full_name, medilink_id, gender')
          .eq(byAccountId ? 'id' : 'medilink_id', byAccountId ? raw : raw.toUpperCase())
          .eq('role', 'patient')
          .maybeSingle();
      if (user == null) {
        return (null, 'No patient has the MediLink ID ${raw.toUpperCase()}. Please check it and try again.');
      }

      // Only readable when this doctor already cares for the patient
      // (043); without it the age is simply left for the doctor to enter.
      DateTime? dob;
      try {
        final patient = await client
            .from('patients')
            .select('date_of_birth')
            .eq('id', user['id'] as String)
            .maybeSingle();
        final v = patient?['date_of_birth'];
        dob = v is String ? DateTime.tryParse(v) : null;
      } catch (_) {}

      return (
        ConsultationPatient(
          id: user['id'] as String,
          name: (user['full_name'] as String?)?.trim().isNotEmpty == true ? user['full_name'] as String : 'Patient',
          medilinkId: user['medilink_id'] as String?,
          gender: user['gender'] as String?,
          dateOfBirth: dob,
        ),
        null,
      );
    } catch (_) {
      return (null, "We couldn't look that patient up. Please check your connection and try again.");
    }
  }
}
