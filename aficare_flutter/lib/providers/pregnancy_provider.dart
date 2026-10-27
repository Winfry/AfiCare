import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/anc_visit_model.dart';
import '../models/pregnancy_model.dart';

/// The signed-in woman's pregnancies and antenatal (ANC) visits, shared by
/// Maternal care and Women's health so the two pages always agree.
///
/// Writes ask for the stored row back: when row-level security refuses a
/// write, Postgres can report success with zero rows, and a save that
/// never happened must not look like one that did.
class PregnancyProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _patientId;
  List<Pregnancy> _pregnancies = [];
  List<AncVisit> _visits = [];
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;

  bool get isLoading => _isLoading;

  /// True once a load for the current person has finished, even if it
  /// failed (then [error] says so).
  bool get loaded => _loaded;
  String? get error => _error;

  /// Newest first.
  List<Pregnancy> get pregnancies => List.unmodifiable(_pregnancies);

  Pregnancy? get current {
    for (final p in _pregnancies) {
      if (p.isOngoing) return p;
    }
    return null;
  }

  List<Pregnancy> get past => _pregnancies.where((p) => !p.isOngoing).toList();

  /// Most recently ended pregnancy, if any.
  Pregnancy? get lastEnded {
    final ended = past.where((p) => p.endedOn != null).toList()
      ..sort((a, b) => b.endedOn!.compareTo(a.endedOn!));
    return ended.isEmpty ? null : ended.first;
  }

  /// The visits of [pregnancy], newest first.
  List<AncVisit> visitsOf(Pregnancy pregnancy) =>
      _visits.where((v) => v.pregnancyId == pregnancy.id).toList();

  /// Loads [patientId]'s pregnancies and visits. Switching person clears
  /// the previous person's data first, so it can never show under the
  /// wrong name.
  Future<void> load(String patientId) async {
    if (_patientId != patientId) {
      _patientId = patientId;
      _pregnancies = [];
      _visits = [];
      _loaded = false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pregnancies = await _supabase
          .from('pregnancies')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
      final visits = await _supabase
          .from('anc_visits')
          .select()
          .eq('patient_id', patientId)
          .order('visit_date', ascending: false);
      if (_patientId != patientId) return;
      _pregnancies = [for (final r in pregnancies as List) Pregnancy.fromJson(Map<String, dynamic>.from(r))];
      _visits = [for (final r in visits as List) AncVisit.fromJson(Map<String, dynamic>.from(r))];
    } catch (e) {
      debugPrint('PregnancyProvider.load failed: $e');
      if (_patientId == patientId) _error = 'Could not load your pregnancy record.';
    } finally {
      if (_patientId == patientId) {
        _isLoading = false;
        _loaded = true;
        notifyListeners();
      }
    }
  }

  /// Starts a pregnancy from the first day of the last period, or from a
  /// due date (a scan or a clinician's). Exactly one must be given.
  Future<bool> start({
    required String patientId,
    DateTime? lmp,
    DateTime? dueDate,
    String dueDateSource = 'scan',
  }) async {
    assert((lmp == null) != (dueDate == null), 'give either lmp or dueDate');
    final pregnancy = Pregnancy(
      id: '',
      patientId: patientId,
      lmpDate: lmp,
      dueDate: lmp != null ? Pregnancy.dueDateFromLmp(lmp) : dueDate!,
      dueDateSource: lmp != null ? 'lmp' : dueDateSource,
    );
    return _write(
      () => _supabase.from('pregnancies').insert(pregnancy.toJson()).select().maybeSingle(),
      fallback: "We couldn't save your pregnancy. Please check your connection and try again.",
    );
  }

  /// Changes the dates of [pregnancy], the same way [start] sets them.
  Future<bool> updateDates(
    Pregnancy pregnancy, {
    DateTime? lmp,
    DateTime? dueDate,
    String dueDateSource = 'scan',
  }) {
    assert((lmp == null) != (dueDate == null), 'give either lmp or dueDate');
    return _write(
      () => _supabase
          .from('pregnancies')
          .update({
            'lmp_date': Pregnancy.dateOnly(lmp),
            'due_date': Pregnancy.dateOnly(lmp != null ? Pregnancy.dueDateFromLmp(lmp) : dueDate),
            'due_date_source': lmp != null ? 'lmp' : dueDateSource,
          })
          .eq('id', pregnancy.id)
          .select()
          .maybeSingle(),
      fallback: "We couldn't change the dates. Please check your connection and try again.",
    );
  }

  /// Closes [pregnancy] with how it ended (see [Pregnancy.outcomes]).
  Future<bool> end(Pregnancy pregnancy, {required String outcome, required DateTime endedOn}) {
    assert(Pregnancy.outcomes.containsKey(outcome));
    return _write(
      () => _supabase
          .from('pregnancies')
          .update({'status': 'ended', 'outcome': outcome, 'ended_on': Pregnancy.dateOnly(endedOn)})
          .eq('id', pregnancy.id)
          .select()
          .maybeSingle(),
      fallback: "We couldn't save that. Please check your connection and try again.",
    );
  }

  /// Records a visit to the ongoing pregnancy. The visit number and the
  /// weeks of pregnancy on [visitDate] are worked out here.
  Future<bool> addVisit({
    required DateTime visitDate,
    int? systolicBP,
    int? diastolicBP,
    double? weight,
    double? hemoglobin,
    int? fetalHeartRate,
    double? fundalHeight,
    String facility = '',
    List<String> dangerSigns = const [],
    String? notes,
  }) async {
    final pregnancy = current;
    if (pregnancy == null) {
      _error = 'Start your pregnancy record first.';
      notifyListeners();
      return false;
    }
    final weeks = pregnancy.weeksOn(visitDate);
    final row = {
      'patient_id': pregnancy.patientId,
      'pregnancy_id': pregnancy.id,
      'visit_number': visitsOf(pregnancy).length + 1,
      'gestational_weeks': weeks,
      'trimester': Pregnancy.trimesterForWeeks(weeks),
      'visit_date': visitDate.toUtc().toIso8601String(),
      'systolic_bp': systolicBP,
      'diastolic_bp': diastolicBP,
      'weight': weight,
      'hemoglobin': hemoglobin,
      'fetal_heart_rate': fetalHeartRate,
      'fundal_height': fundalHeight,
      'facility': facility,
      'danger_signs': dangerSigns,
      'notes': notes,
    };
    _error = null;
    try {
      final saved = await _supabase.from('anc_visits').insert(row).select().maybeSingle();
      if (saved == null) throw StateError('the server accepted the visit but stored nothing');
      _visits = [AncVisit.fromJson(saved), ..._visits]
        ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('PregnancyProvider.addVisit failed: $e');
      _error = "We couldn't save this visit. Please check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  /// Runs a pregnancy write and puts the stored row in place of the old.
  Future<bool> _write(Future<Map<String, dynamic>?> Function() run, {required String fallback}) async {
    _error = null;
    try {
      final saved = await run();
      if (saved == null) throw StateError('the server accepted the request but stored nothing');
      final p = Pregnancy.fromJson(saved);
      _pregnancies = [p, ..._pregnancies.where((x) => x.id != p.id)]
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      debugPrint('PregnancyProvider write failed: ${e.message}');
      // The database allows one ongoing pregnancy per person. With
      // .maybeSingle(), postgrest-dart replaces the error code with the
      // HTTP status (409), keeping Postgres's code only in the message.
      final duplicate = e.code == '23505' || e.message.contains('23505');
      _error = duplicate ? 'You already have a pregnancy in progress.' : fallback;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('PregnancyProvider write failed: $e');
      _error = fallback;
      notifyListeners();
      return false;
    }
  }
}
