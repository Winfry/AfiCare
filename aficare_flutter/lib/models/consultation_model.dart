class ConsultationModel {
  final String id;
  final String patientId;
  final String providerId;
  final DateTime timestamp;
  final String chiefComplaint;
  final List<String> symptoms;
  final VitalSigns vitalSigns;
  final String triageLevel;
  final List<Diagnosis> diagnoses;
  final List<String> recommendations;
  final String? notes;
  final bool followUpRequired;
  final DateTime? followUpDate;

  ConsultationModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    required this.timestamp,
    required this.chiefComplaint,
    required this.symptoms,
    required this.vitalSigns,
    required this.triageLevel,
    required this.diagnoses,
    required this.recommendations,
    this.notes,
    required this.followUpRequired,
    this.followUpDate,
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    return ConsultationModel(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      providerId: json['provider_id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      chiefComplaint: json['chief_complaint'] as String? ?? '',
      symptoms: json['symptoms'] != null
          ? List<String>.from(json['symptoms'] as List)
          : <String>[],
      vitalSigns: json['vital_signs'] != null
          ? VitalSigns.fromJson(json['vital_signs'] as Map<String, dynamic>)
          : VitalSigns(),
      triageLevel: json['triage_level'] as String? ?? 'non_urgent',
      diagnoses: json['diagnoses'] != null
          ? (json['diagnoses'] as List)
              .map((d) => Diagnosis.fromJson(d as Map<String, dynamic>))
              .toList()
          : <Diagnosis>[],
      recommendations: json['recommendations'] != null
          ? List<String>.from(json['recommendations'] as List)
          : <String>[],
      notes: json['notes'] as String?,
      followUpRequired: json['follow_up_required'] as bool? ?? false,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.tryParse(json['follow_up_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'timestamp': timestamp.toIso8601String(),
      'chief_complaint': chiefComplaint,
      'symptoms': symptoms,
      'vital_signs': vitalSigns.toJson(),
      'triage_level': triageLevel,
      'diagnoses': diagnoses.map((d) => d.toJson()).toList(),
      'recommendations': recommendations,
      'notes': notes,
      'follow_up_required': followUpRequired,
      'follow_up_date': followUpDate?.toIso8601String(),
    };
  }
}

/// ConsultationResult class for AI service integration
class ConsultationResult {
  final String id;
  final String patientId;
  final DateTime timestamp;
  final String chiefComplaint;
  final List<String> symptoms;
  final VitalSigns vitalSigns;
  final String triageLevel;
  final List<Map<String, dynamic>> suspectedConditions;
  final List<String> recommendations;
  final double confidenceScore;
  final bool referralNeeded;
  final bool followUpRequired;

  ConsultationResult({
    required this.id,
    required this.patientId,
    required this.timestamp,
    required this.chiefComplaint,
    required this.symptoms,
    required this.vitalSigns,
    required this.triageLevel,
    required this.suspectedConditions,
    required this.recommendations,
    required this.confidenceScore,
    required this.referralNeeded,
    required this.followUpRequired,
  });

  factory ConsultationResult.fromJson(Map<String, dynamic> json) {
    return ConsultationResult(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      chiefComplaint: json['chief_complaint'] as String? ?? '',
      symptoms: json['symptoms'] != null
          ? List<String>.from(json['symptoms'] as List)
          : <String>[],
      vitalSigns: json['vital_signs'] != null
          ? VitalSigns.fromJson(json['vital_signs'] as Map<String, dynamic>)
          : VitalSigns(),
      triageLevel: json['triage_level'] as String? ?? 'non_urgent',
      suspectedConditions: json['suspected_conditions'] != null
          ? List<Map<String, dynamic>>.from(json['suspected_conditions'] as List)
          : <Map<String, dynamic>>[],
      recommendations: json['recommendations'] != null
          ? List<String>.from(json['recommendations'] as List)
          : <String>[],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      referralNeeded: json['referral_needed'] as bool? ?? false,
      followUpRequired: json['follow_up_required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'timestamp': timestamp.toIso8601String(),
      'chief_complaint': chiefComplaint,
      'symptoms': symptoms,
      'vital_signs': vitalSigns.toJson(),
      'triage_level': triageLevel,
      'suspected_conditions': suspectedConditions,
      'recommendations': recommendations,
      'confidence_score': confidenceScore,
      'referral_needed': referralNeeded,
      'follow_up_required': followUpRequired,
    };
  }
}

class VitalSigns {
  final double? temperature;
  final int? systolicBP;
  final int? diastolicBP;
  final int? pulseRate;
  final int? respiratoryRate;
  final double? oxygenSaturation;
  final double? weight;
  final double? height;

  VitalSigns({
    this.temperature,
    this.systolicBP,
    this.diastolicBP,
    this.pulseRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      temperature: (json['temperature'] as num?)?.toDouble(),
      systolicBP: json['systolic_bp'] as int?,
      diastolicBP: json['diastolic_bp'] as int?,
      pulseRate: json['pulse_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      oxygenSaturation: (json['oxygen_saturation'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'systolic_bp': systolicBP,
      'diastolic_bp': diastolicBP,
      'pulse_rate': pulseRate,
      'respiratory_rate': respiratoryRate,
      'oxygen_saturation': oxygenSaturation,
      'weight': weight,
      'height': height,
    };
  }

  String get bloodPressure => '${systolicBP ?? '-'}/${diastolicBP ?? '-'}';
}

class Diagnosis {
  final String condition;
  final double confidence;
  final List<String> matchingSymptoms;
  final List<String> treatment;

  Diagnosis({
    required this.condition,
    required this.confidence,
    required this.matchingSymptoms,
    required this.treatment,
  });

  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    return Diagnosis(
      condition: json['condition'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      matchingSymptoms: json['matching_symptoms'] != null
          ? List<String>.from(json['matching_symptoms'] as List)
          : <String>[],
      treatment: json['treatment'] != null
          ? List<String>.from(json['treatment'] as List)
          : <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'confidence': confidence,
      'matching_symptoms': matchingSymptoms,
      'treatment': treatment,
    };
  }
}
