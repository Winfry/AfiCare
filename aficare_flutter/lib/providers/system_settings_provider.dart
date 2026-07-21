import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_setting_model.dart';

class SystemSettingsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<SystemSettingModel> _settings = [];
  bool _isLoading = false;
  String? _error;

  List<SystemSettingModel> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<SystemSettingModel> getByCategory(String category) {
    return _settings.where((s) => s.category == category).toList();
  }

  dynamic getValue(String category, String key) {
    try {
      return _settings.firstWhere((s) => s.category == category && s.key == key).value;
    } catch (_) {
      return null;
    }
  }

  bool getBool(String category, String key, {bool defaultValue = false}) {
    final v = getValue(category, key);
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return defaultValue;
  }

  String getString(String category, String key, {String defaultValue = ''}) {
    final v = getValue(category, key);
    if (v is String) return v;
    return defaultValue;
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('system_settings')
          .select('*')
          .order('category');

      _settings = (response as List)
          .map((json) => SystemSettingModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSetting(
    String category,
    String key,
    dynamic value, {
    String? description,
    String? userId,
  }) async {
    try {
      final existing = _settings.where(
        (s) => s.category == category && s.key == key,
      );

      if (existing.isNotEmpty) {
        await _supabase
            .from('system_settings')
            .update({
              'value': value,
              'description': description,
              'updated_by': userId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('category', category)
            .eq('key', key);
      } else {
        await _supabase.from('system_settings').insert({
          'category': category,
          'key': key,
          'value': value,
          'description': description,
          'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await loadSettings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> initDefaults(String userId) async {
    try {
      final count = await _supabase
          .from('system_settings')
          .select('id', const FetchOptions(count: ExactCount.exact));
      if ((count.count ?? 0) > 0) return true;

      final defaults = [
        {'category': 'general', 'key': 'app_name', 'value': 'AfiCare MediLink', 'description': 'Application display name', 'updated_by': userId},
        {'category': 'general', 'key': 'app_version', 'value': '1.0.0', 'description': 'Current version', 'updated_by': userId},
        {'category': 'general', 'key': 'maintenance_mode', 'value': false, 'description': 'Enable maintenance mode', 'updated_by': userId},
        {'category': 'security', 'key': 'min_password_length', 'value': 8, 'description': 'Minimum password length', 'updated_by': userId},
        {'category': 'security', 'key': 'mfa_enabled', 'value': false, 'description': 'Multi-factor authentication', 'updated_by': userId},
        {'category': 'security', 'key': 'session_timeout_minutes', 'value': 60, 'description': 'Session timeout in minutes', 'updated_by': userId},
        {'category': 'notifications', 'key': 'smtp_host', 'value': '', 'description': 'SMTP server host', 'updated_by': userId},
        {'category': 'notifications', 'key': 'smtp_port', 'value': 587, 'description': 'SMTP server port', 'updated_by': userId},
        {'category': 'notifications', 'key': 'push_enabled', 'value': true, 'description': 'Push notifications enabled', 'updated_by': userId},
        {'category': 'integrations', 'key': 'api_base_url', 'value': '', 'description': 'External API base URL', 'updated_by': userId},
        {'category': 'integrations', 'key': 'webhook_url', 'value': '', 'description': 'Webhook endpoint URL', 'updated_by': userId},
        {'category': 'subscription', 'key': 'plan', 'value': 'free', 'description': 'Subscription plan', 'updated_by': userId},
        {'category': 'subscription', 'key': 'billing_email', 'value': '', 'description': 'Billing contact email', 'updated_by': userId},
      ];

      for (final d in defaults) {
        await _supabase.from('system_settings').insert({
          ...d,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await loadSettings();
      return true;
    } catch (e) {
      debugPrint('Init defaults error: $e');
      return false;
    }
  }
}