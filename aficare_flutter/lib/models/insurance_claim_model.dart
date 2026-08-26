class InsuranceClaim {
  final String id;
  final String patientId;
  final String? consultationId;
  final String insuranceType; // 'nhif', 'private', 'community', 'other'
  final String? insuranceNumber;
  final String claimStatus; // 'draft', 'submitted', 'in_review', 'approved', 'rejected', 'paid'
  final double claimedAmount;
  final double? approvedAmount;
  final String? facilityName;
  final String? facilityCode;
  final String? diagnosis;
  final String? diagnosisCode;
  final List<Map<String, dynamic>> services;
  final DateTime dateOfService;
  final DateTime? submittedDate;
  final DateTime? resolvedDate;
  final String? rejectionReason;
  final String? notes;
  final DateTime createdAt;

  InsuranceClaim({
    required this.id,
    required this.patientId,
    this.consultationId,
    required this.insuranceType,
    this.insuranceNumber,
    required this.claimStatus,
    required this.claimedAmount,
    this.approvedAmount,
    this.facilityName,
    this.facilityCode,
    this.diagnosis,
    this.diagnosisCode,
    this.services = const [],
    required this.dateOfService,
    this.submittedDate,
    this.resolvedDate,
    this.rejectionReason,
    this.notes,
    required this.createdAt,
  });

  factory InsuranceClaim.fromJson(Map<String, dynamic> json) {
    return InsuranceClaim(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      consultationId: json['consultation_id'] as String?,
      insuranceType: json['insurance_type'] as String? ?? 'nhif',
      insuranceNumber: json['insurance_number'] as String?,
      claimStatus: json['claim_status'] as String? ?? 'draft',
      claimedAmount: (json['claimed_amount'] as num?)?.toDouble() ?? 0.0,
      approvedAmount: (json['approved_amount'] as num?)?.toDouble(),
      facilityName: json['facility_name'] as String?,
      facilityCode: json['facility_code'] as String?,
      diagnosis: json['diagnosis'] as String?,
      diagnosisCode: json['diagnosis_code'] as String?,
      services: json['services'] != null
          ? (json['services'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[],
      dateOfService: json['date_of_service'] != null
          ? DateTime.tryParse(json['date_of_service'] as String) ?? DateTime.now()
          : DateTime.now(),
      submittedDate: json['submitted_date'] != null
          ? DateTime.tryParse(json['submitted_date'] as String)
          : null,
      resolvedDate: json['resolved_date'] != null
          ? DateTime.tryParse(json['resolved_date'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'consultation_id': consultationId,
      'insurance_type': insuranceType,
      'insurance_number': insuranceNumber,
      'claim_status': claimStatus,
      'claimed_amount': claimedAmount,
      'approved_amount': approvedAmount,
      'facility_name': facilityName,
      'facility_code': facilityCode,
      'diagnosis': diagnosis,
      'diagnosis_code': diagnosisCode,
      'services': services,
      'date_of_service': dateOfService.toIso8601String(),
      'submitted_date': submittedDate?.toIso8601String(),
      'resolved_date': resolvedDate?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'draft': return 'Draft';
      case 'submitted': return 'Submitted';
      case 'in_review': return 'Under Review';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'paid': return 'Paid';
      default: return status;
    }
  }

  static String insuranceTypeLabel(String type) {
    switch (type) {
      case 'nhif': return 'NHIF';
      case 'private': return 'Private Insurance';
      case 'community': return 'Community Health Fund';
      case 'other': return 'Other';
      default: return type;
    }
  }
}

class PreAuthRequest {
  final String id;
  final String patientId;
  final String? claimId;
  final String insuranceType;
  final String? insuranceNumber;
  final String serviceDescription;
  final String? procedureCode;
  final double estimatedCost;
  final String status; // 'pending', 'approved', 'denied'
  final DateTime requestDate;
  final DateTime? responseDate;
  final String? authorizationNumber;
  final String? notes;

  PreAuthRequest({
    required this.id,
    required this.patientId,
    this.claimId,
    required this.insuranceType,
    this.insuranceNumber,
    required this.serviceDescription,
    this.procedureCode,
    required this.estimatedCost,
    required this.status,
    required this.requestDate,
    this.responseDate,
    this.authorizationNumber,
    this.notes,
  });

  factory PreAuthRequest.fromJson(Map<String, dynamic> json) {
    return PreAuthRequest(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      claimId: json['claim_id'] as String?,
      insuranceType: json['insurance_type'] as String? ?? 'nhif',
      insuranceNumber: json['insurance_number'] as String?,
      serviceDescription: json['service_description'] as String? ?? '',
      procedureCode: json['procedure_code'] as String?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      requestDate: json['request_date'] != null
          ? DateTime.tryParse(json['request_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      responseDate: json['response_date'] != null
          ? DateTime.tryParse(json['response_date'] as String)
          : null,
      authorizationNumber: json['authorization_number'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'claim_id': claimId,
      'insurance_type': insuranceType,
      'insurance_number': insuranceNumber,
      'service_description': serviceDescription,
      'procedure_code': procedureCode,
      'estimated_cost': estimatedCost,
      'status': status,
      'request_date': requestDate.toIso8601String(),
      'response_date': responseDate?.toIso8601String(),
      'authorization_number': authorizationNumber,
      'notes': notes,
    };
  }
}
