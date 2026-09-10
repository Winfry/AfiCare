enum FacilityAdminRequestStatus { pending, approved, rejected }

class FacilityAdminRequestModel {
  final String id;
  // Null until the request is approved and the invited account is
  // created — a facility admin request no longer implies an account
  // exists yet (see 017_facility_admin_invite_flow.sql).
  final String? userId;
  final String facilityId;
  final String applicantName;
  final String applicantEmail;
  final String? title;
  final FacilityAdminRequestStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  // Denormalized from a join with facilities, for the admin review list.
  final String? facilityName;

  const FacilityAdminRequestModel({
    required this.id,
    this.userId,
    required this.facilityId,
    required this.applicantName,
    required this.applicantEmail,
    this.title,
    this.status = FacilityAdminRequestStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
    this.facilityName,
  });

  factory FacilityAdminRequestModel.fromJson(Map<String, dynamic> json) {
    return FacilityAdminRequestModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      facilityId: json['facility_id'] as String,
      applicantName: json['applicant_name'] as String? ?? '',
      applicantEmail: json['applicant_email'] as String? ?? '',
      title: json['title'] as String?,
      status: FacilityAdminRequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FacilityAdminRequestStatus.pending,
      ),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      facilityName: json['facility_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'facility_id': facilityId,
      'applicant_name': applicantName,
      'applicant_email': applicantEmail,
      'title': title,
      'status': status.name,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'facility_name': facilityName,
    };
  }

  FacilityAdminRequestModel copyWith({
    String? id,
    String? userId,
    String? facilityId,
    String? applicantName,
    String? applicantEmail,
    String? title,
    FacilityAdminRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? createdAt,
    String? facilityName,
  }) {
    return FacilityAdminRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      facilityId: facilityId ?? this.facilityId,
      applicantName: applicantName ?? this.applicantName,
      applicantEmail: applicantEmail ?? this.applicantEmail,
      title: title ?? this.title,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      facilityName: facilityName ?? this.facilityName,
    );
  }
}
