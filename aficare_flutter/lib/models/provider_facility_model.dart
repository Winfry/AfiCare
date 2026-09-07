class ProviderFacilityModel {
  final String providerId;
  final String facilityId;
  final String? specialty;
  final bool isPrimary;
  final DateTime createdAt;
  // Denormalized from a join with users/facilities.
  final String? providerName;
  final String? facilityName;

  const ProviderFacilityModel({
    required this.providerId,
    required this.facilityId,
    this.specialty,
    required this.isPrimary,
    required this.createdAt,
    this.providerName,
    this.facilityName,
  });

  factory ProviderFacilityModel.fromJson(Map<String, dynamic> json) {
    return ProviderFacilityModel(
      providerId: json['provider_id'] as String,
      facilityId: json['facility_id'] as String,
      specialty: json['specialty'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      providerName: json['provider_name'] as String?,
      facilityName: json['facility_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'facility_id': facilityId,
      'specialty': specialty,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
      'provider_name': providerName,
      'facility_name': facilityName,
    };
  }

  ProviderFacilityModel copyWith({
    String? providerId,
    String? facilityId,
    String? specialty,
    bool? isPrimary,
    DateTime? createdAt,
    String? providerName,
    String? facilityName,
  }) {
    return ProviderFacilityModel(
      providerId: providerId ?? this.providerId,
      facilityId: facilityId ?? this.facilityId,
      specialty: specialty ?? this.specialty,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      providerName: providerName ?? this.providerName,
      facilityName: facilityName ?? this.facilityName,
    );
  }
}
