import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription_model.dart';

class PrescriptionProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<PrescriptionModel> _prescriptions = [];
  bool _isLoading = false;
  String? _error;

  List<PrescriptionModel> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

      _prescriptions = (response as List)
          .map((json) => PrescriptionModel.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
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
