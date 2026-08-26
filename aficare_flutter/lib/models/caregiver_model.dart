class CaregiverAccess {
  final String id;
  final String caregiverUserId;
  final String dependentPatientId;
  final String accessCode;
  final String accessLevel; // 'full', 'medical_only', 'appointments_only', 'emergency_only'
  final bool isActive;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final String? grantedByPatientId;
  final String? notes;

  CaregiverAccess({
    required this.id,
    required this.caregiverUserId,
    required this.dependentPatientId,
    required this.accessCode,
    required this.accessLevel,
    this.isActive = true,
    required this.grantedAt,
    this.expiresAt,
    this.grantedByPatientId,
    this.notes,
  });

  factory CaregiverAccess.fromJson(Map<String, dynamic> json) {
    return CaregiverAccess(
      id: json['id'] as String? ?? '',
      caregiverUserId: json['caregiver_user_id'] as String? ?? '',
      dependentPatientId: json['dependent_patient_id'] as String? ?? '',
      accessCode: json['access_code'] as String? ?? '',
      accessLevel: json['access_level'] as String? ?? 'full',
      isActive: json['is_active'] as bool? ?? true,
      grantedAt: json['granted_at'] != null
          ? DateTime.tryParse(json['granted_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      grantedByPatientId: json['granted_by_patient_id'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caregiver_user_id': caregiverUserId,
      'dependent_patient_id': dependentPatientId,
      'access_code': accessCode,
      'access_level': accessLevel,
      'is_active': isActive,
      'granted_at': grantedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'granted_by_patient_id': grantedByPatientId,
      'notes': notes,
    };
  }

  static String accessLevelLabel(String level) {
    switch (level) {
      case 'full': return 'Full Access';
      case 'medical_only': return 'Medical Records Only';
      case 'appointments_only': return 'Appointments Only';
      case 'emergency_only': return 'Emergency Info Only';
      default: return level;
    }
  }

  static String generateAccessCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = (random % 1000000).toString().padLeft(6, '0');
    return code;
  }
}

class CaregiverActivity {
  final String id;
  final String caregiverAccessId;
  final String actionType; // 'viewed_records', 'viewed_appointments', 'logged_in', 'updated_meds'
  final String? details;
  final DateTime timestamp;

  CaregiverActivity({
    required this.id,
    required this.caregiverAccessId,
    required this.actionType,
    this.details,
    required this.timestamp,
  });

  factory CaregiverActivity.fromJson(Map<String, dynamic> json) {
    return CaregiverActivity(
      id: json['id'] as String? ?? '',
      caregiverAccessId: json['caregiver_access_id'] as String? ?? '',
      actionType: json['action_type'] as String? ?? 'logged_in',
      details: json['details'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
