import 'dart:math';
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

  // Generate temporary access code
  Future<String?> generateAccessCode({
    required String patientId,
    required int hoursValid,
    required List<String> permissions,
  }) async {
    try {
      final code = _generateSecureCode();
      final expiresAt = DateTime.now().add(Duration(hours: hoursValid));

      await _supabase.from('access_codes').insert({
        'patient_id': patientId,
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'permissions': permissions,
        'created_at': DateTime.now().toIso8601String(),
        'is_used': false,
      });

      return code;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  String _generateSecureCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // Verify access code
  Future<Map<String, dynamic>?> verifyAccessCode(String code) async {
    try {
      final response = await _supabase
          .from('access_codes')
          .select('*, patients(*)')
          .eq('code', code)
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .single();

      return response;
    } catch (e) {
      return null;
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
