import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_preferences_model.dart';

class PreferencesProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserPreferencesModel? _prefs;
  bool _isLoading = false;
  String? _error;

  bool _loadFailed = false;

  UserPreferencesModel? get prefs => _prefs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when her saved settings could not be loaded. The defaults are
  /// in use meanwhile, and nothing may be saved: saving would write those
  /// defaults over the settings she really chose.
  bool get loadFailed => _loadFailed;

  /// Forgets the signed-in person's settings (on sign-out), so the next
  /// person on the phone doesn't get her text size or contrast.
  void clear() {
    if (_prefs == null && !_loadFailed && _error == null) return;
    _prefs = null;
    _loadFailed = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadPreferences(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      _prefs = response != null
          ? UserPreferencesModel.fromJson(response)
          : UserPreferencesModel(userId: userId);
      _loadFailed = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('PreferencesProvider.loadPreferences failed: $e');
      _error = "We couldn't load your settings.";
      _loadFailed = true;
      _prefs = UserPreferencesModel(userId: userId);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persist preferences via upsert and update local state immediately.
  /// If the save fails, the previous preferences come back, so the screen
  /// never shows a setting as kept when it wasn't.
  Future<bool> save(UserPreferencesModel prefs) async {
    if (_loadFailed) {
      _error = "Your settings didn't load, so nothing was changed. "
          'Check your connection and try again.';
      notifyListeners();
      return false;
    }
    final previous = _prefs;
    _prefs = prefs;
    _error = null;
    notifyListeners();
    try {
      final data = prefs.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('user_preferences').upsert(data);
      return true;
    } catch (e) {
      debugPrint('PreferencesProvider.save failed: $e');
      _prefs = previous;
      _error = "We couldn't save that setting, so it hasn't changed.";
      notifyListeners();
      return false;
    }
  }
}
