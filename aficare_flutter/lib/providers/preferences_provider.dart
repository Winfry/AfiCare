import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_preferences_model.dart';

class PreferencesProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserPreferencesModel? _prefs;
  bool _isLoading = false;
  String? _error;

  UserPreferencesModel? get prefs => _prefs;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _prefs = UserPreferencesModel(userId: userId);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persist preferences via upsert and update local state immediately.
  /// If the save fails, the previous preferences come back, so the screen
  /// never shows a setting as kept when it wasn't.
  Future<bool> save(UserPreferencesModel prefs) async {
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
