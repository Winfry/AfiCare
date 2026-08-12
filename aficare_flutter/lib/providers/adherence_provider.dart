import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adherence_model.dart';

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

  /// Patient adds their own medication: creates a self-prescribed
  /// prescription row + generates today's dose entries.
  Future<bool> addMedication({
    required String patientId,
    required String medicationName,
    required String dosage,
    required int timesPerDay,
    String? instructions,
  }) async {
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

      final prescriptionId = rxResponse['id'] as String;

      // 2. Generate today's dose entries
      final now = DateTime.now();
      final doses = <Map<String, dynamic>>[];
      // Spread doses across the day: morning, noon, evening, night
      const hours = [8, 13, 18, 21];
      for (int i = 0; i < timesPerDay; i++) {
        final scheduledTime = DateTime(
          now.year, now.month, now.day,
          hours[i], 0,
        );
        doses.add({
          'prescription_id': prescriptionId,
          'patient_id': patientId,
          'scheduled_time': scheduledTime.toIso8601String(),
          'status': 'pending',
        });
      }

      if (doses.isNotEmpty) {
        await _supabase.from('adherence_log').insert(doses);
      }

      // 3. Reload today's doses
      await loadToday(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
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
          .gte('scheduled_time', start.toIso8601String())
          .lt('scheduled_time', end.toIso8601String());

      final existingRxIds = (existing as List)
          .map((e) => e['prescription_id'] as String)
          .toSet();

      // For prescriptions without today's doses, generate them
      final newDoses = <Map<String, dynamic>>[];
      for (final rx in prescriptions as List) {
        final rxId = rx['id'] as String;
        if (existingRxIds.contains(rxId)) continue;

        // Parse frequency to determine times per day
        final freq = (rx['frequency'] as String?) ?? '';
        int timesPerDay = _parseFrequency(freq);

        const hours = [8, 13, 18, 21];
        for (int i = 0; i < timesPerDay; i++) {
          final scheduledTime = DateTime(
            now.year, now.month, now.day,
            i < hours.length ? hours[i] : 8,
            0,
          );
          newDoses.add({
            'prescription_id': rxId,
            'patient_id': patientId,
            'scheduled_time': scheduledTime.toIso8601String(),
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

  /// Parse a free-text frequency string into a number of doses per day.
  int _parseFrequency(String freq) {
    final f = freq.toLowerCase();
    if (f.contains('once') || f.contains('1 time') || f.contains('1x')) return 1;
    if (f.contains('twice') || f.contains('2 time') || f.contains('2x') || f.contains('2 times')) return 2;
    if (f.contains('three') || f.contains('3 time') || f.contains('3x') || f.contains('3 times')) return 3;
    if (f.contains('four') || f.contains('4 time') || f.contains('4x') || f.contains('4 times')) return 4;
    // Try to extract a leading number
    final match = RegExp(r'(\d+)').firstMatch(f);
    if (match != null) {
      final n = int.tryParse(match.group(1)!) ?? 1;
      return n.clamp(1, 4);
    }
    return 1; // default to once daily
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
          .gte('scheduled_time', start.toIso8601String())
          .lt('scheduled_time', end.toIso8601String())
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
          .gte('scheduled_time', since.toIso8601String())
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
            ? DateTime.now().toIso8601String()
            : null,
        'skipped_reason': status == AdherenceStatus.skipped ? reason : null,
      };
      await _supabase.from('adherence_log').update(updates).eq('id', logId);

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
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
