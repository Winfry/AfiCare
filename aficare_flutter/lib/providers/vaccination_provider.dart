import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/vaccination_model.dart';

class VaccinationProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<VaccinationRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<VaccinationRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get completedCount => _records.where((r) => r.status == 'completed').length;

  Future<void> loadRecords(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('vaccination_records')
          .select()
          .eq('patient_id', patientId)
          .order('date_given', ascending: false);
      _records = (data as List)
          .map((j) => VaccinationRecord.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading vaccination records: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addRecord({
    required String patientId,
    required String vaccineName,
    String? vaccineType,
    required DateTime dateGiven,
    DateTime? nextDueDate,
    String? facility,
    String? batchNumber,
    String? administeredBy,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final record = VaccinationRecord(
        id: const Uuid().v4(),
        patientId: patientId,
        vaccineName: vaccineName,
        vaccineType: vaccineType,
        dateGiven: dateGiven,
        nextDueDate: nextDueDate,
        facility: facility,
        batchNumber: batchNumber,
        administeredBy: administeredBy,
        status: 'completed',
        notes: notes,
      );

      await _supabase.from('vaccination_records').insert(record.toJson());
      _records.insert(0, record);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<VaccineSchedule> getDueVaccines(int ageWeeks) {
    final administered = _records.map((r) => r.vaccineName).toSet();
    return VaccinationSchedule.kenyaEPI.where((schedule) {
      if (ageWeeks < schedule.minAgeWeeks) return false;
      final alreadyGiven = administered.any((name) =>
          name.toLowerCase().contains(schedule.type.toLowerCase()));
      return !alreadyGiven;
    }).toList();
  }
}
