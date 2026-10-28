import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consultation_model.dart';

class PatientProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ConsultationModel> _consultations = [];
  bool _isLoading = false;
  String? _error;

  List<ConsultationModel> get consultations => _consultations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load patient data (wrapper for loadConsultations)
  Future<void> loadPatientData() async {
    // This method is called without patient ID, so we just notify listeners
    // The actual data loading happens via loadConsultations when patient ID is available
    notifyListeners();
  }

  // Load patient consultations
  Future<void> loadConsultations(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('consultations')
          .select()
          .eq('patient_id', patientId)
          .order('timestamp', ascending: false);

      _consultations = (response as List)
          .map((json) => ConsultationModel.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get health summary stats
  Map<String, dynamic> getHealthStats() {
    return {
      'totalVisits': _consultations.length,
      'lastVisit': _consultations.isNotEmpty
          ? _consultations.first.timestamp
          : null,
      'followUpsNeeded': _consultations
          .where((c) => c.followUpRequired && c.followUpDate != null)
          .length,
    };
  }
}
