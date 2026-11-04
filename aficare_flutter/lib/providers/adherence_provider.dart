import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adherence_model.dart';
import '../utils/dose_frequency.dart';

/// What happened when a medicine was added (see
/// [AdherenceProvider.addMedication]).
enum AddMedicationResult {
  /// The medicine and today's doses are saved.
  added,

  /// The medicine is saved; today's doses will be added when the tracker
  /// next loads.
  addedDosesLater,

  /// Nothing was saved.
  failed,
}

class AdherenceProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AdherenceLogModel> _today = [];
  List<AdherenceLogModel> _history = [];
  bool _isLoading = false;
  String? _error;

  List<AdherenceLogModel> get today => _today;
  List<AdherenceLogModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Doses due today (all statuses).
  List<AdherenceLogModel> get todayDoses => _today;

  /// Percentage of today's doses that are marked taken.
  int get todayScore {
    if (_today.isEmpty) return 0;
    final taken =
        _today.where((d) => d.status == AdherenceStatus.taken).length;
    return ((taken / _today.length) * 100).round();
  }

  int get todayRemaining =>
      _today.where((d) => d.status == AdherenceStatus.pending).length;

  /// Overall adherence rate across the loaded history window.
  int get historyRate {
    final resolved = _history
        .where((d) => d.status != AdherenceStatus.pending)
        .toList();
    if (resolved.isEmpty) return 0;
    final taken =
        resolved.where((d) => d.status == AdherenceStatus.taken).length;
    return ((taken / resolved.length) * 100).round();
  }

  int get historyTaken =>
      _history.where((d) => d.status == AdherenceStatus.taken).length;
  int get historyTotal =>
      _history.where((d) => d.status != AdherenceStatus.pending).length;

  List<AdherenceLogModel> get missedDoses => _history
      .where((d) => d.status == AdherenceStatus.skipped)
      .toList()
    ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

  /// Consecutive-day streak where every dose that day was taken.
  int get streak {
    if (_history.isEmpty) return 0;
    final Map<String, List<AdherenceLogModel>> byDay = {};
    for (final d in _history) {
      final key = _dayKey(d.scheduledTime);
      byDay.putIfAbsent(key, () => []).add(d);
    }
    int streak = 0;
    var day = DateTime.now();
    while (true) {
      final key = _dayKey(day);
      final doses = byDay[key];
      if (doses == null || doses.isEmpty) break;
      final allTaken =
          doses.every((d) => d.status == AdherenceStatus.taken);
      if (!allTaken) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Per-day taken-percentage for the last [days] days (oldest → newest).
  List<double> weeklyBars({int days = 7}) {
    final Map<String, List<AdherenceLogModel>> byDay = {};
    for (final d in _history) {
      byDay.putIfAbsent(_dayKey(d.scheduledTime), () => []).add(d);
    }
    final bars = <double>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final doses = byDay[_dayKey(day)] ?? [];
      if (doses.isEmpty) {
        bars.add(0);
      } else {
        final taken =
            doses.where((d) => d.status == AdherenceStatus.taken).length;
        bars.add(taken / doses.length);
      }
    }
    return bars;
  }

  /// Patient adds their own medication: a self-prescribed prescription,
  /// then today's dose entries.
  ///
  /// Never leaves her guessing: [AddMedicationResult.failed] means nothing
  /// was saved, so trying again cannot make a copy;
  /// [AddMedicationResult.addedDosesLater] means the medicine is saved but
  /// today's doses are not yet, and [ensureTodayDoses] adds them the next
  /// time the tracker loads.
  Future<AddMedicationResult> addMedication({
    required String patientId,
    required String medicationName,
    required String dosage,
    required int timesPerDay,
    String? instructions,
  }) async {
    final String prescriptionId;
    try {
      // 1. Create a self-prescribed prescription
      final rxResponse = await _supabase
          .from('prescriptions')
          .insert({
            'patient_id': patientId,
            'provider_id': patientId, // self-prescribed
            'medication_name': medicationName,
            'dosage': dosage,
            'frequency': '$timesPerDay time${timesPerDay == 1 ? '' : 's'} a day',
            'duration': 'ongoing',
            'instructions': instructions,
            'status': 'active',
          })
          .select()
          .single();
      prescriptionId = rxResponse['id'] as String;
    } catch (e) {
      debugPrint('Adding a medication failed: $e');
      _error = "We couldn't add this medicine. Check your connection and try again.";
      notifyListeners();
      return AddMedicationResult.failed;
    }

    // 2. Today's doses, spread across the day (up to 6).
    final now = DateTime.now();
    final doses = [
      for (final hour in DoseFrequency.hours(timesPerDay))
        {
          'prescription_id': prescriptionId,
          'patient_id': patientId,
          // A true time: Kenyan 08:00 is sent as 05:00 UTC (see 052).
          'scheduled_time': DateTime(now.year, now.month, now.day, hour).toUtc().toIso8601String(),
          'status': 'pending',
        },
    ];
    var dosesSaved = doses.isEmpty;
    for (var attempt = 0; attempt < 2 && !dosesSaved; attempt++) {
      try {
        await _supabase.from('adherence_log').insert(doses);
        dosesSaved = true;
      } catch (e) {
        debugPrint("Adding today's doses failed (attempt ${attempt + 1}): $e");
      }
    }

    // 3. Reload today's doses
    await loadToday(patientId);
    return dosesSaved ? AddMedicationResult.added : AddMedicationResult.addedDosesLater;
  }

  /// Ensures today's doses exist for all active prescriptions.
  /// If a prescription has no adherence_log entries for today,
  /// this generates them based on the frequency.
  Future<void> ensureTodayDoses(String patientId) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      // Get all active prescriptions for this patient
      final prescriptions = await _supabase
          .from('prescriptions')
          .select('id, frequency, status')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      // Get today's existing dose entries
      final existing = await _supabase
          .from('adherence_log')
          .select('prescription_id')
          .eq('patient_id', patientId)
          .gte('scheduled_time', start.toUtc().toIso8601String())
          .lt('scheduled_time', end.toUtc().toIso8601String());

      final existingRxIds = (existing as List)
          .map((e) => e['prescription_id'] as String)
          .toSet();

      // For prescriptions without today's doses, generate them
      final newDoses = <Map<String, dynamic>>[];
      for (final rx in prescriptions as List) {
        final rxId = rx['id'] as String;
        if (existingRxIds.contains(rxId)) continue;

        final perDay = DoseFrequency.perDay(rx['frequency'] as String?);
        for (final hour in DoseFrequency.hours(perDay)) {
          final scheduledTime = DateTime(now.year, now.month, now.day, hour);
          newDoses.add({
            'prescription_id': rxId,
            'patient_id': patientId,
            'scheduled_time': scheduledTime.toUtc().toIso8601String(),
            'status': 'pending',
          });
        }
      }

      if (newDoses.isNotEmpty) {
        await _supabase.from('adherence_log').insert(newDoses);
      }
    } catch (_) {
      // Non-critical — the tracker will just show whatever exists
    }
  }

  Future<void> loadToday(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final response = await _supabase
          .from('adherence_log')
          .select('*, prescriptions(medication_name, dosage)')
          .eq('patient_id', patientId)
          .gte('scheduled_time', start.toUtc().toIso8601String())
          .lt('scheduled_time', end.toUtc().toIso8601String())
          .order('scheduled_time', ascending: true);

      _today = (response as List)
          .map((j) => AdherenceLogModel.fromJson(j as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory(String patientId, {int days = 30}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final response = await _supabase
          .from('adherence_log')
          .select('*, prescriptions(medication_name, dosage)')
          .eq('patient_id', patientId)
          .gte('scheduled_time', since.toUtc().toIso8601String())
          .order('scheduled_time', ascending: false);

      _history = (response as List)
          .map((j) => AdherenceLogModel.fromJson(j as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markStatus(String logId, AdherenceStatus status,
      {String? reason}) async {
    try {
      final updates = <String, dynamic>{
        'status': status == AdherenceStatus.taken
            ? 'taken'
            : status == AdherenceStatus.skipped
                ? 'skipped'
                : 'pending',
        'taken_time': status == AdherenceStatus.taken
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'skipped_reason': status == AdherenceStatus.skipped ? reason : null,
      };
      // .select() so a change the database quietly refused is caught.
      final rows = await _supabase.from('adherence_log').update(updates).eq('id', logId).select('id');
      if ((rows as List).isEmpty) throw StateError('No dose was changed');

      final idx = _today.indexWhere((d) => d.id == logId);
      if (idx != -1) {
        _today[idx] = _today[idx].copyWith(
          status: status,
          takenTime:
              status == AdherenceStatus.taken ? DateTime.now() : null,
          skippedReason: reason,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Marking a dose failed: $e');
      _error = "We couldn't save that. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
