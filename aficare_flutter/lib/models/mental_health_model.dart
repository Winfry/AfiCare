class MentalHealthScreening {
  final String id;
  final String patientId;
  final String toolType; // 'PHQ-9' or 'GAD-7'
  final List<int> answers;
  final int totalScore;
  final String severity;
  final DateTime completedAt;
  final String? providerNotes;

  MentalHealthScreening({
    required this.id,
    required this.patientId,
    required this.toolType,
    required this.answers,
    required this.totalScore,
    required this.severity,
    required this.completedAt,
    this.providerNotes,
  });

  factory MentalHealthScreening.fromJson(Map<String, dynamic> json) {
    return MentalHealthScreening(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      toolType: json['tool_type'] as String? ?? 'PHQ-9',
      answers: json['answers'] != null
          ? List<int>.from(json['answers'] as List)
          : <int>[],
      totalScore: json['total_score'] as int? ?? 0,
      severity: json['severity'] as String? ?? 'none',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      providerNotes: json['provider_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'tool_type': toolType,
      'answers': answers,
      'total_score': totalScore,
      'severity': severity,
      'completed_at': completedAt.toIso8601String(),
      'provider_notes': providerNotes,
    };
  }

  static String severityFromScore(String toolType, int score) {
    if (toolType == 'PHQ-9') {
      if (score <= 4) return 'none';
      if (score <= 9) return 'mild';
      if (score <= 14) return 'moderate';
      if (score <= 19) return 'moderately_severe';
      return 'severe';
    } else {
      // GAD-7
      if (score <= 4) return 'none';
      if (score <= 9) return 'mild';
      if (score <= 14) return 'moderate';
      return 'severe';
    }
  }

  static String severityLabel(String severity) {
    switch (severity) {
      case 'none': return 'Minimal';
      case 'mild': return 'Mild';
      case 'moderate': return 'Moderate';
      case 'moderately_severe': return 'Moderately Severe';
      case 'severe': return 'Severe';
      default: return severity;
    }
  }
}

class MoodEntry {
  final String id;
  final String patientId;
  final int mood; // 1-5
  final String? journal;
  final List<String> factors;
  final DateTime recordedAt;

  MoodEntry({
    required this.id,
    required this.patientId,
    required this.mood,
    this.journal,
    this.factors = const [],
    required this.recordedAt,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      mood: json['mood'] as int? ?? 3,
      journal: json['journal'] as String?,
      factors: json['factors'] != null
          ? List<String>.from(json['factors'] as List)
          : <String>[],
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'mood': mood,
      'journal': journal,
      'factors': factors,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  static String moodEmoji(int mood) {
    switch (mood) {
      case 1: return '😞';
      case 2: return '😟';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😊';
      default: return '😐';
    }
  }

  static String moodLabel(int mood) {
    switch (mood) {
      case 1: return 'Very Low';
      case 2: return 'Low';
      case 3: return 'Okay';
      case 4: return 'Good';
      case 5: return 'Great';
      default: return 'Okay';
    }
  }
}
