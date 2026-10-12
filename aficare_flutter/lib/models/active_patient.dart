import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/dependent_provider.dart';
import '../providers/patient_profile_provider.dart';
import 'dependent_profile_model.dart';
import 'patient_profile_model.dart';

/// Who the patient app is currently showing, and what is actually known
/// about them.
///
/// This exists because the account holder and a dependant are stored in
/// two different tables with two different shapes:
///
/// * the account holder lives in `patients` ([PatientProfileModel]) and
///   has allergies, chronic conditions and an emergency contact;
/// * a dependant lives in `dependent_profiles`
///   ([DependentProfileModel]) and has none of those columns.
///
/// Before this, screens read the account holder's profile regardless of
/// who was selected, so switching to a child showed the child's visits
/// beside the *guardian's* allergies. A record that silently blends two
/// people is more dangerous than a stale one, so resolving "whose record
/// is this" now happens in exactly one place.
///
/// [allergies] is deliberately nullable, and the distinction matters:
/// an empty list means "we know of none", while null means "we could not
/// find out" — the record failed to load. Screens must render those two
/// states differently and must never show null as "none".
///
/// Both profile types can now hold allergies (migration 008 added the
/// column to `dependent_profiles`); before that, a dependant's allergies
/// were nowhere, and the guardian's were shown in their place.
@immutable
class ActivePatient {
  const ActivePatient({
    required this.id,
    required this.fullName,
    required this.isDependent,
    this.relationship,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.allergies,
    this.medilinkId,
  });

  final String id;
  final String fullName;
  final bool isDependent;

  /// How a dependant relates to the account holder ("child", "parent").
  /// Null for the account holder themselves.
  final String? relationship;

  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodType;

  /// Null when allergies cannot be known for this profile — never treat
  /// null as "no allergies".
  final List<String>? allergies;

  final String? medilinkId;

  /// Every profile can hold allergies since migration 008. Kept as a
  /// named concept so screens read by intent rather than by profile type.
  bool get canRecordAllergies => true;

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Resolves the active profile from the three providers that together
  /// hold the answer. Pass [listen] false inside callbacks and loads.
  static ActivePatient of(BuildContext context, {bool listen = true}) {
    final dep = listen
        ? context.watch<DependentProvider>()
        : context.read<DependentProvider>();
    final auth = listen
        ? context.watch<AuthProvider>()
        : context.read<AuthProvider>();

    final dependent = dep.activeDependent;
    if (dep.isViewingDependent && dependent != null) {
      return ActivePatient.fromDependent(dependent);
    }

    final profile = listen
        ? context.watch<PatientProfileProvider>().profile
        : context.read<PatientProfileProvider>().profile;

    return ActivePatient.fromAccountHolder(
      id: auth.currentUser?.id ?? '',
      fullName: auth.currentUser?.fullName ?? '',
      medilinkId: auth.currentUser?.medilinkId,
      profile: profile,
    );
  }

  factory ActivePatient.fromDependent(DependentProfileModel d) => ActivePatient(
        id: d.id,
        fullName: d.fullName,
        isDependent: true,
        relationship: d.relationship,
        dateOfBirth: d.dateOfBirth,
        gender: d.gender,
        bloodType: d.bloodType,
        allergies: d.allergies,
        medilinkId: d.medilinkId,
      );

  factory ActivePatient.fromAccountHolder({
    required String id,
    required String fullName,
    String? medilinkId,
    PatientProfileModel? profile,
  }) =>
      ActivePatient(
        id: id,
        fullName: fullName,
        isDependent: false,
        dateOfBirth: profile?.dateOfBirth,
        gender: profile?.gender,
        bloodType: profile?.bloodType,
        // A null profile means it never loaded — unknown, not none.
        allergies: profile == null ? null : profile.allergies,
        medilinkId: medilinkId,
      );
}
