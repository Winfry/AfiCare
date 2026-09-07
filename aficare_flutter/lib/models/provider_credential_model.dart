enum VerificationStatus { pending, verified, rejected }

class ProviderCredentialModel {
  final String id;
  final String providerId;
  final String licenseNumber;
  final String? specialty;
  final String requestedRole;
  final VerificationStatus verificationStatus;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  // Denormalized from a join with users, for the admin review list.
  final String? providerName;
  final String? providerEmail;

  const ProviderCredentialModel({
    required this.id,
    required this.providerId,
    required this.licenseNumber,
    this.specialty,
    required this.requestedRole,
    this.verificationStatus = VerificationStatus.pending,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    required this.createdAt,
    this.providerName,
    this.providerEmail,
  });

  factory ProviderCredentialModel.fromJson(Map<String, dynamic> json) {
    return ProviderCredentialModel(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      licenseNumber: json['license_number'] as String,
      specialty: json['specialty'] as String?,
      requestedRole: json['requested_role'] as String,
      verificationStatus: VerificationStatus.values.firstWhere(
        (s) => s.name == json['verification_status'],
        orElse: () => VerificationStatus.pending,
      ),
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      providerName: json['provider_name'] as String?,
      providerEmail: json['provider_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'license_number': licenseNumber,
      'specialty': specialty,
      'requested_role': requestedRole,
      'verification_status': verificationStatus.name,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'provider_name': providerName,
      'provider_email': providerEmail,
    };
  }

  ProviderCredentialModel copyWith({
    String? id,
    String? providerId,
    String? licenseNumber,
    String? specialty,
    String? requestedRole,
    VerificationStatus? verificationStatus,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? rejectionReason,
    DateTime? createdAt,
    String? providerName,
    String? providerEmail,
  }) {
    return ProviderCredentialModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialty: specialty ?? this.specialty,
      requestedRole: requestedRole ?? this.requestedRole,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      providerName: providerName ?? this.providerName,
      providerEmail: providerEmail ?? this.providerEmail,
    );
  }
}
