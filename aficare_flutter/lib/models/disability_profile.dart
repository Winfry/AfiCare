// ================================================================
// AfiCare MediLink — Disability Profile Model
//
// Design principle:
//   Every field has a clear owner (patient / provider / both).
//   The rule engine reads this model directly.
//   When ML is added later, replace rule outputs — NOT this model.
// ================================================================

enum DisabilityType {
  visual,
  hearing,
  mobility,
  cognitive,
  speech,
  chronicIllness,
  mentalHealth,
  multiple;

  String get displayName => switch (this) {
        DisabilityType.visual        => 'Visual Impairment',
        DisabilityType.hearing       => 'Hearing Impairment',
        DisabilityType.mobility      => 'Mobility / Physical',
        DisabilityType.cognitive     => 'Cognitive / Intellectual',
        DisabilityType.speech        => 'Speech / Communication',
        DisabilityType.chronicIllness => 'Chronic Illness',
        DisabilityType.mentalHealth  => 'Mental Health',
        DisabilityType.multiple      => 'Multiple Disabilities',
      };

  String get description => switch (this) {
        DisabilityType.visual        => 'Blindness, low vision, color blindness',
        DisabilityType.hearing       => 'Deafness, hard of hearing',
        DisabilityType.mobility      => 'Wheelchair user, limited mobility, amputee',
        DisabilityType.cognitive     => 'Intellectual disability, dementia, autism',
        DisabilityType.speech        => 'Speech or communication impairment',
        DisabilityType.chronicIllness => 'Diabetes, HIV/AIDS, cancer, epilepsy',
        DisabilityType.mentalHealth  => 'Depression, anxiety, schizophrenia',
        DisabilityType.multiple      => 'Two or more disability types',
      };
}

enum DisabilitySeverity {
  mild,
  moderate,
  severe;

  String get displayName => switch (this) {
        DisabilitySeverity.mild     => 'Mild',
        DisabilitySeverity.moderate => 'Moderate',
        DisabilitySeverity.severe   => 'Severe',
      };

  String get description => switch (this) {
        DisabilitySeverity.mild =>
          'Minimal impact on daily activities',
        DisabilitySeverity.moderate =>
          'Some limitations; may need occasional assistance',
        DisabilitySeverity.severe =>
          'Significant limitations; requires regular support',
      };
}

/// Standard assistive devices — displayed as chips for patient to select.
const kAssistiveDevices = [
  'Wheelchair',
  'Walking frame / walker',
  'Crutches',
  'Hearing aid',
  'White cane',
  'Guide dog',
  'Prosthetic limb',
  'Communication device (AAC)',
  'Screen reader / magnifier software',
  'Catheter',
  'Feeding tube',
  'Oxygen support',
  'Epilepsy alert device',
];

/// Standard caregiver relationships
const kCaregiverRelationships = [
  'Parent',
  'Spouse / Partner',
  'Child',
  'Sibling',
  'Other family member',
  'Professional carer',
  'Community health worker',
  'Friend',
];

/// What the caregiver is allowed to see
const kCaregiverPermissions = [
  'Emergency contacts',
  'Current medications',
  'Known allergies',
  'Upcoming appointments',
  'Vital signs summary',
  'Medical history',
];

// ----------------------------------------------------------------
// Caregiver Designation
// ----------------------------------------------------------------

class CaregiverDesignation {
  /// Who the caregiver is
  final String name;
  final String phone;
  final String relationship;

  /// What they can access
  final List<String> permissions;

  /// Access code for caregiver login (6-char, time-limited)
  final String? accessCode;
  final DateTime? codeExpiry;

  final bool isActive;
  final DateTime designatedAt;

  const CaregiverDesignation({
    required this.name,
    required this.phone,
    required this.relationship,
    required this.permissions,
    required this.designatedAt,
    this.accessCode,
    this.codeExpiry,
    this.isActive = true,
  });

  bool get codeIsValid =>
      accessCode != null &&
      codeExpiry != null &&
      codeExpiry!.isAfter(DateTime.now());

  CaregiverDesignation copyWith({
    String?       name,
    String?       phone,
    String?       relationship,
    List<String>? permissions,
    String?       accessCode,
    DateTime?     codeExpiry,
    bool?         isActive,
  }) {
    return CaregiverDesignation(
      name:         name         ?? this.name,
      phone:        phone        ?? this.phone,
      relationship: relationship ?? this.relationship,
      permissions:  permissions  ?? this.permissions,
      accessCode:   accessCode   ?? this.accessCode,
      codeExpiry:   codeExpiry   ?? this.codeExpiry,
      isActive:     isActive     ?? this.isActive,
      designatedAt: designatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name':         name,
        'phone':        phone,
        'relationship': relationship,
        'permissions':  permissions,
        'access_code':  accessCode,
        'code_expiry':  codeExpiry?.toIso8601String(),
        'is_active':    isActive,
        'designated_at': designatedAt.toIso8601String(),
      };

  factory CaregiverDesignation.fromMap(Map<String, dynamic> map) =>
      CaregiverDesignation(
        name:         map['name']         as String,
        phone:        map['phone']        as String,
        relationship: map['relationship'] as String,
        permissions:  List<String>.from(map['permissions'] as List),
        accessCode:   map['access_code']  as String?,
        codeExpiry:   map['code_expiry'] != null
            ? DateTime.parse(map['code_expiry'] as String)
            : null,
        isActive:     map['is_active']    as bool? ?? true,
        designatedAt: DateTime.parse(map['designated_at'] as String),
      );
}

// ----------------------------------------------------------------
// Disability Profile (core model)
// ----------------------------------------------------------------

class DisabilityProfile {
  final String patientId;

  // ---- Fields patient fills (self-reported) ----
  final List<DisabilityType> disabilityTypes;
  final DisabilitySeverity severity;

  /// Did they have this from birth?
  final bool isCongenital;

  /// Approximate year/date of onset (if acquired)
  final DateTime? onsetDate;

  /// Assistive devices they currently use
  final List<String> assistiveDevices;

  // ---- Fields provider fills (clinical) ----

  /// Clinical/medical name, e.g. "Spastic Diplegia Cerebral Palsy"
  final String? clinicalDiagnosis;

  /// Free-form provider notes for other clinicians to read
  final String? providerNotes;

  /// Provider assessed that a caregiver must be present for decisions
  final bool requiresCaregiverForConsent;

  /// Specialist referrals the provider has recommended
  final List<String> specialistReferrals;

  // ---- Caregiver ----
  final CaregiverDesignation? caregiver;

  // ---- Metadata ----
  final DateTime lastUpdated;

  /// 'patient' | provider UUID
  final String updatedBy;

  const DisabilityProfile({
    required this.patientId,
    required this.disabilityTypes,
    required this.severity,
    required this.assistiveDevices,
    required this.lastUpdated,
    required this.updatedBy,
    this.isCongenital          = false,
    this.onsetDate,
    this.clinicalDiagnosis,
    this.providerNotes,
    this.requiresCaregiverForConsent = false,
    this.specialistReferrals   = const [],
    this.caregiver,
  });

  // ---- Convenience getters ----

  bool get isEmpty   => disabilityTypes.isEmpty;
  bool get hasCaregiver =>
      caregiver != null && caregiver!.isActive;

  // ---- Mutation ----

  DisabilityProfile copyWith({
    List<DisabilityType>? disabilityTypes,
    DisabilitySeverity?   severity,
    bool?                 isCongenital,
    DateTime?             onsetDate,
    List<String>?         assistiveDevices,
    String?               clinicalDiagnosis,
    String?               providerNotes,
    bool?                 requiresCaregiverForConsent,
    List<String>?         specialistReferrals,
    CaregiverDesignation? caregiver,
    DateTime?             lastUpdated,
    String?               updatedBy,
  }) {
    return DisabilityProfile(
      patientId:                    patientId,
      disabilityTypes:              disabilityTypes  ?? this.disabilityTypes,
      severity:                     severity         ?? this.severity,
      isCongenital:                 isCongenital     ?? this.isCongenital,
      onsetDate:                    onsetDate        ?? this.onsetDate,
      assistiveDevices:             assistiveDevices ?? this.assistiveDevices,
      clinicalDiagnosis:            clinicalDiagnosis ?? this.clinicalDiagnosis,
      providerNotes:                providerNotes    ?? this.providerNotes,
      requiresCaregiverForConsent:  requiresCaregiverForConsent
                                        ?? this.requiresCaregiverForConsent,
      specialistReferrals:          specialistReferrals ?? this.specialistReferrals,
      caregiver:                    caregiver        ?? this.caregiver,
      lastUpdated:                  lastUpdated      ?? this.lastUpdated,
      updatedBy:                    updatedBy        ?? this.updatedBy,
    );
  }

  // ---- Serialization (ready for Supabase) ----

  Map<String, dynamic> toMap() => {
        'patient_id':          patientId,
        'disability_types':    disabilityTypes.map((e) => e.name).toList(),
        'severity':            severity.name,
        'is_congenital':       isCongenital,
        'onset_date':          onsetDate?.toIso8601String(),
        'assistive_devices':   assistiveDevices,
        'clinical_diagnosis':  clinicalDiagnosis,
        'provider_notes':      providerNotes,
        'requires_caregiver_for_consent': requiresCaregiverForConsent,
        'specialist_referrals': specialistReferrals,
        'caregiver':           caregiver?.toMap(),
        'last_updated':        lastUpdated.toIso8601String(),
        'updated_by':          updatedBy,
      };

  factory DisabilityProfile.fromMap(Map<String, dynamic> map) =>
      DisabilityProfile(
        patientId: map['patient_id'] as String,
        disabilityTypes: (map['disability_types'] as List)
            .map((e) => DisabilityType.values.byName(e as String))
            .toList(),
        severity: DisabilitySeverity.values
            .byName(map['severity'] as String),
        isCongenital: map['is_congenital'] as bool? ?? false,
        onsetDate:    map['onset_date'] != null
            ? DateTime.parse(map['onset_date'] as String)
            : null,
        assistiveDevices: List<String>.from(
            map['assistive_devices'] as List? ?? []),
        clinicalDiagnosis: map['clinical_diagnosis'] as String?,
        providerNotes:     map['provider_notes']     as String?,
        requiresCaregiverForConsent:
            map['requires_caregiver_for_consent'] as bool? ?? false,
        specialistReferrals: List<String>.from(
            map['specialist_referrals'] as List? ?? []),
        caregiver: map['caregiver'] != null
            ? CaregiverDesignation.fromMap(
                map['caregiver'] as Map<String, dynamic>)
            : null,
        lastUpdated: DateTime.parse(map['last_updated'] as String),
        updatedBy:   map['updated_by'] as String,
      );

  /// Blank profile for a new patient
  factory DisabilityProfile.empty(String patientId) => DisabilityProfile(
        patientId:       patientId,
        disabilityTypes: [],
        severity:        DisabilitySeverity.mild,
        assistiveDevices: [],
        lastUpdated:     DateTime.now(),
        updatedBy:       'patient',
      );
}
