class WardModel {
  final String id;
  final String facilityId;
  final String name;
  final int totalBeds;
  final DateTime createdAt;
  final DateTime updatedAt;

  WardModel({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.totalBeds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WardModel.fromJson(Map<String, dynamic> json) {
    return WardModel(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      totalBeds: json['total_beds'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
