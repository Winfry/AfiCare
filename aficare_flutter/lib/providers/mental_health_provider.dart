import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/mental_health_model.dart';

class MentalHealthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<MentalHealthScreening> _screenings = [];
  List<MoodEntry> _moodEntries = [];
  bool _isLoading = false;
  String? _error;

  List<MentalHealthScreening> get screenings => _screenings;
  List<MoodEntry> get moodEntries => _moodEntries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  MentalHealthScreening? get latestPHQ9 {
    final phq = _screenings.where((s) => s.toolType == 'PHQ-9').toList();
    return phq.isNotEmpty ? phq.first : null;
  }

  MentalHealthScreening? get latestGAD7 {
    final gad = _screenings.where((s) => s.toolType == 'GAD-7').toList();
    return gad.isNotEmpty ? gad.first : null;
  }

  double get averageMood {
    if (_moodEntries.isEmpty) return 3.0;
    final sum = _moodEntries.take(7).fold(0, (int acc, e) => acc + e.mood);
    return sum / _moodEntries.take(7).length;
  }

  Future<void> loadScreenings(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('mental_health_screenings')
          .select()
          .eq('patient_id', patientId)
          .order('completed_at', ascending: false)
          .limit(50);
      _screenings = (data as List)
          .map((j) => MentalHealthScreening.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading screenings: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoodEntries(String patientId) async {
    try {
      final data = await _supabase
          .from('mood_entries')
          .select()
          .eq('patient_id', patientId)
          .order('recorded_at', ascending: false)
          .limit(30);
      _moodEntries = (data as List)
          .map((j) => MoodEntry.fromJson(j))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading mood entries: $e');
    }
  }

  Future<bool> saveScreening({
    required String patientId,
    required String toolType,
    required List<int> answers,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final totalScore = answers.fold(0, (int acc, a) => acc + a);
      final severity = MentalHealthScreening.severityFromScore(toolType, totalScore);

      final screening = MentalHealthScreening(
        id: const Uuid().v4(),
        patientId: patientId,
        toolType: toolType,
        answers: answers,
        totalScore: totalScore,
        severity: severity,
        completedAt: DateTime.now(),
      );

      await _supabase.from('mental_health_screenings').insert(screening.toJson());

      _screenings.insert(0, screening);
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

  Future<bool> saveMoodEntry({
    required String patientId,
    required int mood,
    String? journal,
    List<String>? factors,
  }) async {
    try {
      final entry = MoodEntry(
        id: const Uuid().v4(),
        patientId: patientId,
        mood: mood,
        journal: journal,
        factors: factors ?? [],
        recordedAt: DateTime.now(),
      );

      await _supabase.from('mood_entries').insert(entry.toJson());
      _moodEntries.insert(0, entry);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      return false;
    }
  }
}
