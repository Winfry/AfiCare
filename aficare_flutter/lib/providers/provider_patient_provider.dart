import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consultation_model.dart';
import '../models/lab_model.dart';
import '../models/prescription_model.dart';
import '../models/radiology_model.dart';
import '../models/triage_model.dart';
import '../models/referral_model.dart';

class ProviderPatientProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Search results
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Loaded patient detail
  Map<String, dynamic>? _patientProfile;
  List<ConsultationModel> _consultations = [];
  List<TriageAssessment> _triageAssessments = [];
  List<LabOrderModel> _labOrders = [];
  List<RadiologyOrderModel> _radiologyOrders = [];
  List<PrescriptionModel> _prescriptions = [];
  List<ReferralModel> _referrals = [];

  bool _isLoadingPatient = false;
  String? _error;

  // Getters
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  Map<String, dynamic>? get patientProfile => _patientProfile;
  List<ConsultationModel> get consultations => _consultations;
  List<TriageAssessment> get triageAssessments => _triageAssessments;
  List<LabOrderModel> get labOrders => _labOrders;
  List<RadiologyOrderModel> get radiologyOrders => _radiologyOrders;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  List<ReferralModel> get referrals => _referrals;
  bool get isLoadingPatient => _isLoadingPatient;
  String? get error => _error;

  Future<void> searchPatients(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final q = query.toLowerCase();
      final response = await _supabase
          .from('users')
          .select('id, full_name, medilink_id, phone, created_at')
          .eq('role', 'patient')
          .or(
            'full_name.ilike.%$q%,medilink_id.ilike.%$q%',
          )
          .limit(20);

      _searchResults = List<Map<String, dynamic>>.from(response as List);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> loadPatientDetail(String patientId) async {
    _isLoadingPatient = true;
    _error = null;
    _patientProfile = null;
    _consultations = [];
    _triageAssessments = [];
    _labOrders = [];
    _radiologyOrders = [];
    _prescriptions = [];
    _referrals = [];
    notifyListeners();

    try {
      // Profile
      final userResp = await _supabase
          .from('users')
          .select('id, full_name, medilink_id, phone, email, gender, created_at')
          .eq('id', patientId)
          .single();
      _patientProfile = Map<String, dynamic>.from(userResp);

      try {
        final patientResp = await _supabase
            .from('patients')
            .select('date_of_birth, blood_type, allergies, chronic_conditions, emergency_contact')
            .eq('id', patientId)
            .single();
        _patientProfile!.addAll(Map<String, dynamic>.from(patientResp));
      } catch (_) {}

      // Consultations
      try {
        final consResp = await _supabase
            .from('consultations')
            .select()
            .eq('patient_id', patientId)
            .order('timestamp', ascending: false);
        _consultations = (consResp as List)
            .map((j) => ConsultationModel.fromJson(j))
            .toList();
      } catch (_) {}

      // Triage
      try {
        final triResp = await _supabase
            .from('triage_assessments')
            .select()
            .eq('patient_id', patientId)
            .order('assessed_at', ascending: false);
        _triageAssessments = (triResp as List)
            .map((j) => TriageAssessment.fromJson(j))
            .toList();
      } catch (_) {}

      // Labs
      try {
        final labResp = await _supabase
            .from('lab_orders')
            .select('*, lab_results(*)')
            .eq('patient_id', patientId)
            .order('ordered_at', ascending: false);
        _labOrders = (labResp as List)
            .map((j) => LabOrderModel.fromJson(j))
            .toList();
      } catch (_) {}

      // Radiology
      try {
        final radResp = await _supabase
            .from('radiology_orders')
            .select('*, radiology_reports(*)')
            .eq('patient_id', patientId)
            .order('ordered_at', ascending: false);
        _radiologyOrders = (radResp as List)
            .map((j) => RadiologyOrderModel.fromJson(j))
            .toList();
      } catch (_) {}

      // Prescriptions
      try {
        final rxResp = await _supabase
            .from('prescriptions')
            .select()
            .eq('patient_id', patientId)
            .order('issued_at', ascending: false);
        _prescriptions = (rxResp as List)
            .map((j) => PrescriptionModel.fromJson(j))
            .toList();
      } catch (_) {}

      // Referrals
      try {
        final refResp = await _supabase
            .from('referrals')
            .select()
            .eq('patient_id', patientId)
            .order('created_at', ascending: false);
        _referrals = (refResp as List)
            .map((j) => ReferralModel.fromJson(j))
            .toList();
      } catch (_) {}

      _isLoadingPatient = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingPatient = false;
      notifyListeners();
    }
  }

  void clear() {
    _searchResults = [];
    _patientProfile = null;
    _consultations = [];
    _triageAssessments = [];
    _labOrders = [];
    _radiologyOrders = [];
    _prescriptions = [];
    _referrals = [];
    _error = null;
    notifyListeners();
  }
}
