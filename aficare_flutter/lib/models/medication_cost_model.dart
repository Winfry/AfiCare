class MedicationCost {
  final String id;
  final String patientId;
  final String? prescriptionId;
  final String medicationName;
  final String dosage;
  final int quantity;
  final double unitCost;
  final double totalCost;
  final String? pharmacyName;
  final String? facilityName;
  final String paymentMethod; // 'cash', 'nhif', 'insurance', 'mhealth', 'free'
  final DateTime purchaseDate;
  final String? receiptId;
  final String? notes;

  MedicationCost({
    required this.id,
    required this.patientId,
    this.prescriptionId,
    required this.medicationName,
    required this.dosage,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.pharmacyName,
    this.facilityName,
    this.paymentMethod = 'cash',
    required this.purchaseDate,
    this.receiptId,
    this.notes,
  });

  factory MedicationCost.fromJson(Map<String, dynamic> json) {
    return MedicationCost(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      prescriptionId: json['prescription_id'] as String?,
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      pharmacyName: json['pharmacy_name'] as String?,
      facilityName: json['facility_name'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      purchaseDate: json['purchase_date'] != null
          ? DateTime.tryParse(json['purchase_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      receiptId: json['receipt_id'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'prescription_id': prescriptionId,
      'medication_name': medicationName,
      'dosage': dosage,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'pharmacy_name': pharmacyName,
      'facility_name': facilityName,
      'payment_method': paymentMethod,
      'purchase_date': purchaseDate.toIso8601String(),
      'receipt_id': receiptId,
      'notes': notes,
    };
  }

  static String paymentMethodLabel(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'nhif': return 'NHIF';
      case 'insurance': return 'Insurance';
      case 'mhealth': return 'M-Pesa';
      case 'free': return 'Free (Subsidized)';
      default: return method;
    }
  }
}

class MedicationBudget {
  final String patientId;
  final double monthlyBudget;
  final double spentThisMonth;
  final double remaining;
  final List<MedicationCost> recentPurchases;

  MedicationBudget({
    required this.patientId,
    required this.monthlyBudget,
    required this.spentThisMonth,
    required this.remaining,
    this.recentPurchases = const [],
  });

  double get usagePercentage => monthlyBudget > 0 ? (spentThisMonth / monthlyBudget) * 100 : 0;
  bool get isOverBudget => spentThisMonth > monthlyBudget;
  bool get isNearLimit => usagePercentage > 80 && !isOverBudget;

  static MedicationBudget calculate({
    required String patientId,
    required double monthlyBudget,
    required List<MedicationCost> costs,
  }) {
    final now = DateTime.now();
    final monthCosts = costs.where((c) =>
        c.purchaseDate.year == now.year && c.purchaseDate.month == now.month);
    final spent = monthCosts.fold(0.0, (sum, c) => sum + c.totalCost);

    return MedicationBudget(
      patientId: patientId,
      monthlyBudget: monthlyBudget,
      spentThisMonth: spent,
      remaining: monthlyBudget - spent,
      recentPurchases: costs.take(10).toList(),
    );
  }
}

class PharmacyPrice {
  final String id;
  final String medicationName;
  final String dosage;
  final String pharmacyName;
  final String? facilityType; // 'hospital', 'chemist', 'online'
  final double price;
  final DateTime lastUpdated;
  final String? location;

  PharmacyPrice({
    required this.id,
    required this.medicationName,
    required this.dosage,
    required this.pharmacyName,
    this.facilityType,
    required this.price,
    required this.lastUpdated,
    this.location,
  });

  factory PharmacyPrice.fromJson(Map<String, dynamic> json) {
    return PharmacyPrice(
      id: json['id'] as String? ?? '',
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      pharmacyName: json['pharmacy_name'] as String? ?? '',
      facilityType: json['facility_type'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medication_name': medicationName,
      'dosage': dosage,
      'pharmacy_name': pharmacyName,
      'facility_type': facilityType,
      'price': price,
      'last_updated': lastUpdated.toIso8601String(),
      'location': location,
    };
  }
}
