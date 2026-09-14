import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_patient_model.dart';
import '../models/visit_model.dart';

/// Facility-local patient register and visit history — step 1 of the
/// facility-admin-as-HMS roadmap. Deliberately its own provider, not
/// folded into AdminFacilityProvider (shared with platform-admin screens
/// that have no Patients equivalent) or FacilityAdminProvider
/// (deliberately tiny, "which facility is mine" only). This surface will
/// keep growing as OPD Queue and Billing/Clearance are built on top of
/// the same `visits` table.
class FacilityPatientProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FacilityPatientModel> _patients = [];
  FacilityPatientModel? _selectedPatient;
  List<VisitModel> _selectedPatientVisits = [];
  bool _isLoading = false;
  String? _error;

  List<FacilityPatientModel> get patients => _patients;
  FacilityPatientModel? get selectedPatient => _selectedPatient;
  List<VisitModel> get selectedPatientVisits => _selectedPatientVisits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFacilityPatients(String facilityId, {String? searchTerm}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var query = _supabase.from('facility_patients').select('*').eq('facility_id', facilityId);
      if (searchTerm != null && searchTerm.trim().isNotEmpty) {
        query = query.ilike('full_name', '%${searchTerm.trim()}%');
      }
      final rows = await query.order('created_at', ascending: false).limit(500);

      _patients = (rows as List).map((r) => FacilityPatientModel.fromJson(r as Map<String, dynamic>)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPatientDetail(String facilityPatientId) async {
    _error = null;
    try {
      final patientRow = await _supabase
          .from('facility_patients')
          .select('*')
          .eq('id', facilityPatientId)
          .single();
      _selectedPatient = FacilityPatientModel.fromJson(patientRow);

      final visitRows = await _supabase
          .from('visits')
          .select('*')
          .eq('facility_patient_id', facilityPatientId)
          .order('occurred_at', ascending: false)
          .limit(100);
      _selectedPatientVisits = (visitRows as List).map((r) => VisitModel.fromJson(r as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearSelectedPatient() {
    _selectedPatient = null;
    _selectedPatientVisits = [];
    notifyListeners();
  }

  /// Registers a facility-local walk-in via the checked RPC
  /// (020_facility_patients_and_visits.sql) -- RLS on facility_patients
  /// has no INSERT policy, so a raw insert would be rejected; the RPC is
  /// the real permission boundary (is_facility_admin_of gate) and also
  /// writes the audit_log entry. Returns the new patient's id, or null
  /// on failure.
  Future<String?> registerPatient({
    required String facilityId,
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? phone,
    String? fileNumber,
    String shaStatus = 'unknown',
    String? shaNumber,
    List<String> allergies = const [],
  }) async {
    try {
      final newId = await _supabase.rpc('facility_admin_register_patient', params: {
        'target_facility_id': facilityId,
        'patient_full_name': fullName,
        'patient_date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'patient_gender': gender,
        'patient_phone': phone,
        'patient_file_number': fileNumber,
        'patient_sha_status': shaStatus,
        'patient_sha_number': shaNumber,
        'patient_allergies': allergies,
      }) as String;

      await loadFacilityPatients(facilityId);
      return newId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Registers a visit via the checked RPC, same reasoning as
  /// [registerPatient]. Reloads this patient's visit list on success.
  Future<bool> registerVisit({
    required String facilityPatientId,
    String? chiefComplaint,
    String? notes,
    String? providerId,
  }) async {
    try {
      await _supabase.rpc('facility_admin_register_visit', params: {
        'target_facility_patient_id': facilityPatientId,
        'visit_chief_complaint': chiefComplaint,
        'visit_notes': notes,
        'visit_provider_id': providerId,
      });

      await loadPatientDetail(facilityPatientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
