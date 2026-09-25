import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nck_nurse_model.dart';

/// Nurse verification against the Nursing Council of Kenya (NCK)'s
/// public register -- the nurse counterpart to KmpdcVerificationProvider
/// (doctors/dentists). Deliberately simpler: NCK's own site is already a
/// per-query search endpoint (see verify-nck-register), so there is no
/// local mirror table, no staleness, and no triggerSync -- every search
/// is answered live.
///
/// This is NOT the same thing as provider_credentials.verification_status
/// -- that remains the sole, platform-admin-only source of truth for
/// platform trust. This provider only ever answers "what does NCK's
/// public register currently say," an informational cross-check.
class NckVerificationProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<NckNurseModel> _results = [];
  bool _isSearching = false;
  String? _error;

  List<NckNurseModel> get results => _results;
  bool get isSearching => _isSearching;
  String? get error => _error;

  Future<void> search({required String name}) async {
    final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.isEmpty) return;

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _supabase.functions.invoke('verify-nck-register', body: {'name': normalizedName});
      final data = res.data as Map<String, dynamic>;
      final rows = (data['results'] as List? ?? []);
      _results = rows.map((r) => NckNurseModel.fromJson(r as Map<String, dynamic>)).toList();
    } on FunctionException catch (e) {
      final details = e.details;
      _error = (details is Map && details['error'] is String) ? details['error'] as String : 'Could not check NCK\'s register.';
      _results = [];
    } catch (e) {
      _error = e.toString();
      _results = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// True when [candidate]'s full license number exactly matches
  /// [licenseNumber] -- unlike KMPDC's masked pattern match, NCK
  /// publishes full numbers so this can be a real exact-match check.
  bool matchesLicense(NckNurseModel candidate, String? licenseNumber) {
    final input = licenseNumber?.trim();
    if (input == null || input.isEmpty) return false;
    return candidate.licenseNumber == input;
  }
}
