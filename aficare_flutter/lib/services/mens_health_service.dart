import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/mens_health_model.dart';
import '../models/mens_health_tools.dart';

/// Loads and saves Men's health check-ups. Both throw on failure, so the
/// screen can tell "couldn't load" from "none yet" and "not saved" from
/// "saved".
class MensHealthService {
  MensHealthService([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<List<MensHealthScreening>> load(String patientId) async {
    final data = await _db
        .from('mens_health_screenings')
        .select()
        .eq('patient_id', patientId)
        .order('completed_at', ascending: false)
        .limit(30);
    return (data as List).map((j) => MensHealthScreening.fromJson(j)).toList();
  }

  Future<void> save({
    required String patientId,
    required MhTool tool,
    required Map<String, int> answers,
    required MhResult result,
  }) async {
    await _db.from('mens_health_screenings').insert({
      'id': const Uuid().v4(),
      'patient_id': patientId,
      'screening_type': tool.type,
      'responses': {'answers': answers},
      'risk_score': result.score,
      'risk_level': result.level,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();
  }
}
