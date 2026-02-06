enum UserRole { patient, doctor, nurse, admin }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? medilinkId;
  final String? hospitalId;
  final String? department;
  final String? gender;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.medilinkId,
    this.hospitalId,
    this.department,
    this.gender,
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
      hospitalId: json['hospital_id'] as String?,
      department: json['department'] as String?,
      gender: json['gender'] as String?,
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
      'hospital_id': hospitalId,
      'department': department,
      'gender': gender,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Generate MediLink ID
  static String generateMedilinkId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final uniquePart = timestamp.substring(timestamp.length - 6);
    return 'ML-NBO-$uniquePart';
  }
}
