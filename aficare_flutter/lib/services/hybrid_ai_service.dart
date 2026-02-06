import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/consultation_model.dart';

/// Hybrid AI Service that connects to AfiCare backend
/// Supports both Streamlit backend and local fallback
/// Note: Primary service is MedicalAIService which has full offline support
class HybridAIService {
  // Production URL - update to your deployed Railway/Render URL
  static const String streamlitUrl = 'https://aficare-backend.up.railway.app';
  
  /// Conduct consultation with hybrid AI backend
  Future<ConsultationResult> conductConsultation({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
    required String chiefComplaint,
  }) async {
    try {
      // Try Streamlit backend first
      final response = await http.post(
        Uri.parse('$streamlitUrl/api/ai-consultation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': patientId,
          'symptoms': symptoms,
          'vital_signs': vitalSigns,
          'age': age,
          'gender': gender,
          'chief_complaint': chiefComplaint,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ConsultationResult.fromJson(data);
      } else {
        throw Exception('Backend consultation failed');
      }
    } catch (e) {
      // Fallback to local AI simulation
      print('Backend unavailable, using local simulation: $e');
      return _simulateAIConsultation(
        patientId: patientId,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: age,
        gender: gender,
        chiefComplaint: chiefComplaint,
      );
    }
  }

  /// Local AI simulation for offline use
  Future<ConsultationResult> _simulateAIConsultation({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
    required String chiefComplaint,
  }) async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 1200));

    // Simple rule-based analysis
    String triageLevel = 'non_urgent';
    List<Map<String, dynamic>> conditions = [];
    List<String> recommendations = [];

    // Check for emergency symptoms
    final emergencySymptoms = [
      'difficulty breathing', 'chest pain', 'unconscious', 'severe bleeding'
    ];
    
    if (symptoms.any((s) => emergencySymptoms.any((e) => s.toLowerCase().contains(e)))) {
      triageLevel = 'emergency';
    }

    // Check vital signs
    final temp = vitalSigns['temperature'] ?? 37.0;
    final systolic = vitalSigns['systolic_bp'] ?? 120.0;
    
    if (temp > 39.0 || systolic > 180) {
      triageLevel = 'urgent';
    }

    // Analyze symptoms for conditions
    if (symptoms.any((s) => s.toLowerCase().contains('fever'))) {
      if (symptoms.any((s) => s.toLowerCase().contains('cough'))) {
        conditions.add({'name': 'Pneumonia', 'confidence': 0.85});
        recommendations.addAll([
          'Chest X-ray recommended',
          'Antibiotic therapy may be needed',
          'Monitor oxygen saturation',
        ]);
      } else {
        conditions.add({'name': 'Malaria', 'confidence': 0.78});
        recommendations.addAll([
          'Malaria rapid test recommended',
          'Artemether-Lumefantrine if positive',
          'Paracetamol for fever',
        ]);
      }
    }

    if (symptoms.any((s) => s.toLowerCase().contains('headache'))) {
      conditions.add({'name': 'Hypertension', 'confidence': 0.65});
      recommendations.add('Blood pressure monitoring');
    }

    // Default recommendations
    if (recommendations.isEmpty) {
      recommendations.addAll([
        'Rest and adequate hydration',
        'Monitor symptoms',
        'Return if symptoms worsen',
      ]);
    }

    if (conditions.isEmpty) {
      conditions.add({'name': 'Viral syndrome', 'confidence': 0.60});
    }

    return ConsultationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      timestamp: DateTime.now(),
      chiefComplaint: chiefComplaint,
      symptoms: symptoms,
      vitalSigns: VitalSigns(
        temperature: vitalSigns['temperature'],
        systolicBP: vitalSigns['systolic_bp']?.toInt(),
        diastolicBP: vitalSigns['diastolic_bp']?.toInt(),
        pulseRate: vitalSigns['pulse']?.toInt(),
        respiratoryRate: vitalSigns['respiratory_rate']?.toInt(),
        oxygenSaturation: vitalSigns['oxygen_saturation'],
      ),
      triageLevel: triageLevel,
      suspectedConditions: conditions,
      recommendations: recommendations,
      confidenceScore: conditions.isNotEmpty ? conditions.first['confidence'] : 0.6,
      referralNeeded: triageLevel == 'emergency' || triageLevel == 'urgent',
      followUpRequired: true,
    );
  }

  /// Test AI connectivity
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$streamlitUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}