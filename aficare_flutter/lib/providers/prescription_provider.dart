import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription_model.dart';
import '../services/offline_cache.dart';

class PrescriptionProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<PrescriptionModel> _prescriptions = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _fromCacheAt;

  List<PrescriptionModel> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// When the current list came from the on-device copy rather than the
  /// server, the time that copy was saved. Null when the list is live.
  DateTime? get fromCacheAt => _fromCacheAt;

  List<PrescriptionModel> getActivePrescriptions() =>
      _prescriptions.where((p) => p.status == PrescriptionStatus.active).toList();

  Future<void> loadPrescriptions(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('prescriptions')
          .select()
          .eq('patient_id', patientId)
          .order('issued_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _prescriptions = rows.map((json) => PrescriptionModel.fromJson(json)).toList();

      // Keep a copy: what someone is taking is the single most useful
      // thing to have on hand without a connection.
      await OfflineCache.save(OfflineCache.medicationsKey(patientId), rows);
      _fromCacheAt = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      // Fall back to the last known list rather than showing nothing: a
      // patient reading "no medications" may conclude they have none.
      final cached = OfflineCache.readList(OfflineCache.medicationsKey(patientId));
      if (cached != null) {
        try {
          _prescriptions = cached.rows.map((j) => PrescriptionModel.fromJson(j)).toList();
          _fromCacheAt = cached.savedAt;
        } catch (err) {
          debugPrint('prescription_provider: cached list unreadable: $err');
          _fromCacheAt = null;
        }
      } else {
        _fromCacheAt = null;
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPrescription(PrescriptionModel prescription) async {
    try {
      final data = prescription.toJson();
      data.remove('id');
      await _supabase.from('prescriptions').insert(data);
      await loadPrescriptions(prescription.patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update the status of a prescription (e.g. active → completed / cancelled).
  /// Used by providers to close out prescriptions.
  Future<bool> updateStatus(String id, PrescriptionStatus status) async {
    try {
      await _supabase
          .from('prescriptions')
          .update({'status': status.name})
          .eq('id', id);
      // Optimistic update in local list
      final idx = _prescriptions.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _prescriptions[idx] = _prescriptions[idx].copyWith(status: status);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
