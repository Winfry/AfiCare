class FacilityModel {
  final String id;
  final String name;
  final String type;
  final String? county;
  final String? subCounty;
  final String? address;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  FacilityModel({
    required this.id,
    required this.name,
    required this.type,
    this.county,
    this.subCounty,
    this.address,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'clinic',
      county: json['county'] as String?,
      subCounty: json['sub_county'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'county': county,
      'sub_county': subCounty,
      'address': address,
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => name;
}
