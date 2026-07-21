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
