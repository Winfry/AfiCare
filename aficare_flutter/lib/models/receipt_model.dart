class Receipt {
  final String id;
  final String patientId;
  final String? imageUrl;
  final String? facilityName;
  final double? totalAmount;
  final String? serviceType;
  final String? paymentMethod;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  Receipt({
    required this.id,
    required this.patientId,
    this.imageUrl,
    this.facilityName,
    this.totalAmount,
    this.serviceType,
    this.paymentMethod,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      facilityName: json['facility_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      serviceType: json['service_type'] as String?,
      paymentMethod: json['payment_method'] as String?,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static const List<String> serviceTypeOptions = [
    'Consultation', 'Lab Test', 'Imaging', 'Medication', 'Surgery',
    'Dental', 'Optical', 'Maternity', 'Other',
  ];

  static const Map<String, String> paymentMethodOptions = {
    'cash': 'Cash',
    'nhif': 'NHIF',
    'insurance': 'Insurance',
    'mpesa': 'M-Pesa',
    'card': 'Card',
    'subsidized': 'Subsidized',
  };

  static String paymentMethodLabel(String method) {
    return paymentMethodOptions[method] ?? method;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'image_url': imageUrl,
      'facility_name': facilityName,
      'total_amount': totalAmount,
      'service_type': serviceType,
      'payment_method': paymentMethod,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }
}
