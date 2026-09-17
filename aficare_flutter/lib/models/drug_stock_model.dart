/// A facility's own drug inventory row -- `facility_drug_stock`. Unlike
/// every visit-derived board (Queue/Billing/Lab/Prescriptions), a stock
/// item has no patient dimension to join against, so this is a
/// standalone model (like DepartmentModel), not a join row.
class DrugStockModel {
  final String id;
  final String facilityId;
  final String drugName;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int quantityOnHand;
  final int reorderThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  DrugStockModel({
    required this.id,
    required this.facilityId,
    required this.drugName,
    this.batchNumber,
    this.expiryDate,
    required this.quantityOnHand,
    required this.reorderThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DrugStockModel.fromJson(Map<String, dynamic> json) => DrugStockModel(
        id: json['id'] as String,
        facilityId: json['facility_id'] as String,
        drugName: json['drug_name'] as String,
        batchNumber: json['batch_number'] as String?,
        expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
        quantityOnHand: json['quantity_on_hand'] as int,
        reorderThreshold: json['reorder_threshold'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// 'critical' (reorder now) / 'warning' (low) / 'ok' (in stock) -- a
  /// derived annotation over quantityOnHand vs reorderThreshold, same as
  /// Laboratory's client-computed "Overdue" -- never stored.
  String get stockLevelStatus {
    if (quantityOnHand == 0) return 'critical';
    if (quantityOnHand <= reorderThreshold) return 'warning';
    return 'ok';
  }

  /// Proportional fill for a stock-level bar, clamped to [0, 1].
  double get stockLevelFraction {
    final denom = (reorderThreshold * 2).clamp(1, 1 << 30);
    return (quantityOnHand / denom).clamp(0.0, 1.0);
  }
}
