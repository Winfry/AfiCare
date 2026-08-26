class MensHealthScreening {
  final String id;
  final String patientId;
  final String screeningType; // 'cardiovascular', 'prostate', 'lifestyle', 'erectile', 'metabolic'
  final Map<String, dynamic> responses;
  final int riskScore;
  final String riskLevel; // 'low', 'moderate', 'high', 'very_high'
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

  static String screeningLabel(String type) {
    switch (type) {
      case 'cardiovascular': return 'Cardiovascular Risk (Framingham)';
      case 'prostate': return 'Prostate Health (IPSS)';
      case 'lifestyle': return 'Lifestyle & Wellness';
      case 'erectile': return 'Sexual Health (IIEF-5)';
      case 'metabolic': return 'Metabolic Syndrome';
      default: return type;
    }
  }

  static String screeningDescription(String type) {
    switch (type) {
      case 'cardiovascular':
        return '10-year heart disease risk assessment using age, cholesterol, BP, smoking, diabetes';
      case 'prostate':
        return 'International Prostate Symptom Score — urinary symptoms and quality of life';
      case 'lifestyle':
        return 'Physical activity, alcohol, smoking, sleep, stress, and nutrition check';
      case 'erectile':
        return 'International Index of Erectile Function — sexual health screening';
      case 'metabolic':
        return 'Waist circumference, BP, glucose, triglycerides, HDL assessment';
      default: return '';
    }
  }

  static String riskLevelLabel(String level) {
    switch (level) {
      case 'low': return 'Low Risk';
      case 'moderate': return 'Moderate Risk';
      case 'high': return 'High Risk';
      case 'very_high': return 'Very High Risk';
      default: return level;
    }
  }

  // Framingham-inspired cardiovascular risk questions
  static const List<Map<String, dynamic>> cvdQuestions = [
    {'key': 'age', 'question': 'Your age range', 'options': ['30-39', '40-49', '50-59', '60-69', '70-79'], 'scores': [0, 1, 2, 3, 4]},
    {'key': 'total_cholesterol', 'question': 'Total cholesterol (mg/dL)', 'options': ['<160', '160-199', '200-239', '240-279', '280+'], 'scores': [0, 1, 2, 3, 4]},
    {'key': 'hdl', 'question': 'HDL cholesterol (mg/dL)', 'options': ['60+', '50-59', '40-49', '<40'], 'scores': [0, 1, 2, 3]},
    {'key': 'systolic_bp', 'question': 'Systolic blood pressure', 'options': ['<120', '120-129', '130-139', '140-159', '160+'], 'scores': [0, 1, 2, 3, 4]},
    {'key': 'bp_treatment', 'question': 'On blood pressure medication?', 'options': ['No', 'Yes'], 'scores': [0, 2]},
    {'key': 'smoker', 'question': 'Current smoker?', 'options': ['No', 'Yes'], 'scores': [0, 2]},
    {'key': 'diabetes', 'question': 'Diabetic?', 'options': ['No', 'Yes'], 'scores': [0, 2]},
  ];

  // IPSS prostate symptom questions
  static const List<Map<String, dynamic>> ipssQuestions = [
    {'key': 'incomplete_emptying', 'question': 'Over the last month, how often have you had a sensation of not emptying your bladder completely after urinating?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'frequency', 'question': 'How often have you had to urinate again less than two hours after finishing urinating?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'intermittent', 'question': 'How often have you found you stopped and started again several times when urinating?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'urgency', 'question': 'How often have you found it difficult to postpone urination?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'weak_stream', 'question': 'How often have you had a weak urinary stream?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'straining', 'question': 'How often have you had to push or strain to begin urination?', 'options': ['Not at all', 'Less than 1 in 5', 'Less than half', 'About half', 'More than half', 'Almost always'], 'scores': [0, 1, 2, 3, 4, 5]},
    {'key': 'nocturia', 'question': 'How many times did you typically get up to urinate from the time you went to bed until the time you got up in the morning?', 'options': ['None', '1 time', '2 times', '3 times', '4 times', '5+ times'], 'scores': [0, 1, 2, 3, 4, 5]},
  ];

  static String ipssSeverity(int score) {
    if (score <= 7) return 'mild';
    if (score <= 19) return 'moderate';
    return 'severe';
  }

  static String cvdRiskInterpretation(int score) {
    if (score <= 5) return 'low';
    if (score <= 10) return 'moderate';
    if (score <= 15) return 'high';
    return 'very_high';
  }
}
