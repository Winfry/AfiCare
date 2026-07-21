class FacilityModel {
  final String id;
  final String name;
  final String type;
  final String? county;
  final String? subCounty;
  final String? address;
  final String? phone;
  final String? email;
  final String? licenseNo;
  final String status;
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
    this.licenseNo,
    this.status = 'pending',
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
      licenseNo: json['license_no'] as String?,
      status: json['status'] as String? ?? 'pending',
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
      'license_no': licenseNo,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => name;
}