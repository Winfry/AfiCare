import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/anc_visit_model.dart';

class AncProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AncVisit> _visits = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _estimatedDueDate;
  DateTime? _lastMenstrualPeriod;

  List<AncVisit> get visits => _visits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get estimatedDueDate => _estimatedDueDate;
  DateTime? get lastMenstrualPeriod => _lastMenstrualPeriod;

  int get completedVisits => _visits.length;

  int get currentGestationalWeeks {
    if (_lastMenstrualPeriod == null) return 0;
    final diff = DateTime.now().difference(_lastMenstrualPeriod!);
    return (diff.inDays / 7).floor();
  }

  String get currentTrimester => AncVisit.trimesterFromWeeks(currentGestationalWeeks);

  List<String> get activeDangerSigns {
    if (_visits.isEmpty) return [];
    final latest = _visits.first;
    return latest.dangerSigns;
  }

  static const int recommendedVisitWeeks = 4; // every 4 weeks

  int get expectedVisitCount {
    final weeks = currentGestationalWeeks;
    if (weeks <= 0) return 0;
    return (weeks / recommendedVisitWeeks).ceil();
  }

  double get visitCompletionRate {
    if (expectedVisitCount == 0) return 0;
    return completedVisits / expectedVisitCount;
  }

  Future<void> loadVisits(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('anc_visits')
          .select()
          .eq('patient_id', patientId)
          .order('visit_date', ascending: false);
      _visits = (data as List)
          .map((j) => AncVisit.fromJson(j))
          .toList();

      // Try to load pregnancy info from patient metadata
      try {
        final patient = await _supabase
            .from('patients')
            .select('date_of_birth, notes')
            .eq('id', patientId)
            .maybeSingle();
        if (patient != null && patient['notes'] != null) {
          final notes = patient['notes'] as String?;
          if (notes != null && notes.contains('lmp:')) {
            final lmpStr = notes.split('lmp:')[1].split(';')[0].trim();
            _lastMenstrualPeriod = DateTime.tryParse(lmpStr);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading ANC visits: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setLMP(String patientId, DateTime lmp) async {
    _lastMenstrualPeriod = lmp;
    _estimatedDueDate = lmp.add(const Duration(days: 280));
    notifyListeners();

    try {
      await _supabase.from('patients').upsert({
        'id': patientId,
        'notes': 'lmp: ${lmp.toIso8601String()};',
      });
    } catch (e) {
      debugPrint('Error saving LMP: $e');
    }
  }

  Future<bool> addVisit({
    required String patientId,
    required int visitNumber,
    required int gestationalWeeks,
    required DateTime visitDate,
    double? fundalHeight,
    int? fetalHeartRate,
    int? systolicBP,
    int? diastolicBP,
    double? weight,
    double? hemoglobin,
    String? urineProtein,
    String? urineGlucose,
    bool? hivTested,
    String? hivResult,
    String? notes,
    List<String>? dangerSigns,
    String? nextVisitDate,
    String? facility,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final visit = AncVisit(
        id: const Uuid().v4(),
        patientId: patientId,
        visitNumber: visitNumber,
        gestationalWeeks: gestationalWeeks,
        trimester: AncVisit.trimesterFromWeeks(gestationalWeeks),
        visitDate: visitDate,
        fundalHeight: fundalHeight,
        fetalHeartRate: fetalHeartRate,
        systolicBP: systolicBP,
        diastolicBP: diastolicBP,
        weight: weight,
        hemoglobin: hemoglobin,
        urineProtein: urineProtein,
        urineGlucose: urineGlucose,
        hivTested: hivTested,
        hivResult: hivResult,
        notes: notes,
        dangerSigns: dangerSigns ?? [],
        nextVisitDate: nextVisitDate,
        facility: facility ?? '',
      );

      await _supabase.from('anc_visits').insert(visit.toJson());
      _visits.insert(0, visit);
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
}
