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
  List<ConsultationModel> _consultations = [];
  String _triageLevel = 'non_urgent';
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _error;

  ConsultationModel? get currentConsultation => _currentConsultation;
  List<Diagnosis> get diagnoses => _diagnoses;
  List<ConsultationModel> get consultations => _consultations;
  String get triageLevel => _triageLevel;

  /// The values consultations.triage_level accepts.
  static const triageLevels = ['emergency', 'urgent', 'less_urgent', 'non_urgent'];
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;

  Future<void> loadConsultationsForProvider(String providerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('consultations')
          .select()
          .eq('provider_id', providerId)
          .order('timestamp', ascending: false)
          .limit(50);
      _consultations = (data as List)
          .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading consultations: $e');
      _error = 'Failed to load consultations. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> analyzeSymptoms({
    required List<String> symptoms,
    required VitalSigns vitalSigns,
    required int patientAge,
    required String patientGender,
  }) async {
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _medicalAI.analyze(
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        age: patientAge,
        gender: patientGender,
      );

      _diagnoses = result['diagnoses'] as List<Diagnosis>;
      _triageLevel = result['triage_level'] as String;
    } catch (e) {
      debugPrint('Error analyzing symptoms: $e');
      _error = 'Failed to analyze symptoms. Please try again.';
    }

    _isAnalyzing = false;
    notifyListeners();
  }

  Future<String?> saveConsultation({
    required String patientId,
    required String providerId,
    required String chiefComplaint,
    required List<String> symptoms,
    required VitalSigns vitalSigns,
    required List<String> recommendations,
    String? notes,
    bool followUpRequired = false,
    DateTime? followUpDate,
    String? triageLevel,
    List<Diagnosis>? diagnoses,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // The consultation screen runs its own analysis, so its triage and
    // diagnoses are passed in; without them every consultation was saved
    // as non-urgent with no diagnoses, whatever the analysis found.
    final triage = triageLevels.contains(triageLevel) ? triageLevel! : _triageLevel;

    try {
      final consultation = ConsultationModel(
        id: const Uuid().v4(),
        patientId: patientId,
        providerId: providerId,
        timestamp: DateTime.now(),
        chiefComplaint: chiefComplaint,
        symptoms: symptoms,
        vitalSigns: vitalSigns,
        triageLevel: triage,
        diagnoses: diagnoses ?? _diagnoses,
        recommendations: recommendations,
        notes: notes,
        followUpRequired: followUpRequired,
        followUpDate: followUpDate,
      );

      await _supabase.from('consultations').insert(consultation.toJson());

      // The consultation is saved at this point. A failed audit entry
      // must not report it as unsaved: the doctor would save it again.
      try {
        await _supabase.from('audit_log').insert({
          'action': 'consultation_created',
          'user_id': providerId,
          'patient_id': patientId,
          'details': {'consultation_id': consultation.id},
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Consultation saved, but its audit entry failed: $e');
      }

      _currentConsultation = consultation;
      _isLoading = false;
      notifyListeners();
      return consultation.id;
    } catch (e) {
      debugPrint('Error saving consultation: $e');
      _error = 'Failed to save consultation. Please try again.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void clearConsultation() {
    _currentConsultation = null;
    _diagnoses = [];
    _triageLevel = 'non_urgent';
    _error = null;
    notifyListeners();
  }
}
