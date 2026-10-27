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
  /// See [paymentMethodOptions]. Older rows may hold 'nhif', 'mhealth' or
  /// 'free', which still display.
  final String paymentMethod;
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

  /// Reads a medication_costs row. The table stores the total as `cost`
  /// and the pharmacy as `pharmacy` (042); the unit cost is worked out.
  factory MedicationCost.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final total = ((json['cost'] ?? json['total_cost']) as num?)?.toDouble() ?? 0.0;
    return MedicationCost(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      prescriptionId: json['prescription_id'] as String?,
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      quantity: quantity,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? (quantity > 0 ? total / quantity : total),
      totalCost: total,
      pharmacyName: (json['pharmacy'] ?? json['pharmacy_name']) as String?,
      facilityName: json['facility_name'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      purchaseDate: json['purchase_date'] != null
          ? DateTime.tryParse(json['purchase_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      receiptId: json['receipt_id'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// The columns of medication_costs (see [MedicationCost.fromJson]).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'prescription_id': prescriptionId,
      'medication_name': medicationName,
      'dosage': dosage,
      'quantity': quantity,
      'cost': totalCost,
      'pharmacy': pharmacyName,
      'payment_method': paymentMethod,
      'purchase_date': purchaseDate.toIso8601String().split('T').first,
      'notes': notes,
    };
  }

  /// What the app offers now. NHIF became SHA in October 2024.
  static const Map<String, String> paymentMethodOptions = {
    'cash': 'Cash',
    'mpesa': 'M-Pesa',
    'sha': 'SHA',
    'insurance': 'Insurance',
    'subsidized': 'Subsidized',
  };

  static String paymentMethodLabel(String method) {
    switch (method) {
      case 'nhif': return 'NHIF';
      case 'mhealth': return 'M-Pesa';
      case 'free': return 'Free (Subsidized)';
      default: return paymentMethodOptions[method] ?? method;
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
