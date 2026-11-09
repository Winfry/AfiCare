import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adherence_model.dart';
import '../utils/dose_frequency.dart';
import '../utils/medicine_course.dart';

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
  bool _todayFailed = false;
  bool _historyFailed = false;
  final Set<String> _marking = {};

  /// Whether a "Mark taken" / "Skip" for this dose is still being saved,
  /// so its buttons can wait instead of sending it twice.
  bool isMarking(String logId) => _marking.contains(logId);

  List<AdherenceLogModel> get today => _today;
  List<AdherenceLogModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether the last load of today's doses failed. Kept apart from
  /// [error], which a later load (or a failed "Mark taken") overwrites:
  /// otherwise a failed load could be shown as "No medications yet".
  bool get todayFailed => _todayFailed;

  /// Whether the last history load failed.
  bool get historyFailed => _historyFailed;

  /// Either load failed.
  bool get loadFailed => _todayFailed || _historyFailed;

  /// How long after its time an unmarked dose counts as missed.
  static const missedAfter = Duration(hours: 2);

  /// An unmarked dose more than [missedAfter] past its time.
  static bool isMissed(AdherenceLogModel d, [DateTime? now]) =>
      d.status == AdherenceStatus.pending &&
      d.scheduledTime.isBefore((now ?? DateTime.now()).subtract(missedAfter));

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

  /// Doses that count in the history figures: taken, skipped, or missed
  /// (unmarked well past their time). Doses still to come don't count yet.
  /// Missed doses used to be left out, so someone who never marked
  /// anything could read 100%.
  List<AdherenceLogModel> get _counted {
    final now = DateTime.now();
    return _history
        .where((d) => d.status != AdherenceStatus.pending || isMissed(d, now))
        .toList();
  }

  /// Percentage of counted doses that were taken.
  int get historyRate {
    final counted = _counted;
    if (counted.isEmpty) return 0;
    final taken = counted.where((d) => d.status == AdherenceStatus.taken).length;
    return ((taken / counted.length) * 100).round();
  }

  int get historyTaken =>
      _history.where((d) => d.status == AdherenceStatus.taken).length;
  int get historyTotal => _counted.length;

  /// Doses never marked, well past their time (newest first).
  List<AdherenceLogModel> get missedDoses {
    final now = DateTime.now();
    return _history.where((d) => isMissed(d, now)).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  /// Doses she chose to skip (newest first). Not the same as missed.
  List<AdherenceLogModel> get skippedDoses => _history
      .where((d) => d.status == AdherenceStatus.skipped)
      .toList()
    ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

  /// Days in a row on which every dose was taken. Today joins the streak
  /// once all of it is taken; until then the streak runs to yesterday, so
  /// it doesn't read 0 every morning. A skipped or missed dose today ends it.
  int get streak {
    if (_history.isEmpty) return 0;
    final Map<String, List<AdherenceLogModel>> byDay = {};
    for (final d in _history) {
      byDay.putIfAbsent(_dayKey(d.scheduledTime), () => []).add(d);
    }
    final now = DateTime.now();
    final todays = byDay[_dayKey(now)] ?? const <AdherenceLogModel>[];
    if (todays.any((d) => d.status == AdherenceStatus.skipped || isMissed(d, now))) {
      return 0;
    }
    final todayDone =
        todays.isNotEmpty && todays.every((d) => d.status == AdherenceStatus.taken);
    var day = todayDone ? now : DateTime(now.year, now.month, now.day - 1);

    int streak = 0;
    while (true) {
      final doses = byDay[_dayKey(day)];
      if (doses == null || doses.isEmpty) break;
      if (!doses.every((d) => d.status == AdherenceStatus.taken)) break;
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
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
    final doses = _dosesFor(prescriptionId, patientId, DateTime.now(), timesPerDay);
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

  /// One day's dose rows for a prescription, at the usual clock hours,
  /// leaving out any before [notBefore].
  /// A true time: Kenyan 08:00 is sent as 05:00 UTC (see 052).
  static List<Map<String, dynamic>> _dosesFor(
      String prescriptionId, String patientId, DateTime day, int perDay,
      {DateTime? notBefore}) {
    return [
      for (final hour in DoseFrequency.hours(perDay))
        if (notBefore == null ||
            !DateTime(day.year, day.month, day.day, hour).isBefore(notBefore))
          {
            'prescription_id': prescriptionId,
            'patient_id': patientId,
            'scheduled_time':
                DateTime(day.year, day.month, day.day, hour).toUtc().toIso8601String(),
            'status': 'pending',
          },
    ];
  }

  /// How many past days [ensureTodayDoses] fills in.
  static const backfillDays = 30;

  /// Makes sure every active prescription has its dose entries: today,
  /// and the past days she didn't open the tracker (up to [backfillDays],
  /// never before she first used the tracker, never before the medicine
  /// started). Without the past days, a day she forgot simply wasn't
  /// there, and her adherence could read 100%. A course that has ended
  /// ("5 days", "2/52", or past its expiry date) gets no new doses.
  Future<void> ensureTodayDoses(String patientId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day + 1);

      final prescriptions = await _supabase
          .from('prescriptions')
          // '*': which of issued_at / created_at / expires_at exist has
          // varied between databases; a named missing column would fail
          // the whole query and leave her with no doses at all.
          .select('*')
          .eq('patient_id', patientId)
          .eq('status', 'active');
      if ((prescriptions as List).isEmpty) return;

      // The first day she used the tracker: days before that aren't hers
      // to be marked down for.
      final first = await _supabase
          .from('adherence_log')
          .select('scheduled_time')
          .eq('patient_id', patientId)
          .order('scheduled_time', ascending: true)
          .limit(1);
      var from = DateTime(today.year, today.month, today.day - backfillDays);
      if ((first as List).isEmpty) {
        from = today;
      } else {
        final f = DateTime.parse(first.first['scheduled_time'] as String).toLocal();
        final firstDay = DateTime(f.year, f.month, f.day);
        if (firstDay.isAfter(from)) from = firstDay;
      }

      final existing = await _supabase
          .from('adherence_log')
          .select('prescription_id, scheduled_time')
          .eq('patient_id', patientId)
          .gte('scheduled_time', from.toUtc().toIso8601String())
          .lt('scheduled_time', end.toUtc().toIso8601String());
      final have = <String>{
        for (final e in existing as List)
          '${e['prescription_id']}|'
              '${_dayKey(DateTime.parse(e['scheduled_time'] as String).toLocal())}',
      };

      final newDoses = <Map<String, dynamic>>[];
      for (final rx in prescriptions) {
        final rxId = rx['id'] as String;
        final perDay = DoseFrequency.perDay(rx['frequency'] as String?);
        if (perDay == 0) continue;
        final startedRaw = (rx['issued_at'] ?? rx['created_at']) as String?;
        final started = startedRaw == null ? null : DateTime.parse(startedRaw).toLocal();
        final startDay =
            started == null ? null : DateTime(started.year, started.month, started.day);
        final last = started == null
            ? null
            : MedicineCourse.lastDay(
                start: started,
                duration: rx['duration'] as String?,
                expiresAt: rx['expires_at'] == null
                    ? null
                    : DateTime.parse(rx['expires_at'] as String),
              );

        for (var day = from; !day.isAfter(today); day = DateTime(day.year, day.month, day.day + 1)) {
          if (last != null && day.isAfter(last)) break;
          if (startDay != null && day.isBefore(startDay)) continue;
          if (have.contains('$rxId|${_dayKey(day)}')) continue;
          // Today every dose is listed, so she can tick ones she already
          // took; on past days, none from before the medicine started.
          newDoses.addAll(_dosesFor(rxId, patientId, day, perDay,
              notBefore: day == today ? null : started));
        }
      }

      if (newDoses.isNotEmpty) {
        await _supabase.from('adherence_log').insert(newDoses);
      }
    } catch (e) {
      // Non-critical: the tracker shows whatever exists.
      debugPrint('Adding missing doses failed: $e');
    }
  }

  Future<void> loadToday(String patientId) async {
    _isLoading = true;
    _error = null;
    _todayFailed = false;
    notifyListeners();

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day + 1);

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
      debugPrint("Loading today's doses failed: $e");
      _error = "We couldn't load today's doses.";
      _todayFailed = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory(String patientId, {int days = 30}) async {
    _isLoading = true;
    _error = null;
    _historyFailed = false;
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
      debugPrint('Loading dose history failed: $e');
      _error = "We couldn't load your dose history.";
      _historyFailed = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markStatus(String logId, AdherenceStatus status,
      {String? reason}) async {
    if (!_marking.add(logId)) return false;
    notifyListeners();
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

      // Both lists, so the streak and history figures move at once.
      AdherenceLogModel changed(AdherenceLogModel d) => d.copyWith(
            status: status,
            takenTime: status == AdherenceStatus.taken ? DateTime.now() : null,
            skippedReason: reason,
          );
      final idx = _today.indexWhere((d) => d.id == logId);
      if (idx != -1) _today[idx] = changed(_today[idx]);
      final h = _history.indexWhere((d) => d.id == logId);
      if (h != -1) _history[h] = changed(_history[h]);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Marking a dose failed: $e');
      _error = "We couldn't save that. Check your connection and try again.";
      notifyListeners();
      return false;
    } finally {
      _marking.remove(logId);
      notifyListeners();
    }
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
