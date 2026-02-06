import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/consultation_model.dart';
import '../services/medical_ai_service.dart';

class ConsultationProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MedicalAIService _medicalAI = MedicalAIService();

  ConsultationModel? _currentConsultation;
  List<Diagnosis> _diagnoses = [];
  String _triageLevel = 'non_urgent';
  bool _isAnalyzing = false;

  ConsultationModel? get currentConsultation => _currentConsultation;
  List<Diagnosis> get diagnoses => _diagnoses;
  String get triageLevel => _triageLevel;
  bool get isAnalyzing => _isAnalyzing;

  // Analyze symptoms using rule-based AI
  Future<void> analyzeSymptoms({
    required List<String> symptoms,
    required VitalSigns vitalSigns,
    required int patientAge,
    required String patientGender,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      // Use the medical AI service
      final result = await _medicalAI.analyze(
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: patientAge,
        gender: patientGender,
      );

      _diagnoses = result['diagnoses'] as List<Diagnosis>;
      _triageLevel = result['triage_level'] as String;

      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // Save consultation
  Future<bool> saveConsultation({
    required String patientId,
    required String providerId,
    required String chiefComplaint,
    required List<String> symptoms,
    required VitalSigns vitalSigns,
    required List<String> recommendations,
    String? notes,
    bool followUpRequired = false,
    DateTime? followUpDate,
  }) async {
    try {
      final consultation = ConsultationModel(
        id: const Uuid().v4(),
        patientId: patientId,
        providerId: providerId,
        timestamp: DateTime.now(),
        chiefComplaint: chiefComplaint,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        triageLevel: _triageLevel,
        diagnoses: _diagnoses,
        recommendations: recommendations,
        notes: notes,
        followUpRequired: followUpRequired,
        followUpDate: followUpDate,
      );

      await _supabase.from('consultations').insert(consultation.toJson());

      // Log to audit
      await _supabase.from('audit_log').insert({
        'action': 'consultation_created',
        'user_id': providerId,
        'patient_id': patientId,
        'details': {'consultation_id': consultation.id},
        'timestamp': DateTime.now().toIso8601String(),
      });

      _currentConsultation = consultation;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving consultation: $e');
      return false;
    }
  }

  // Clear current consultation
  void clearConsultation() {
    _currentConsultation = null;
    _diagnoses = [];
    _triageLevel = 'non_urgent';
    notifyListeners();
  }
}
