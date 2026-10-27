class InsuranceClaim {
  final String id;
  final String patientId;
  final String? consultationId;
  /// The insurer: see [insurerOptions]. Stored as insurance_claims.insurance_provider.
  final String insuranceType;

  /// Policy or member number. Stored as policy_number.
  final String? insuranceNumber;

  /// See [claimTypes]. Stored as claim_type.
  final String claimType;

  /// 'draft', 'submitted', 'under_review', 'approved', 'rejected' or
  /// 'paid'. Stored as status.
  final String claimStatus;
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
    this.claimType = 'outpatient',
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

  /// Reads an insurance_claims row. The live table's names (042 pre-check)
  /// come first; the older names are still understood.
  factory InsuranceClaim.fromJson(Map<String, dynamic> json) {
    DateTime? date(String a, String b) {
      final v = json[a] ?? json[b];
      return v is String ? DateTime.tryParse(v) : null;
    }

    final status = (json['status'] ?? json['claim_status']) as String? ?? 'draft';
    return InsuranceClaim(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      consultationId: json['consultation_id'] as String?,
      insuranceType: (json['insurance_provider'] ?? json['insurance_type']) as String? ?? 'sha',
      insuranceNumber: (json['policy_number'] ?? json['insurance_number']) as String?,
      claimType: json['claim_type'] as String? ?? 'outpatient',
      claimStatus: status == 'in_review' ? 'under_review' : status,
      claimedAmount: ((json['amount'] ?? json['claimed_amount']) as num?)?.toDouble() ?? 0.0,
      approvedAmount: (json['approved_amount'] as num?)?.toDouble(),
      facilityName: json['facility_name'] as String?,
      facilityCode: json['facility_code'] as String?,
      diagnosis: json['diagnosis'] as String?,
      diagnosisCode: json['diagnosis_code'] as String?,
      services: json['services'] != null
          ? (json['services'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[],
      dateOfService: date('service_date', 'date_of_service') ?? DateTime.now(),
      submittedDate: date('submitted_at', 'submitted_date'),
      resolvedDate: date('resolved_at', 'resolved_date'),
      rejectionReason: json['rejection_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// The columns of insurance_claims.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'insurance_provider': insuranceType,
      'policy_number': insuranceNumber ?? '',
      'claim_type': claimType,
      'amount': claimedAmount,
      'status': claimStatus,
      'service_date': dateOfService.toIso8601String().split('T').first,
      'facility_name': facilityName,
      'diagnosis': diagnosis,
      'submitted_at': submittedDate?.toIso8601String(),
      'resolved_at': resolvedDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// The statuses insurance_claims accepts, in order.
  static const statuses = ['draft', 'submitted', 'under_review', 'approved', 'rejected', 'paid'];

  /// Who the claim is with. NHIF became SHA in October 2024.
  static const Map<String, String> insurerOptions = {
    'sha': 'SHA',
    'private': 'Private insurance',
    'community': 'Community health fund',
    'other': 'Other',
  };

  /// The claim types insurance_claims accepts.
  static const Map<String, String> claimTypes = {
    'outpatient': 'Outpatient visit',
    'inpatient': 'Hospital stay',
    'emergency': 'Emergency',
    'maternity': 'Maternity',
    'chronic': 'Chronic illness',
    'dental': 'Dental',
    'optical': 'Eyes and glasses',
    'other': 'Other',
  };

  static String statusLabel(String status) {
    switch (status) {
      case 'draft': return 'Draft';
      case 'submitted': return 'Submitted';
      case 'under_review':
      case 'in_review': return 'Under Review';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'paid': return 'Paid';
      default: return status;
    }
  }

  static String insuranceTypeLabel(String type) {
    switch (type) {
      case 'sha': return 'SHA';
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
