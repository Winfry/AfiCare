import 'dart:ui' show Color;

enum TriageLevel { emergency, urgent, nonUrgent }

class TriageAssessment {
  final String id;
  final String patientId;
  final String providerId;
  final String? consultationId;
  final DateTime assessedAt;
  final String chiefComplaint;
  final List<String> symptoms;
  final TriageLevel triageLevel;
  final double? temperature;
  final int? systolicBP;
  final int? diastolicBP;
  final int? heartRate;
  final int? respiratoryRate;
  final double? oxygenSaturation;
  final double? weight;
  final String? notes;

  TriageAssessment({
    required this.id,
    required this.patientId,
    required this.providerId,
    this.consultationId,
    required this.assessedAt,
    required this.chiefComplaint,
    required this.symptoms,
    required this.triageLevel,
    this.temperature,
    this.systolicBP,
    this.diastolicBP,
    this.heartRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.notes,
  });

  factory TriageAssessment.fromJson(Map<String, dynamic> json) {
    return TriageAssessment(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      consultationId: json['consultation_id'] as String?,
      assessedAt: DateTime.parse(json['assessed_at'] as String),
      chiefComplaint: json['chief_complaint'] as String,
      symptoms: json['symptoms'] != null
          ? List<String>.from(json['symptoms'] as List)
          : [],
      triageLevel: _triageFromString(json['triage_level'] as String),
      temperature: (json['temperature'] as num?)?.toDouble(),
      systolicBP: json['systolic_bp'] as int?,
      diastolicBP: json['diastolic_bp'] as int?,
      heartRate: json['heart_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      oxygenSaturation: (json['oxygen_saturation'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'consultation_id': consultationId,
      'assessed_at': assessedAt.toIso8601String(),
      'chief_complaint': chiefComplaint,
      'symptoms': symptoms,
      'triage_level': _triageToString(triageLevel),
      'temperature': temperature,
      'systolic_bp': systolicBP,
      'diastolic_bp': diastolicBP,
      'heart_rate': heartRate,
      'respiratory_rate': respiratoryRate,
      'oxygen_saturation': oxygenSaturation,
      'weight': weight,
      'notes': notes,
    };
  }

  Color get triageColor => _triageColor(triageLevel);

  static Color _triageColor(TriageLevel l) {
    switch (l) {
      case TriageLevel.emergency:
        return const Color(0xFFE53935);
      case TriageLevel.urgent:
        return const Color(0xFFFB8C00);
      case TriageLevel.nonUrgent:
        return const Color(0xFF43A047);
    }
  }

  String get triageLabel {
    switch (triageLevel) {
      case TriageLevel.emergency:
        return 'Emergency';
      case TriageLevel.urgent:
        return 'Urgent';
      case TriageLevel.nonUrgent:
        return 'Non-Urgent';
    }
  }

  static TriageLevel _triageFromString(String s) {
    switch (s) {
      case 'emergency':
        return TriageLevel.emergency;
      case 'urgent':
        return TriageLevel.urgent;
      default:
        return TriageLevel.nonUrgent;
    }
  }

  static String _triageToString(TriageLevel l) {
    switch (l) {
      case TriageLevel.emergency:
        return 'emergency';
      case TriageLevel.urgent:
        return 'urgent';
      case TriageLevel.nonUrgent:
        return 'non_urgent';
    }
  }
}