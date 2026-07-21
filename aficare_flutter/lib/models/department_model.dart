class DepartmentModel {
  final String id;
  final String facilityId;
  final String name;
  final String? headProviderId;
  final String? description;
  final DateTime createdAt;

  DepartmentModel({
    required this.id,
    required this.facilityId,
    required this.name,
    this.headProviderId,
    this.description,
    required this.createdAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      headProviderId: json['head_provider_id'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_id': facilityId,
      'name': name,
      'head_provider_id': headProviderId,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}