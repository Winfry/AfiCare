class SystemSettingModel {
  final String id;
  final String category;
  final String key;
  final dynamic value;
  final String? description;
  final DateTime updatedAt;
  final String? updatedBy;

  SystemSettingModel({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    this.description,
    required this.updatedAt,
    this.updatedBy,
  });

  factory SystemSettingModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingModel(
      id: json['id'] as String,
      category: json['category'] as String,
      key: json['key'] as String,
      value: json['value'],
      description: json['description'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'key': key,
      'value': value,
      'description': description,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}