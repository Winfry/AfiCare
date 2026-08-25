import 'package:shared_preferences/shared_preferences.dart';

/// Persists a patient's avatar choice for each provider.
///
/// Storage key format: `avatar_{patientId}_{providerId}`
/// Value: asset path string (e.g. `assets/images/avatar-07.png`)
///
/// This is a patient-side visual preference only — it does not affect
/// what the provider or other patients see.
class AvatarStorage {
  const AvatarStorage._();

  static String _key(String patientId, String providerId) =>
      'avatar_${patientId}_$providerId';

  /// Get the patient's chosen avatar asset path for [providerId].
  /// Returns null if no choice has been made.
  static Future<String?> get({
    required String patientId,
    required String providerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(patientId, providerId));
  }

  /// Save the patient's avatar choice for [providerId].
  static Future<void> set({
    required String patientId,
    required String providerId,
    required String assetPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(patientId, providerId), assetPath);
  }

  /// Clear the patient's avatar choice for [providerId].
  /// Reverts to the default role+gender fallback.
  static Future<void> clear({
    required String patientId,
    required String providerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(patientId, providerId));
  }

  /// Get all avatar choices for a patient (providerId → assetPath).
  static Future<Map<String, String>> getAll({
    required String patientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'avatar_${patientId}_';
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        final providerId = key.substring(prefix.length);
        final value = prefs.getString(key);
        if (value != null) result[providerId] = value;
      }
    }
    return result;
  }
}
