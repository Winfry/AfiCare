/// A saved Men's health check-up. Since 046, [responses] holds
/// `{'answers': {questionKey: value}}`; older rows held a bare list.
class MensHealthScreening {
  final String id;
  final String patientId;
  /// One of the `MhTool.all` types (see mens_health_tools.dart).
  final String screeningType;
  final Map<String, dynamic> responses;
  final int riskScore;
  /// One of that tool's `levels`.
  final String riskLevel;
  final Map<String, dynamic>? vitals;
  final String? recommendations;
  final DateTime completedAt;

  MensHealthScreening({
    required this.id,
    required this.patientId,
    required this.screeningType,
    this.responses = const {},
    required this.riskScore,
    required this.riskLevel,
    this.vitals,
    this.recommendations,
    required this.completedAt,
  });

  factory MensHealthScreening.fromJson(Map<String, dynamic> json) {
    return MensHealthScreening(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      screeningType: json['screening_type'] as String? ?? 'cardiovascular',
      responses: json['responses'] != null
          ? Map<String, dynamic>.from(json['responses'] as Map)
          : <String, dynamic>{},
      riskScore: json['risk_score'] as int? ?? 0,
      riskLevel: json['risk_level'] as String? ?? 'low',
      vitals: json['vitals'] != null
          ? Map<String, dynamic>.from(json['vitals'] as Map)
          : null,
      recommendations: json['recommendations'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'screening_type': screeningType,
      'responses': responses,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'vitals': vitals,
      'recommendations': recommendations,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

extension MensHealthAnswers on MensHealthScreening {
  /// The answers by question, or null for older rows saved as a list
  /// (which can't be matched to questions any more).
  Map<String, int>? get answersByQuestion {
    final a = responses['answers'];
    if (a is! Map) return null;
    final out = <String, int>{};
    for (final e in a.entries) {
      final v = e.value;
      if (v is! int) return null;
      out[e.key.toString()] = v;
    }
    return out;
  }
}
