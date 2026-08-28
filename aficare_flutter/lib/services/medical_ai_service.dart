import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/consultation_model.dart';

/// Medical AI Service that integrates with AfiCare backend
/// Supports both local rule-based AI and backend integration
/// The local AI works completely offline - no internet required
class MedicalAIService {
  static const String backendUrl = String.fromEnvironment(
    'AFICARE_BACKEND_URL',
    defaultValue: '',
  );

  static const bool preferLocalAI = true;

  Future<ConsultationResult> conductConsultation({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
    required String chiefComplaint,
  }) async {
    if (preferLocalAI || backendUrl.isEmpty) {
      return await _consultWithLocalAI(
        patientId: patientId,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: age,
        gender: gender,
        chiefComplaint: chiefComplaint,
      );
    }

    try {
      final result = await _consultWithBackend(
        patientId: patientId,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: age,
        gender: gender,
        chiefComplaint: chiefComplaint,
      );
      return result;
    } catch (e) {
      debugPrint('Backend unavailable, using local AI: $e');
      return await _consultWithLocalAI(
        patientId: patientId,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: age,
        gender: gender,
        chiefComplaint: chiefComplaint,
      );
    }
  }

  Future<ConsultationResult> _consultWithBackend({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
    required String chiefComplaint,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/consult'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient_id': patientId,
        'symptoms': symptoms,
        'vital_signs': vitalSigns,
        'age': age,
        'gender': gender,
        'chief_complaint': chiefComplaint,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ConsultationResult.fromJson(data);
    } else {
      throw Exception('Backend consultation failed: ${response.statusCode}');
    }
  }

  Future<ConsultationResult> _consultWithLocalAI({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
    required String chiefComplaint,
  }) async {
    final vitalSignsModel = VitalSigns(
      temperature: vitalSigns['temperature'],
      systolicBP: vitalSigns['systolic_bp']?.toInt(),
      diastolicBP: vitalSigns['diastolic_bp']?.toInt(),
      pulseRate: vitalSigns['pulse']?.toInt(),
      respiratoryRate: vitalSigns['respiratory_rate']?.toInt(),
      oxygenSaturation: vitalSigns['oxygen_saturation'],
    );

    final analysis = await analyze(
      symptoms: symptoms,
      vitalSigns: vitalSignsModel,
      age: age,
      gender: gender,
    );

    final diagnoses = analysis['diagnoses'] as List<Diagnosis>;
    final triageLevel = analysis['triage_level'] as String;

    return ConsultationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      timestamp: DateTime.now(),
      chiefComplaint: chiefComplaint,
      symptoms: symptoms,
      vitalSigns: vitalSignsModel,
      triageLevel: triageLevel,
      suspectedConditions: diagnoses.map((d) => {
        'name': d.condition,
        'confidence': d.confidence,
      }).toList(),
      recommendations: diagnoses.isNotEmpty
          ? diagnoses.first.treatment
          : ['Rest and monitor symptoms', 'Seek medical attention if symptoms worsen'],
      confidenceScore: diagnoses.isNotEmpty ? diagnoses.first.confidence : 0.5,
      referralNeeded: triageLevel == 'emergency' || triageLevel == 'urgent',
      followUpRequired: true,
    );
  }

  final Map<String, MedicalCondition> _conditions = {
    'malaria': MedicalCondition(
      name: 'Malaria',
      symptoms: {
        'fever': 0.9, 'chills': 0.8, 'headache': 0.7,
        'muscle aches': 0.6, 'nausea': 0.5, 'fatigue': 0.6,
        'vomiting': 0.5, 'sweating': 0.4,
      },
      treatment: [
        'Artemether-Lumefantrine based on weight',
        'Paracetamol for fever and pain',
        'Oral rehydration therapy',
        'Rest and adequate nutrition',
        'Follow-up in 3 days',
      ],
      dangerSigns: ['severe headache', 'confusion', 'difficulty breathing'],
    ),
    'pneumonia': MedicalCondition(
      name: 'Pneumonia',
      symptoms: {
        'cough': 0.9, 'fever': 0.8, 'difficulty breathing': 0.9,
        'chest pain': 0.7, 'fatigue': 0.6, 'rapid breathing': 0.8,
        'chills': 0.6,
      },
      treatment: [
        'Amoxicillin 15mg/kg twice daily for 5 days (children)',
        'Amoxicillin 500mg three times daily for 5 days (adults)',
        'Oxygen therapy if SpO2 < 90%',
        'Adequate fluid intake',
        'Follow-up in 2-3 days',
      ],
      dangerSigns: ['difficulty breathing', 'chest pain', 'high fever'],
    ),
    'hypertension': MedicalCondition(
      name: 'Hypertension',
      symptoms: {
        'headache': 0.4, 'dizziness': 0.5, 'blurred vision': 0.6,
        'chest pain': 0.3, 'fatigue': 0.3,
      },
      treatment: [
        'Lifestyle modifications (diet, exercise)',
        'Regular blood pressure monitoring',
        'Antihypertensive medication if indicated',
        'Reduce salt intake',
        'Regular follow-up',
      ],
      dangerSigns: ['severe headache', 'chest pain', 'difficulty breathing'],
    ),
    'common_cold': MedicalCondition(
      name: 'Common Cold/Flu',
      symptoms: {
        'cough': 0.7, 'runny nose': 0.8, 'sore throat': 0.7,
        'headache': 0.5, 'fatigue': 0.6, 'muscle aches': 0.4,
        'fever': 0.4,
      },
      treatment: [
        'Rest and adequate sleep',
        'Increase fluid intake',
        'Paracetamol for fever and pain',
        'Warm salt water gargling',
        'Return if symptoms worsen',
      ],
      dangerSigns: ['high fever', 'difficulty breathing', 'severe headache'],
    ),
    'diabetes': MedicalCondition(
      name: 'Diabetes Mellitus',
      symptoms: {
        'frequent urination': 0.8, 'excessive thirst': 0.8,
        'unexplained weight loss': 0.7, 'fatigue': 0.6,
        'blurred vision': 0.5, 'slow healing': 0.5,
      },
      treatment: [
        'Blood glucose monitoring',
        'Dietary modifications',
        'Regular exercise',
        'Medication as prescribed',
        'Regular follow-up every 3 months',
      ],
      dangerSigns: ['confusion', 'excessive thirst', 'fruity breath'],
    ),
    'tuberculosis': MedicalCondition(
      name: 'Tuberculosis',
      symptoms: {
        'persistent cough': 0.9, 'coughing blood': 0.8,
        'night sweats': 0.7, 'weight loss': 0.7,
        'fatigue': 0.6, 'fever': 0.5, 'chest pain': 0.5,
      },
      treatment: [
        'Refer for TB testing (sputum, chest X-ray)',
        'DOTS therapy if confirmed',
        '6-month treatment regimen',
        'Contact tracing',
        'Monthly follow-up',
      ],
      dangerSigns: ['coughing blood', 'severe weight loss', 'difficulty breathing'],
    ),
  };

  Future<Map<String, dynamic>> analyze({
    required List<String> symptoms,
    required VitalSigns vitalSigns,
    required int age,
    required String gender,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    List<Diagnosis> diagnoses = [];
    String triageLevel = 'non_urgent';

    final normalizedSymptoms = symptoms
        .map((s) => s.toLowerCase().trim())
        .toList();

    for (final entry in _conditions.entries) {
      final condition = entry.value;
      double score = 0.0;
      List<String> matchingSymptoms = [];

      for (final symptom in normalizedSymptoms) {
        for (final conditionSymptom in condition.symptoms.entries) {
          if (symptom.contains(conditionSymptom.key) ||
              conditionSymptom.key.contains(symptom)) {
            score += conditionSymptom.value;
            matchingSymptoms.add(conditionSymptom.key);
          }
        }
      }

      if (entry.key == 'malaria' && (vitalSigns.temperature ?? 37) > 38.5) {
        score += 0.3;
      } else if (entry.key == 'pneumonia') {
        if ((vitalSigns.respiratoryRate ?? 16) > 24) score += 0.2;
        if ((vitalSigns.temperature ?? 37) > 38.0) score += 0.2;
      } else if (entry.key == 'hypertension' &&
          (vitalSigns.systolicBP ?? 120) > 140) {
        score += 0.4;
      }

      if (entry.key == 'pneumonia' && (age < 5 || age > 65)) {
        score += 0.1;
      } else if (entry.key == 'hypertension' && age > 40) {
        score += 0.1;
      }

      if (score > 0.3) {
        diagnoses.add(Diagnosis(
          condition: condition.name,
          confidence: (score).clamp(0.0, 1.0),
          matchingSymptoms: matchingSymptoms,
          treatment: condition.treatment,
        ));

        for (final danger in condition.dangerSigns) {
          if (normalizedSymptoms.any((s) => s.contains(danger))) {
            triageLevel = 'emergency';
          }
        }
      }
    }

    diagnoses.sort((a, b) => b.confidence.compareTo(a.confidence));

    triageLevel = _assessTriage(vitalSigns, normalizedSymptoms, triageLevel);

    return {
      'diagnoses': diagnoses.take(3).toList(),
      'triage_level': triageLevel,
    };
  }

  String _assessTriage(
      VitalSigns vitals, List<String> symptoms, String currentLevel) {
    final emergencySymptoms = [
      'difficulty breathing', 'chest pain', 'unconscious',
      'severe bleeding', 'convulsions',
    ];

    for (final emergency in emergencySymptoms) {
      if (symptoms.any((s) => s.contains(emergency))) {
        return 'emergency';
      }
    }

    final temp = vitals.temperature ?? 37;
    final systolic = vitals.systolicBP ?? 120;
    final respRate = vitals.respiratoryRate ?? 16;
    final spo2 = vitals.oxygenSaturation ?? 98;

    if (temp > 40 || systolic > 180 || respRate > 30 || spo2 < 90) {
      return 'emergency';
    }
    if (temp > 39 || systolic > 160 || respRate > 24 || spo2 < 94) {
      return 'urgent';
    }
    if (temp > 38 || systolic > 140 || respRate > 20) {
      return 'less_urgent';
    }

    return currentLevel;
  }
}

class MedicalCondition {
  final String name;
  final Map<String, double> symptoms;
  final List<String> treatment;
  final List<String> dangerSigns;

  MedicalCondition({
    required this.name,
    required this.symptoms,
    required this.treatment,
    required this.dangerSigns,
  });
}
