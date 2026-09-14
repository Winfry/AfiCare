class FacilityPatientModel {
  final String id;
  final String facilityId;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? fileNumber;
  final String shaStatus;
  final String? shaNumber;
  final List<String> allergies;
  final String? linkedUserId;
  final String? linkedDependentId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilityPatientModel({
    required this.id,
    required this.facilityId,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.fileNumber,
    this.shaStatus = 'unknown',
    this.shaNumber,
    this.allergies = const [],
    this.linkedUserId,
    this.linkedDependentId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Years since [dateOfBirth], or null if unknown.
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

  factory FacilityPatientModel.fromJson(Map<String, dynamic> json) {
    return FacilityPatientModel(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.parse(json['date_of_birth'] as String) : null,
      gender: json['gender'] as String?,
      phone: json['phone'] as String?,
      fileNumber: json['file_number'] as String?,
      shaStatus: json['sha_status'] as String? ?? 'unknown',
      shaNumber: json['sha_number'] as String?,
      allergies: (json['allergies'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      linkedUserId: json['linked_user_id'] as String?,
      linkedDependentId: json['linked_dependent_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_id': facilityId,
      'full_name': fullName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'gender': gender,
      'phone': phone,
      'file_number': fileNumber,
      'sha_status': shaStatus,
      'sha_number': shaNumber,
      'allergies': allergies,
      'linked_user_id': linkedUserId,
      'linked_dependent_id': linkedDependentId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FacilityPatientModel copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? phone,
    String? fileNumber,
    String? shaStatus,
    String? shaNumber,
    List<String>? allergies,
  }) {
    return FacilityPatientModel(
      id: id,
      facilityId: facilityId,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      fileNumber: fileNumber ?? this.fileNumber,
      shaStatus: shaStatus ?? this.shaStatus,
      shaNumber: shaNumber ?? this.shaNumber,
      allergies: allergies ?? this.allergies,
      linkedUserId: linkedUserId,
      linkedDependentId: linkedDependentId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => fullName;
}
