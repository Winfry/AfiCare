import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/patient_profile_model.dart';
import '../services/offline_cache.dart';

class PatientProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  PatientProfileModel? _profile;
  bool _isLoading = false;
  String? _error;
  DateTime? _profileFromCacheAt;

  PatientProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// When the current [profile] came from the on-device copy rather than
  /// the server, the time that copy was saved. Null when it is live.
  /// Screens that show allergies or blood type must say so.
  DateTime? get profileFromCacheAt => _profileFromCacheAt;

  Future<void> loadProfile(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('patients')
          .select()
          .eq('id', patientId)
          .maybeSingle();

      if (response != null) {
        _profile = PatientProfileModel.fromJson(response);
        // Keep a copy: allergies and blood type are what a clinician
        // needs when the patient cannot speak and there is no signal.
        await OfflineCache.save(
          OfflineCache.safetyKey(patientId),
          _profile!.toJson(),
        );
      } else {
        // No row yet — start with an empty profile for this patient.
        _profile = PatientProfileModel(id: patientId);
      }
      _profileFromCacheAt = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      // Previously this manufactured an empty profile, which is
      // indistinguishable from a patient who has no allergies on file.
      // Prefer the last known copy; only fall back to empty when there
      // isn't one, and never silently present it as current.
      final cached = OfflineCache.read(OfflineCache.safetyKey(patientId));
      final payload = cached?.payload;
      if (payload is Map) {
        try {
          _profile = PatientProfileModel.fromJson(Map<String, dynamic>.from(payload));
          _profileFromCacheAt = cached!.savedAt;
        } catch (err) {
          debugPrint('patient_profile_provider: cached profile unreadable: $err');
          _profile = PatientProfileModel(id: patientId);
          _profileFromCacheAt = null;
        }
      } else {
        _profile = PatientProfileModel(id: patientId);
        _profileFromCacheAt = null;
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upsert the patient profile row (insert if absent, update otherwise).
  Future<bool> saveProfile(PatientProfileModel profile) async {
    try {
      // Ask for the stored row back. When row-level security refuses an
      // upsert's UPDATE half, Postgres reports success with zero rows, so
      // without this a write that never happened looked identical to one
      // that did — and a new patient's profile was silently lost.
      final saved = await _supabase
          .from('patients')
          .upsert(profile.toJson())
          .select()
          .maybeSingle();
      if (saved == null) {
        throw StateError('the server accepted the request but stored nothing');
      }
      _profile = PatientProfileModel.fromJson(saved);
      _profileFromCacheAt = null;
      _error = null;
      await OfflineCache.save(OfflineCache.safetyKey(profile.id), _profile!.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('patient_profile_provider: saveProfile failed: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
