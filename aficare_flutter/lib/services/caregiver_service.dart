import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/caregiver_model.dart';

/// A failure worth showing the person as it is: the database functions in
/// migration 036 word their errors for patients ("That code has expired…").
class CaregiverException implements Exception {
  const CaregiverException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Caregiver access goes only through the database functions in migration
/// 036. The table itself is read-only to the app, so a patient cannot point
/// a code at someone else's record and a caregiver cannot widen what they
/// were given.
class CaregiverService {
  CaregiverService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Patient side ────────────────────────────────────────────────

  Future<List<CaregiverAccess>> myGrants() async {
    final rows = await _call('my_caregiver_grants');
    return _list(rows).map(CaregiverAccess.fromJson).toList();
  }

  /// Makes a new code for [accessLevel] and returns it. [relationship] is
  /// who the caregiver is to the patient (one of [CaregiverRelationship.values]).
  Future<String> createCode(String accessLevel, String relationship) async {
    final res = await _call('create_caregiver_code', {'p_level': accessLevel, 'p_relationship': relationship});
    final code = res is Map ? res['access_code'] as String? : null;
    if (code == null || code.isEmpty) throw const CaregiverException(_genericError);
    return code;
  }

  /// False when nothing was stopped (already stopped, or not this
  /// patient's code).
  Future<bool> revoke(String accessId) async {
    final res = await _call('revoke_caregiver_access', {'p_access_id': accessId});
    return res == true;
  }

  // ── Caregiver side ──────────────────────────────────────────────

  /// Enters [code] and returns the name of the person who shared it.
  Future<String> redeem(String code) async {
    final res = await _call('redeem_caregiver_code', {'p_code': CaregiverAccess.normaliseCode(code)});
    final name = res is Map ? (res['patient_name'] as String?)?.trim() : null;
    return (name == null || name.isEmpty) ? 'this person' : name;
  }

  Future<List<CaregiverLink>> peopleICareFor() async {
    final rows = await _call('people_i_care_for');
    return _list(rows).map(CaregiverLink.fromJson).toList();
  }

  /// The shared record, holding only the sections the access level allows
  /// (see `caregiver_view()` in migration 036).
  Future<Map<String, dynamic>> view(String accessId) async {
    final res = await _call('caregiver_view', {'p_access_id': accessId});
    if (res is! Map) throw const CaregiverException(_genericError);
    return Map<String, dynamic>.from(res);
  }

  // ────────────────────────────────────────────────────────────────

  static const _genericError = "Something went wrong. Check your connection and try again.";

  Future<dynamic> _call(String fn, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      debugPrint('$fn failed: ${e.code} ${e.message}');
      // P0001 is RAISE EXCEPTION: one of our own messages, written to be read.
      if (e.code == 'P0001' && e.message.isNotEmpty) throw CaregiverException(e.message);
      // The function is not there: migration 036 has not been run.
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const CaregiverException('Caregiver access is not switched on yet. Please try again later.');
      }
      throw const CaregiverException(_genericError);
    } catch (e) {
      debugPrint('$fn failed: $e');
      throw const CaregiverException(_genericError);
    }
  }

  static List<Map<String, dynamic>> _list(dynamic rows) =>
      rows is List ? rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
}
