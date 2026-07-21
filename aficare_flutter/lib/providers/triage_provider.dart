import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/triage_model.dart';

class TriageProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<TriageAssessment> _assessments = [];
  bool _isLoading = false;
  String? _error;

  List<TriageAssessment> get assessments => _assessments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAssessments(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('triage_assessments')
          .select()
          .eq('patient_id', patientId)
          .order('assessed_at', ascending: false);

      _assessments = (response as List)
          .map((json) => TriageAssessment.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProviderAssessments(String providerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('triage_assessments')
          .select()
          .eq('provider_id', providerId)
          .order('assessed_at', ascending: false);

      _assessments = (response as List)
          .map((json) => TriageAssessment.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitAssessment(TriageAssessment assessment) async {
    try {
      await _supabase.from('triage_assessments').insert(assessment.toJson());
      _assessments.insert(0, assessment);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  TriageAssessment? getLatestAssessment(String patientId) {
    final patientAssessments = _assessments
        .where((a) => a.patientId == patientId)
        .toList()
      ..sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
    return patientAssessments.isNotEmpty ? patientAssessments.first : null;
  }
}
