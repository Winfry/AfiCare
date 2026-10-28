import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/record_share_model.dart';

/// A failure worth showing as it is: the database functions in migration
/// 044 word their errors for people ("This share has expired…").
class RecordShareException implements Exception {
  const RecordShareException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// "Share my records" goes only through the database functions in
/// migration 044. The table is read-only to the app, and a doctor or nurse
/// gets back only the sections the patient chose, so neither side can
/// widen a share.
class RecordShareService {
  RecordShareService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Patient side ────────────────────────────────────────────────

  /// Makes a share of [patientId]'s record (the account holder's own, or
  /// a dependant's) and returns it with its code.
  Future<RecordShare> create(String patientId, List<String> sections, int hours) async {
    final res = await _call('create_record_share', {
      'p_patient_id': patientId,
      'p_sections': sections,
      'p_hours': hours,
    });
    if (res is! Map || (res['code'] as String?)?.isNotEmpty != true) {
      throw const RecordShareException(_genericError);
    }
    return RecordShare.fromJson(Map<String, dynamic>.from(res));
  }

  /// [patientId]'s shares, newest first, with who opened each one.
  Future<List<RecordShare>> mine(String patientId) async {
    final rows = await _call('my_record_shares', {'p_patient_id': patientId});
    return rows is List
        ? rows.whereType<Map>().map((m) => RecordShare.fromJson(Map<String, dynamic>.from(m))).toList()
        : const [];
  }

  /// False when nothing was stopped (already stopped or expired).
  Future<bool> revoke(String shareId) async {
    final res = await _call('revoke_record_share', {'p_share_id': shareId});
    return res == true;
  }

  // ── Doctor or nurse side ────────────────────────────────────────

  Future<SharedRecord> open(String code) async {
    final res = await _call('open_record_share', {'p_code': RecordShare.normaliseCode(code)});
    if (res is! Map) throw const RecordShareException(_genericError);
    return SharedRecord.fromJson(Map<String, dynamic>.from(res));
  }

  // ────────────────────────────────────────────────────────────────

  static const _genericError = 'Something went wrong. Check your connection and try again.';

  Future<dynamic> _call(String fn, Map<String, dynamic> params) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      debugPrint('$fn failed: ${e.code} ${e.message}');
      // P0001 is RAISE EXCEPTION: one of our own messages, written to be read.
      if (e.code == 'P0001' && e.message.isNotEmpty) throw RecordShareException(e.message);
      // The function is not there: migration 044 has not been run.
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const RecordShareException('Sharing records is not switched on yet. Please try again later.');
      }
      throw const RecordShareException(_genericError);
    } catch (e) {
      debugPrint('$fn failed: $e');
      throw const RecordShareException(_genericError);
    }
  }
}
