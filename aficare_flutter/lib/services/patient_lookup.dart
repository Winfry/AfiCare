import 'package:supabase_flutter/supabase_flutter.dart';

/// A patient found by her exact MediLink ID.
class FoundPatient {
  const FoundPatient({required this.id, required this.fullName, required this.medilinkId});

  final String id;
  final String fullName;
  final String medilinkId;
}

/// How staff open a patient who isn't (yet) in their care: by her exact
/// MediLink ID, through `find_patient_by_medilink()` (migration 056).
///
/// Staff can read a patient's account only when she is in their care
/// (care team, appointment, consultation) or registered at a facility
/// they run. An exact-ID lookup is logged and opens her record to that
/// person for 7 days. It never returns her phone or email.
class PatientLookup {
  PatientLookup._();

  /// Whether [text] looks like a MediLink ID ("ML-NBO-AB1234",
  /// "ML-DEP-..."), so a search box can try an exact lookup.
  static bool looksLikeMedilinkId(String text) =>
      RegExp(r'^ML-[A-Z]{2,4}-[A-Z0-9]{4,}$', caseSensitive: false).hasMatch(text.trim());

  /// The patient with exactly this MediLink ID, or null when there is none.
  /// Throws when the lookup itself failed (offline, not allowed).
  static Future<FoundPatient?> byMedilinkId(String medilinkId) async {
    final rows = await Supabase.instance.client
        .rpc('find_patient_by_medilink', params: {'p_medilink': medilinkId.trim()});
    final list = rows is List ? rows : const [];
    if (list.isEmpty) return null;
    final r = Map<String, dynamic>.from(list.first as Map);
    return FoundPatient(
      id: r['id'] as String,
      fullName: (r['full_name'] as String?) ?? 'Patient',
      medilinkId: (r['medilink_id'] as String?) ?? medilinkId.trim(),
    );
  }
}
