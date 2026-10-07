import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A small on-device cache for the handful of things a patient must be
/// able to see with no connection: what they take, what they react to,
/// their blood type and their MediLink ID — which is also exactly what
/// matters in an emergency, when signal is least likely.
///
/// Deliberately narrow. This is not a general offline mode and nothing
/// here is ever written back to the server: it is a read-only copy of the
/// last successful load, so that a failed load can show the last known
/// truth instead of an empty screen.
///
/// Values are stored as JSON strings rather than through generated Hive
/// adapters, so adding a field to a model can never corrupt the box — an
/// entry that no longer parses is simply dropped.
class OfflineCache {
  OfflineCache._();

  static const _boxName = 'aficare_offline_v1';
  static Box<String>? _box;

  /// Opens the box. Safe to call more than once, and safe to fail: when
  /// the box is unavailable every read returns null and every write is a
  /// no-op, so the app behaves exactly as it did before this existed.
  static Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      debugPrint('offline_cache: could not open box: $e');
    }
  }

  static bool get isReady => _box != null;

  // ── Keys ────────────────────────────────────────────────────────────
  // Scoped per patient id so a guardian's cache and a dependant's cache
  // can never be read in place of one another.

  static String medicationsKey(String patientId) => 'meds::$patientId';
  static String safetyKey(String patientId) => 'safety::$patientId';
  static String emergencyKey(String patientId) => 'emergency::$patientId';

  /// The signed-in user's own row. Cached chiefly for the MediLink ID,
  /// which is what a facility scans — useless if it only exists on a
  /// server the phone cannot reach. Cleared on sign-out.
  static String userKey(String userId) => 'user::$userId';

  // ── Write ───────────────────────────────────────────────────────────

  /// Stores [payload] (anything `jsonEncode` accepts) with the time it was
  /// saved. Failures are swallowed: caching must never break a load that
  /// otherwise succeeded.
  static Future<void> save(String key, Object payload) async {
    final box = _box;
    if (box == null) return;
    try {
      await box.put(
        key,
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'payload': payload,
        }),
      );
    } catch (e) {
      debugPrint('offline_cache: could not save $key: $e');
    }
  }

  // ── Read ────────────────────────────────────────────────────────────

  /// The last saved copy for [key], or null if there is none, the box is
  /// unavailable, or the stored entry no longer parses.
  static CachedEntry? read(String key) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(decoded['savedAt'] as String? ?? '');
      if (savedAt == null) return null;
      return CachedEntry(payload: decoded['payload'], savedAt: savedAt);
    } catch (e) {
      debugPrint('offline_cache: dropping unreadable entry $key: $e');
      return null;
    }
  }

  /// Convenience for the common case of a cached list of rows.
  static CachedList? readList(String key) {
    final entry = read(key);
    final payload = entry?.payload;
    if (entry == null || payload is! List) return null;
    return CachedList(
      rows: payload.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      savedAt: entry.savedAt,
    );
  }

  // ── Clear ───────────────────────────────────────────────────────────

  /// Wipes everything. Called on sign-out: these devices are shared, and
  /// one person's allergies must not survive into the next person's
  /// session.
  static Future<void> clear() async {
    final box = _box;
    if (box == null) return;
    try {
      await box.clear();
    } catch (e) {
      debugPrint('offline_cache: could not clear: $e');
    }
  }
}

class CachedEntry {
  const CachedEntry({required this.payload, required this.savedAt});
  final dynamic payload;
  final DateTime savedAt;
}

class CachedList {
  const CachedList({required this.rows, required this.savedAt});
  final List<Map<String, dynamic>> rows;
  final DateTime savedAt;
}
