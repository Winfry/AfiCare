class DependentProfileModel {
  final String id;
  final String guardianId;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender; // 'male', 'female', 'other'
  final String relationship; // 'child', 'grandchild', 'sibling', 'other'
  final String? bloodType;

  /// Known allergies for this dependant. An empty list means "none
  /// recorded" — never a clinical confirmation that they have none.
  final List<String> allergies;
  final String? medilinkId; // 'ML-DEP-XXXXXX'
  final String? notes;
  final DateTime createdAt;

  const DependentProfileModel({
    required this.id,
    required this.guardianId,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    required this.relationship,
    this.bloodType,
    this.allergies = const [],
    this.medilinkId,
    this.notes,
    required this.createdAt,
  });

  factory DependentProfileModel.fromJson(Map<String, dynamic> json) {
    return DependentProfileModel(
      id: json['id'] as String,
      guardianId: json['guardian_id'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      relationship: json['relationship'] as String,
      bloodType: json['blood_type'] as String?,
      // Tolerates the column being absent on older databases.
      allergies: (json['allergies'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      medilinkId: json['medilink_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guardian_id': guardianId,
      'full_name': fullName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'gender': gender,
      'relationship': relationship,
      'blood_type': bloodType,
      'allergies': allergies,
      'medilink_id': medilinkId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DependentProfileModel copyWith({
    String? id,
    String? guardianId,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? relationship,
    String? bloodType,
    List<String>? allergies,
    String? medilinkId,
    String? notes,
    DateTime? createdAt,
  }) {
    return DependentProfileModel(
      id: id ?? this.id,
      guardianId: guardianId ?? this.guardianId,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      relationship: relationship ?? this.relationship,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medilinkId: medilinkId ?? this.medilinkId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Generates a unique MediLink ID for dependents (ML-DEP- prefix).
  static String generateMedilinkId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final uniquePart = timestamp.substring(timestamp.length - 6);
    return 'ML-DEP-$uniquePart';
  }
}
