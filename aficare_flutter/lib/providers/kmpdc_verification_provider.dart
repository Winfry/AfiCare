import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kmpdc_practitioner_model.dart';

/// Doctor verification against KMPDC's public register -- the final
/// item from the original facility-admin mockup. Deliberately its own
/// provider: this is global reference data (not facility-scoped, not
/// visit-derived, not a facility-wide catalog with writes), so it
/// doesn't fit either existing facility-admin provider's axis. See
/// 029_kmpdc_practitioners.sql and the sync-kmpdc-register Edge
/// Function for how the underlying data gets there.
///
/// This is NOT the same thing as provider_credentials.verification_status
/// (011_provider_verification.sql) -- that remains the sole,
/// platform-admin-only source of truth for whether a provider is
/// trusted on this platform. This provider only ever answers "what does
/// KMPDC's public data currently say," an informational cross-check.
class KmpdcVerificationProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<KmpdcPractitionerModel> _results = [];
  DateTime? _lastSyncedAt;
  bool _isSearching = false;
  bool _isSyncing = false;
  String? _error;

  List<KmpdcPractitionerModel> get results => _results;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSearching => _isSearching;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  /// Searches the local kmpdc_practitioners mirror by name (the only
  /// reliable key -- KMPDC never publishes full registration numbers).
  /// When [licenseNumber] is given, computes the SAME masking KMPDC
  /// applies (first 2 + last 1 character visible) and sorts rows whose
  /// masked_registration_no matches that pattern to the top -- never an
  /// exact-ID query, since the stored value is itself already masked.
  Future<void> search({required String name, String? licenseNumber}) async {
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      // Collapse repeated whitespace defensively -- KMPDC's own source
      // data has had real double-space artifacts (fixed at sync time,
      // see sync-kmpdc-register), and a user could paste/type extra
      // spaces too; either way an exact-substring ILIKE would otherwise
      // silently miss a real match over nothing but spacing.
      final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
      final rows = await _supabase
          .from('kmpdc_practitioners')
          .select('*')
          .ilike('full_name', '%$normalizedName%')
          .inFilter('cadre', ['medical_doctor', 'dentist', 'medical_intern', 'dental_intern'])
          .limit(50);

      var list = (rows as List).map((r) => KmpdcPractitionerModel.fromJson(r as Map<String, dynamic>)).toList();

      final maskedInput = _maskLike(licenseNumber);
      if (maskedInput != null) {
        list.sort((a, b) {
          final aMatch = a.maskedRegistrationNo == maskedInput;
          final bMatch = b.maskedRegistrationNo == maskedInput;
          if (aMatch == bMatch) return 0;
          return aMatch ? -1 : 1;
        });
      }

      _results = list;
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// True when [candidate]'s masked registration number exactly matches
  /// what [licenseNumber] masks down to -- the "Pattern matches ID on
  /// file" signal the Verification screen shows per result.
  bool matchesLicensePattern(KmpdcPractitionerModel candidate, String? licenseNumber) {
    final masked = _maskLike(licenseNumber);
    return masked != null && candidate.maskedRegistrationNo == masked;
  }

  String? _maskLike(String? fullId) {
    final id = fullId?.trim();
    if (id == null || id.length < 3) return null;
    return id[0] + id[1] + ('*' * (id.length - 3)) + id[id.length - 1];
  }

  /// Triggers the sync-kmpdc-register Edge Function. Safe to call as
  /// often as the UI wants -- the function itself no-ops (returns
  /// `skipped: true`) if the mirror was refreshed within the last ~20
  /// hours, so this never actually re-fetches KMPDC's site on every call.
  Future<void> triggerSync() async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _supabase.functions.invoke('sync-kmpdc-register');
    } on FunctionException catch (e) {
      final details = e.details;
      _error = (details is Map && details['error'] is String) ? details['error'] as String : 'Could not sync KMPDC data.';
    } catch (e) {
      _error = e.toString();
    }
    await _loadLastSyncedAt();
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> _loadLastSyncedAt() async {
    try {
      final row = await _supabase
          .from('kmpdc_practitioners')
          .select('synced_at')
          .order('synced_at', ascending: false)
          .limit(1)
          .maybeSingle();
      _lastSyncedAt = row == null ? null : DateTime.parse(row['synced_at'] as String);
    } catch (_) {
      // Best-effort -- the sync itself already surfaced any real error.
    }
  }
}
