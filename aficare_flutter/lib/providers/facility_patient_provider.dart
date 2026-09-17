import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clearance_row_model.dart';
import '../models/facility_patient_model.dart';
import '../models/lab_order_row_model.dart';
import '../models/patient_appointment_row_model.dart';
import '../models/prescription_row_model.dart';
import '../models/queue_row_model.dart';
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
  List<PatientAppointmentRowModel> _selectedPatientAppointments = [];
  List<QueueRowModel> _activeVisits = [];
  List<ClearanceRowModel> _clearanceVisits = [];
  List<LabOrderRowModel> _labOrders = [];
  List<PrescriptionRowModel> _prescriptions = [];
  bool _isLoading = false;
  String? _error;

  List<FacilityPatientModel> get patients => _patients;
  FacilityPatientModel? get selectedPatient => _selectedPatient;
  List<VisitModel> get selectedPatientVisits => _selectedPatientVisits;
  List<PatientAppointmentRowModel> get selectedPatientAppointments => _selectedPatientAppointments;
  List<QueueRowModel> get activeVisits => _activeVisits;
  List<ClearanceRowModel> get clearanceVisits => _clearanceVisits;
  List<LabOrderRowModel> get labOrders => _labOrders;
  List<PrescriptionRowModel> get prescriptions => _prescriptions;
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
    _selectedPatientAppointments = [];
    notifyListeners();
  }

  /// Loads one patient's appointment history via the `appointments` table
  /// (the app-account booking system) -- entirely separate from
  /// `visits` (the facility-local walk-in log). Only works when this
  /// facility_patient is linked to a real AfiCare account
  /// (`linkedUserId` non-null); nothing in the app populates that link
  /// yet (see 020_facility_patients_and_visits.sql's header comment), so
  /// for virtually every patient today this returns an empty list
  /// without querying -- deliberately called lazily (only when the
  /// Appointments sub-tab is opened), not chained into loadPatientDetail,
  /// so that near-universal null case never fires a wasted round trip.
  Future<void> loadPatientAppointments(String facilityId, String? linkedUserId) async {
    if (linkedUserId == null) {
      _selectedPatientAppointments = [];
      notifyListeners();
      return;
    }
    _error = null;
    try {
      final rows = await _supabase
          .from('appointments')
          .select('id, provider_id, scheduled_at, status')
          .eq('patient_id', linkedUserId)
          .eq('facility_id', facilityId)
          .order('scheduled_at', ascending: false)
          .limit(100);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _selectedPatientAppointments = [];
        notifyListeners();
        return;
      }

      final providerIds = {for (final r in list) r['provider_id'] as String}.toList();
      final providerRows = await _supabase
          .from('users')
          .select('id, full_name')
          .inFilter('id', providerIds);

      final nameById = <String, String>{
        for (final u in (providerRows as List)) (u as Map<String, dynamic>)['id'] as String: u['full_name'] as String? ?? 'Unknown',
      };

      _selectedPatientAppointments = list
          .map((r) => PatientAppointmentRowModel.fromJson(r, providerName: nameById[r['provider_id']]))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Loads today's active OPD Queue board for the whole facility --
  /// waiting/triage/in_consultation (all statuses, no date bound; a
  /// patient can sit "with doctor" across a shift boundary) plus
  /// completed visits from TODAY only (bounded so the Completed tally
  /// doesn't grow unboundedly over the facility's whole history).
  /// 'registered' (a plain Patients-tab visit, no queue intent) and
  /// 'cancelled' are deliberately excluded -- see
  /// 021_opd_queue.sql's header comment. 2-query pattern (no embedded
  /// joins), same convention as AdminFacilityProvider.loadFacilityAppointments.
  Future<void> loadActiveVisits(String facilityId) async {
    _error = null;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // Date bound applies only to 'completed' (so the tally doesn't grow
      // unboundedly across the facility's whole history) -- waiting/
      // triage/in_consultation stay unbounded, since a visit can
      // legitimately still be active from before midnight.
      final rows = await _supabase
          .from('visits')
          .select('*')
          .eq('facility_id', facilityId)
          .or('status.in.(waiting,triage,in_consultation),and(status.eq.completed,occurred_at.gte.$todayStart)')
          .order('status_changed_at', ascending: true)
          .limit(300);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _activeVisits = [];
        notifyListeners();
        return;
      }

      final patientIds = {for (final r in list) r['facility_patient_id'] as String}.toList();
      final patientRows = await _supabase
          .from('facility_patients')
          .select('id, full_name, file_number')
          .inFilter('id', patientIds);

      final patientById = <String, Map<String, dynamic>>{
        for (final p in (patientRows as List)) p['id'] as String: p as Map<String, dynamic>,
      };

      _activeVisits = list.map((v) {
        final p = patientById[v['facility_patient_id']];
        return QueueRowModel.fromVisitJson(
          v,
          patientName: p?['full_name'] as String?,
          patientFileNumber: p?['file_number'] as String?,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Advances (or re-prioritizes) a queued visit via the checked RPC
  /// (021_opd_queue.sql) -- deliberately does not reload here; the OPD
  /// Queue screen already has facilityId in scope and calls
  /// loadActiveVisits itself right after, so one stage-advance triggers
  /// exactly one reload instead of two.
  Future<bool> updateVisitStatus({
    required String visitId,
    required String newStatus,
    String? newPriority,
  }) async {
    try {
      await _supabase.rpc('facility_admin_update_visit_status', params: {
        'target_visit_id': visitId,
        'new_status': newStatus,
        'new_priority': newPriority,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads today's Billing & Clearance ledger for the whole facility --
  /// a flat list of today's visits (not restricted to queue-stage
  /// statuses like loadActiveVisits), excluding cancelled. Every visit
  /// already carries clearance state (eligibility_status defaults to
  /// 'pending' -- see 022_billing_clearance.sql), so there is no
  /// separate "add to billing" step. Same 2-query client-side join
  /// pattern as loadActiveVisits.
  Future<void> loadClearanceVisits(String facilityId) async {
    _error = null;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final rows = await _supabase
          .from('visits')
          .select('*')
          .eq('facility_id', facilityId)
          .neq('status', 'cancelled')
          .gte('occurred_at', todayStart)
          .order('occurred_at', ascending: false)
          .limit(300);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _clearanceVisits = [];
        notifyListeners();
        return;
      }

      final patientIds = {for (final r in list) r['facility_patient_id'] as String}.toList();
      final patientRows = await _supabase
          .from('facility_patients')
          .select('id, full_name, file_number')
          .inFilter('id', patientIds);

      final patientById = <String, Map<String, dynamic>>{
        for (final p in (patientRows as List)) p['id'] as String: p as Map<String, dynamic>,
      };

      _clearanceVisits = list.map((v) {
        final p = patientById[v['facility_patient_id']];
        return ClearanceRowModel.fromVisitJson(
          v,
          patientName: p?['full_name'] as String?,
          patientFileNumber: p?['file_number'] as String?,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Sets payer/eligibility on a visit via the checked RPC
  /// (022_billing_clearance.sql) -- deliberately does not reload here,
  /// same convention as updateVisitStatus (the Billing & Clearance
  /// screen calls loadClearanceVisits itself right after).
  Future<bool> updateVisitClearance({
    required String visitId,
    String? newPayerType,
    String? newEligibilityStatus,
  }) async {
    try {
      await _supabase.rpc('facility_admin_update_visit_clearance', params: {
        'target_visit_id': visitId,
        'new_payer_type': newPayerType,
        'new_eligibility_status': newEligibilityStatus,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads today's Laboratory board for the whole facility -- a flat
  /// ledger of today's lab orders (all statuses, like loadClearanceVisits,
  /// not filtered to "active" like loadActiveVisits), oldest-first so the
  /// most overdue-prone orders surface first. 3-query pattern (one more
  /// than the other boards): visit_lab_orders, then facility_patients for
  /// names, then users for the ordering provider's name (same pattern
  /// loadPatientAppointments already uses for provider names) -- needed
  /// because facility_id/facility_patient_id/provider_id are denormalized
  /// snapshots on visit_lab_orders itself (see 024_visit_lab_orders.sql),
  /// so no join through `visits` is required.
  Future<void> loadLabOrders(String facilityId) async {
    _error = null;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final rows = await _supabase
          .from('visit_lab_orders')
          .select('*')
          .eq('facility_id', facilityId)
          .gte('ordered_at', todayStart)
          .order('ordered_at', ascending: true)
          .limit(300);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _labOrders = [];
        notifyListeners();
        return;
      }

      final patientIds = {for (final r in list) r['facility_patient_id'] as String}.toList();
      final patientRows = await _supabase
          .from('facility_patients')
          .select('id, full_name, file_number')
          .inFilter('id', patientIds);

      final patientById = <String, Map<String, dynamic>>{
        for (final p in (patientRows as List)) p['id'] as String: p as Map<String, dynamic>,
      };

      final providerIds = {for (final r in list) if (r['provider_id'] != null) r['provider_id'] as String}.toList();
      final nameByProviderId = <String, String>{};
      if (providerIds.isNotEmpty) {
        final providerRows = await _supabase
            .from('users')
            .select('id, full_name')
            .inFilter('id', providerIds);
        for (final u in (providerRows as List)) {
          final m = u as Map<String, dynamic>;
          nameByProviderId[m['id'] as String] = m['full_name'] as String? ?? 'Unknown';
        }
      }

      _labOrders = list.map((r) {
        final p = patientById[r['facility_patient_id']];
        return LabOrderRowModel.fromJson(
          r,
          patientName: p?['full_name'] as String?,
          patientFileNumber: p?['file_number'] as String?,
          orderedByName: r['provider_id'] == null ? 'Unassigned' : nameByProviderId[r['provider_id']],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Places a lab order for a visit via the checked RPC
  /// (024_visit_lab_orders.sql) -- deliberately does not reload here,
  /// same convention as registerVisit/updateVisitClearance (the
  /// Laboratory screen calls loadLabOrders itself right after). Returns
  /// the new lab order's id, or null on failure.
  Future<String?> placeLabOrder({
    required String visitId,
    required String testName,
  }) async {
    try {
      final newId = await _supabase.rpc('facility_admin_place_lab_order', params: {
        'target_visit_id': visitId,
        'order_test_name': testName,
      }) as String;
      return newId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Advances a lab order's status via the checked RPC
  /// (024_visit_lab_orders.sql) -- deliberately does not reload here,
  /// same convention as updateVisitStatus.
  Future<bool> updateLabOrderStatus({
    required String labOrderId,
    required String newStatus,
  }) async {
    try {
      await _supabase.rpc('facility_admin_update_lab_order_status', params: {
        'target_lab_order_id': labOrderId,
        'new_status': newStatus,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Loads today's Pharmacy & Stock "Prescriptions" board for the whole
  /// facility -- a flat ledger of today's prescriptions (pending +
  /// dispensed), oldest-first. Same 3-query pattern as loadLabOrders:
  /// visit_prescriptions, then facility_patients for names, then users
  /// for the prescribing provider's name.
  Future<void> loadPrescriptions(String facilityId) async {
    _error = null;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final rows = await _supabase
          .from('visit_prescriptions')
          .select('*')
          .eq('facility_id', facilityId)
          .gte('prescribed_at', todayStart)
          .order('prescribed_at', ascending: true)
          .limit(300);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _prescriptions = [];
        notifyListeners();
        return;
      }

      final patientIds = {for (final r in list) r['facility_patient_id'] as String}.toList();
      final patientRows = await _supabase
          .from('facility_patients')
          .select('id, full_name, file_number')
          .inFilter('id', patientIds);

      final patientById = <String, Map<String, dynamic>>{
        for (final p in (patientRows as List)) p['id'] as String: p as Map<String, dynamic>,
      };

      final providerIds = {for (final r in list) if (r['provider_id'] != null) r['provider_id'] as String}.toList();
      final nameByProviderId = <String, String>{};
      if (providerIds.isNotEmpty) {
        final providerRows = await _supabase
            .from('users')
            .select('id, full_name')
            .inFilter('id', providerIds);
        for (final u in (providerRows as List)) {
          final m = u as Map<String, dynamic>;
          nameByProviderId[m['id'] as String] = m['full_name'] as String? ?? 'Unknown';
        }
      }

      _prescriptions = list.map((r) {
        final p = patientById[r['facility_patient_id']];
        return PrescriptionRowModel.fromJson(
          r,
          patientName: p?['full_name'] as String?,
          patientFileNumber: p?['file_number'] as String?,
          prescribedByName: r['provider_id'] == null ? 'Unassigned' : nameByProviderId[r['provider_id']],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Places a prescription for a visit via the checked RPC
  /// (025_pharmacy_stock.sql) -- deliberately does not reload here, same
  /// convention as placeLabOrder (the Pharmacy screen calls
  /// loadPrescriptions itself right after). Returns the new
  /// prescription's id, or null on failure.
  Future<String?> placePrescription({
    required String visitId,
    required String drugStockId,
    required String medicationLabel,
  }) async {
    try {
      final newId = await _supabase.rpc('facility_admin_place_prescription', params: {
        'target_visit_id': visitId,
        'target_drug_stock_id': drugStockId,
        'new_medication_label': medicationLabel,
      }) as String;
      return newId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
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
  /// [status]/[priority] are optional -- omitted, the RPC defaults to
  /// 'registered'/'routine' (a plain visit, not queued). OPD Queue's
  /// "add to queue" flow passes status: 'waiting' to put a new walk-in
  /// straight on the board in one call, no separate updateVisitStatus
  /// round trip needed.
  Future<bool> registerVisit({
    required String facilityPatientId,
    String? chiefComplaint,
    String? notes,
    String? providerId,
    String? status,
    String? priority,
    int? bpSystolic,
    int? bpDiastolic,
    double? weightKg,
    double? temperatureC,
  }) async {
    try {
      await _supabase.rpc('facility_admin_register_visit', params: {
        'target_facility_patient_id': facilityPatientId,
        'visit_chief_complaint': chiefComplaint,
        'visit_notes': notes,
        'visit_provider_id': providerId,
        'visit_status': status,
        'visit_priority': priority,
        'visit_bp_systolic': bpSystolic,
        'visit_bp_diastolic': bpDiastolic,
        'visit_weight_kg': weightKg,
        'visit_temperature_c': temperatureC,
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
