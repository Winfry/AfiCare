enum UserRole { patient, doctor, nurse, admin }
enum UserStatus { active, suspended, invited }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? medilinkId;
  final String? facilityId;
  final String? department;
  final String? gender;
  final UserStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.medilinkId,
    this.facilityId,
    this.department,
    this.gender,
    this.status = UserStatus.active,
    required this.createdAt,
    this.metadata,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.patient,
      ),
      phone: json['phone'] as String?,
      medilinkId: json['medilink_id'] as String?,
      facilityId: json['facility_id'] as String? ?? json['hospital_id'] as String?,
      department: json['department'] as String?,
      gender: json['gender'] as String?,
      status: _statusFromString(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'phone': phone,
      'medilink_id': medilinkId,
      'facility_id': facilityId,
      'department': department,
      'gender': gender,
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  static String _statusToString(UserStatus s) => s.name;
  static UserStatus _statusFromString(String s) {
    return UserStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => UserStatus.active,
    );
  }

  static String generateMedilinkId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final uniquePart = timestamp.substring(timestamp.length - 6);
    return 'ML-NBO-$uniquePart';
  }
}