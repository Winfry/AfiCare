import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';

class AppointmentProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAppointments(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('appointments')
          .select()
          .eq('patient_id', patientId)
          .order('scheduled_at', ascending: false);

      _appointments = (response as List)
          .map((json) => AppointmentModel.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProviderAppointments(String providerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('appointments')
          .select()
          .eq('provider_id', providerId)
          .order('scheduled_at', ascending: false);

      _appointments = (response as List)
          .map((json) => AppointmentModel.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> bookAppointment(AppointmentModel appointment) async {
    try {
      final data = appointment.toJson();
      data.remove('id');
      await _supabase.from('appointments').insert(data);
      await loadAppointments(appointment.patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus(String id, AppointmentStatus status) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': _statusToString(status)})
          .eq('id', id);
      final idx = _appointments.indexWhere((a) => a.id == id);
      if (idx != -1) {
        _appointments[idx] = _appointments[idx].copyWith(status: status);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  String _statusToString(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed:
        return 'confirmed';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.pending:
        return 'pending';
    }
  }
}
