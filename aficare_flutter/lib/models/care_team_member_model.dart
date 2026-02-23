class CareTeamMemberModel {
  final String id;
  final String patientId;
  final String providerId;
  final String? specialtyLabel;
  final String? notes;
  final bool isPrimary;
  final DateTime createdAt;
  // Denormalized from join with users table
  final String providerName;
  final String providerRole;
  final String? providerDepartment;

  const CareTeamMemberModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.specialtyLabel,
    this.notes,
    required this.isPrimary,
    required this.createdAt,
    required this.providerName,
    required this.providerRole,
    this.providerDepartment,
  });

  factory CareTeamMemberModel.fromJson(Map<String, dynamic> json) {
    return CareTeamMemberModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      specialtyLabel: json['specialty_label'] as String?,
      notes: json['notes'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      providerName: json['provider_name'] as String? ?? 'Unknown Provider',
      providerRole: json['provider_role'] as String? ?? 'doctor',
      providerDepartment: json['provider_department'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'specialty_label': specialtyLabel,
      'notes': notes,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
      'provider_name': providerName,
      'provider_role': providerRole,
      'provider_department': providerDepartment,
    };
  }

  CareTeamMemberModel copyWith({
    String? id,
    String? patientId,
    String? providerId,
    String? specialtyLabel,
    String? notes,
    bool? isPrimary,
    DateTime? createdAt,
    String? providerName,
    String? providerRole,
    String? providerDepartment,
  }) {
    return CareTeamMemberModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      specialtyLabel: specialtyLabel ?? this.specialtyLabel,
      notes: notes ?? this.notes,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      providerName: providerName ?? this.providerName,
      providerRole: providerRole ?? this.providerRole,
      providerDepartment: providerDepartment ?? this.providerDepartment,
    );
  }
}
