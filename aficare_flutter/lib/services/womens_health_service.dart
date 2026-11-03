import 'package:supabase_flutter/supabase_flutter.dart';

/// The patient's Women's health record (cycle, periods, screenings, life
/// stage), in its own table that only she can read or change (migration
/// 047). It used to live in the account row, which every staff account
/// can read.
class WomensHealthService {
  WomensHealthService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Her stored record, or null when she has none yet. Throws when it
  /// could not be loaded, so "not loaded" is never shown as "nothing".
  Future<Map<String, dynamic>?> load(String patientId) async {
    final row = await _client
        .from('womens_health_records')
        .select('record')
        .eq('patient_id', patientId)
        .maybeSingle();
    final record = row?['record'];
    return record is Map ? Map<String, dynamic>.from(record) : null;
  }

  /// Saves [record] as hers. Throws unless the database confirms the row.
  Future<void> save(String patientId, Map<String, dynamic> record) async {
    await _client
        .from('womens_health_records')
        .upsert({
          'patient_id': patientId,
          'record': record,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'patient_id')
        .select('patient_id')
        .single();
  }
}
