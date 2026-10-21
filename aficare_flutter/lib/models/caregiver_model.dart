// Caregiver access: a patient with their own account lets someone they
// trust follow part of their care, read-only, until they stop it.
//
// Not the same as a dependant (see dependent_profile_model.dart), whose
// profile the guardian owns because the person has no account. Codes are
// made and checked in the database (migration 036), never in the app.

/// Where a code is in its life, from the patient's side.
enum CaregiverGrantStatus {
  /// Made but not yet entered; can still be used.
  waiting,

  /// Entered by the caregiver, who can now see the shared sections.
  active,

  /// Never entered within its 48 hours.
  expired,

  /// Stopped by the patient.
  stopped,
}

/// One code the patient has made, as returned by `my_caregiver_grants()`.
class CaregiverAccess {
  final String id;
  final String accessCode;
  final String accessLevel; // 'full', 'medical_only', 'appointments_only', 'emergency_only'

  /// Who the caregiver is to the patient (see [CaregiverRelationship]).
  /// Null for codes made before migration 037.
  final String? relationship;
  final bool isActive;
  final DateTime grantedAt;
  final DateTime? codeExpiresAt;
  final DateTime? redeemedAt;

  /// The caregiver's name once they have entered the code.
  final String? caregiverName;

  /// The last time the caregiver opened the shared record.
  final DateTime? lastViewedAt;

  CaregiverAccess({
    required this.id,
    required this.accessCode,
    required this.accessLevel,
    this.relationship,
    this.isActive = true,
    required this.grantedAt,
    this.codeExpiresAt,
    this.redeemedAt,
    this.caregiverName,
    this.lastViewedAt,
  });

  factory CaregiverAccess.fromJson(Map<String, dynamic> json) {
    return CaregiverAccess(
      id: json['id'] as String? ?? '',
      accessCode: json['access_code'] as String? ?? '',
      accessLevel: json['access_level'] as String? ?? 'full',
      relationship: json['relationship'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      grantedAt: _date(json['granted_at']) ?? DateTime.now(),
      codeExpiresAt: _date(json['code_expires_at']),
      redeemedAt: _date(json['redeemed_at']),
      caregiverName: json['caregiver_name'] as String?,
      lastViewedAt: _date(json['last_viewed_at']),
    );
  }

  CaregiverGrantStatus statusAt(DateTime now) {
    if (!isActive) return CaregiverGrantStatus.stopped;
    if (redeemedAt != null) return CaregiverGrantStatus.active;
    if (codeExpiresAt == null || !codeExpiresAt!.isAfter(now)) return CaregiverGrantStatus.expired;
    return CaregiverGrantStatus.waiting;
  }

  /// Still something the patient may want to stop: a live code or a
  /// caregiver who can see the record.
  bool isLiveAt(DateTime now) {
    final s = statusAt(now);
    return s == CaregiverGrantStatus.waiting || s == CaregiverGrantStatus.active;
  }

  static String accessLevelLabel(String level) {
    switch (level) {
      case 'full': return 'Everything shared';
      case 'medical_only': return 'Health only';
      case 'appointments_only': return 'Appointments only';
      case 'emergency_only': return 'Emergency details only';
      default: return level;
    }
  }

  /// What each level lets the caregiver see, in plain words. Matches
  /// `caregiver_view()` in migration 036.
  static String accessLevelScope(String level) {
    switch (level) {
      case 'full': return 'Appointments, medicines, lab results and emergency details';
      case 'medical_only': return 'Medicines, lab results and emergency details';
      case 'appointments_only': return 'Upcoming and recent appointments';
      case 'emergency_only': return 'Blood type, allergies, conditions and emergency contacts';
      default: return accessLevelLabel(level);
    }
  }

  /// `ABCD2345` → `ABCD-2345`, easier to read aloud or copy by hand.
  static String formatCode(String code) {
    final c = normaliseCode(code);
    return c.length == 8 ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
  }

  /// What the person typed, as the database stores it: capitals, with
  /// spaces and dashes taken out.
  static String normaliseCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Someone who has shared their record with the signed-in user, as
/// returned by `people_i_care_for()`.
class CaregiverLink {
  final String accessId;
  final String patientName;
  final String? medilinkId;
  final String accessLevel;

  /// Who the signed-in caregiver is to this patient, as the patient put it.
  final String? relationship;
  final DateTime? since;

  const CaregiverLink({
    required this.accessId,
    required this.patientName,
    this.medilinkId,
    required this.accessLevel,
    this.relationship,
    this.since,
  });

  factory CaregiverLink.fromJson(Map<String, dynamic> json) {
    final name = (json['patient_name'] as String?)?.trim() ?? '';
    return CaregiverLink(
      accessId: json['access_id'] as String? ?? '',
      patientName: name.isEmpty ? 'AfiCare patient' : name,
      medilinkId: json['medilink_id'] as String?,
      accessLevel: json['access_level'] as String? ?? 'full',
      relationship: json['relationship'] as String?,
      since: _date(json['redeemed_at']),
    );
  }
}

/// Who a caregiver is to the patient. The patient picks one when making a
/// code (migration 037). It is only a label: it never changes what the
/// caregiver can see, and it gives no right to decide for the patient.
abstract final class CaregiverRelationship {
  /// In the order the patient is offered them. Matches the check on
  /// caregiver_access.relationship.
  static const values = [
    'spouse', 'parent', 'child', 'sibling', 'relative', 'friend', 'paid_carer', 'nurse', 'other',
  ];

  /// As the patient sees it: "Wanjiru · Child". Null when not recorded.
  static String? label(String? value) => switch (value) {
        'spouse' => 'Spouse or partner',
        'parent' => 'Parent',
        'child' => 'Child',
        'sibling' => 'Brother or sister',
        'relative' => 'Other relative',
        'friend' => 'Friend',
        'paid_carer' => 'Paid carer',
        'nurse' => 'Nurse',
        'other' => 'Someone else',
        _ => null,
      };

  /// As the caregiver sees it: "you're their child". Null when not
  /// recorded, or when "someone else" says nothing worth repeating.
  static String? asTheir(String? value) => switch (value) {
        'spouse' => "you're their spouse or partner",
        'parent' => "you're their parent",
        'child' => "you're their child",
        'sibling' => "you're their brother or sister",
        'relative' => "you're their relative",
        'friend' => "you're their friend",
        'paid_carer' => "you're their paid carer",
        'nurse' => "you're their nurse",
        _ => null,
      };
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
