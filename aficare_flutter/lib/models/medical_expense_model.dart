enum ExpenseCategory {
  medication,
  consultation,
  labTest,
  procedure,
  hospitalStay,
  other;

  String get label {
    switch (this) {
      case ExpenseCategory.medication:
        return 'Medication';
      case ExpenseCategory.consultation:
        return 'Consultation';
      case ExpenseCategory.labTest:
        return 'Lab Test';
      case ExpenseCategory.procedure:
        return 'Procedure';
      case ExpenseCategory.hospitalStay:
        return 'Hospital Stay';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String toJson() => name;

  static ExpenseCategory fromJson(String s) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class MedicalExpenseModel {
  final String id;
  final String patientId;
  final ExpenseCategory category;
  final double amount;
  final String currency;
  final String description;
  final DateTime date;
  final String? facilityName;
  final String? notes;
  final DateTime createdAt;

  MedicalExpenseModel({
    required this.id,
    required this.patientId,
    required this.category,
    required this.amount,
    this.currency = 'KES',
    required this.description,
    required this.date,
    this.facilityName,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MedicalExpenseModel.fromJson(Map<String, dynamic> json) {
    return MedicalExpenseModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      category: ExpenseCategory.fromJson(json['category'] as String),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'KES',
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      facilityName: json['facility_name'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'category': category.toJson(),
      'amount': amount,
      'currency': currency,
      'description': description,
      'date': date.toIso8601String().substring(0, 10),
      'facility_name': facilityName,
      'notes': notes,
    };
  }

  MedicalExpenseModel copyWith({
    String? id,
    String? patientId,
    ExpenseCategory? category,
    double? amount,
    String? currency,
    String? description,
    DateTime? date,
    String? facilityName,
    String? notes,
  }) {
    return MedicalExpenseModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      date: date ?? this.date,
      facilityName: facilityName ?? this.facilityName,
      notes: notes ?? this.notes,
    );
  }
}
