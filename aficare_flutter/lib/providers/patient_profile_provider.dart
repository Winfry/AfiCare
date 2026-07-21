import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient_profile_model.dart';

class PatientProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  PatientProfileModel? _profile;
  bool _isLoading = false;
  String? _error;

  PatientProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProfile(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('patients')
          .select()
          .eq('id', patientId)
          .maybeSingle();

      if (response != null) {
        _profile = PatientProfileModel.fromJson(response);
      } else {
        // No row yet — start with an empty profile for this patient.
        _profile = PatientProfileModel(id: patientId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _profile = PatientProfileModel(id: patientId);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upsert the patient profile row (insert if absent, update otherwise).
  Future<bool> saveProfile(PatientProfileModel profile) async {
    try {
      await _supabase.from('patients').upsert(profile.toJson());
      _profile = profile;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
