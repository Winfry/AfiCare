import 'package:flutter/foundation.dart';
import '../models/medication_reminder_model.dart';
import '../services/medication_reminder_service.dart';

class MedicationReminderProvider with ChangeNotifier {
  final MedicationReminderService _service = MedicationReminderService();

  List<MedicationReminder> _reminders = [];
  bool _isLoading = false;
  String? _error;

  List<MedicationReminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MedicationReminder> get activeReminders =>
      _reminders.where((r) => r.isActive).toList();

  int get todaysCount => activeReminders.length;

  Future<void> loadReminders(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _reminders = await _service.loadReminders(patientId);

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveReminder({
    required String patientId,
    required String medicationName,
    required String dosage,
    required String frequency,
    required List<ReminderTime> times,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? prescriptionId,
    String? existingId,
  }) async {
    final result = await _service.saveReminder(
      patientId: patientId,
      medicationName: medicationName,
      dosage: dosage,
      frequency: frequency,
      times: times,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      prescriptionId: prescriptionId,
      existingId: existingId,
    );

    if (result != null) {
      if (existingId != null) {
        final idx = _reminders.indexWhere((r) => r.id == existingId);
        if (idx >= 0) _reminders[idx] = result;
      } else {
        _reminders.insert(0, result);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> toggleReminder(String reminderId, bool isActive) async {
    await _service.toggleReminder(reminderId, isActive);
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx >= 0) {
      _reminders[idx] = MedicationReminder(
        id: _reminders[idx].id,
        patientId: _reminders[idx].patientId,
        medicationName: _reminders[idx].medicationName,
        dosage: _reminders[idx].dosage,
        frequency: _reminders[idx].frequency,
        times: _reminders[idx].times,
        isActive: isActive,
        startDate: _reminders[idx].startDate,
        endDate: _reminders[idx].endDate,
        notes: _reminders[idx].notes,
        prescriptionId: _reminders[idx].prescriptionId,
        createdAt: _reminders[idx].createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    await _service.deleteReminder(reminderId);
    _reminders.removeWhere((r) => r.id == reminderId);
    notifyListeners();
  }
}
