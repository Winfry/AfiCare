import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_credential_model.dart';

/// Manages provider license verification requests: the self-service
/// submission flow and the admin review flow.
///
/// Follows the codebase's "2-query, no embedded joins" convention (see
/// CareTeamProvider) — provider_credentials rows are fetched separately
/// from the matching users rows and merged in Dart, rather than relying
/// on a PostgREST embedded select.
class ProviderVerificationProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProviderCredentialModel> _requests = [];
  ProviderCredentialModel? _myRequest;
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'pending';
  String _searchQuery = '';

  List<ProviderCredentialModel> get requests => _requests;
  ProviderCredentialModel? get myRequest => _myRequest;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<ProviderCredentialModel> get filteredRequests {
    var result = _requests;
    if (_statusFilter != 'all') {
      result = result.where((r) => r.verificationStatus.name == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) =>
        (r.providerName?.toLowerCase().contains(q) ?? false) ||
        (r.providerEmail?.toLowerCase().contains(q) ?? false) ||
        r.licenseNumber.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  void setStatusFilter(String f) {
    _statusFilter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  /// Admin: loads every verification request, newest first, with the
  /// applicant's name/email attached from a second query.
  Future<void> loadRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase
          .from('provider_credentials')
          .select('*')
          .order('created_at', ascending: false)
          .limit(500);

      final credentials = (rows as List)
          .map((json) => ProviderCredentialModel.fromJson(json))
          .toList();

      if (credentials.isEmpty) {
        _requests = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final providerIds = credentials.map((c) => c.providerId).toSet().toList();
      final users = await _supabase
          .from('users')
          .select('id, full_name, email')
          .inFilter('id', providerIds);

      final nameById = <String, String>{};
      final emailById = <String, String>{};
      for (final u in users as List) {
        nameById[u['id'] as String] = u['full_name'] as String? ?? 'Unknown';
        emailById[u['id'] as String] = u['email'] as String? ?? '';
      }

      _requests = credentials
          .map((c) => c.copyWith(
                providerName: nameById[c.providerId],
                providerEmail: emailById[c.providerId],
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin dashboard stat tile: a cheap count-only query, so a dashboard
  /// visit doesn't pay for the full applicant-name join in [loadRequests].
  Future<void> loadPendingCount() async {
    try {
      final rows = await _supabase
          .from('provider_credentials')
          .select('id')
          .eq('verification_status', 'pending')
          .limit(5000);
      _pendingCount = (rows as List).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Pending verification count error: $e');
    }
  }

  /// Self-service: loads the current user's own request, if any, so the
  /// request screen can show status instead of the form.
  Future<void> loadMyRequest() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final row = await _supabase
          .from('provider_credentials')
          .select('*')
          .eq('provider_id', uid)
          .maybeSingle();

      _myRequest = row != null ? ProviderCredentialModel.fromJson(row) : null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Self-service: submits (or resubmits, after a rejection) a
  /// verification request. RLS enforces this can only ever be inserted
  /// as the caller's own row, in 'pending' status.
  Future<bool> submitRequest({
    required String licenseNumber,
    String? specialty,
    required String requestedRole,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _error = 'You must be logged in to request verification.';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.from('provider_credentials').insert({
        'provider_id': uid,
        'license_number': licenseNumber,
        'specialty': specialty,
        'requested_role': requestedRole,
      });
      await loadMyRequest();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Admin: approves a request via the checked RPC — this both marks the
  /// credential verified and promotes the user's role server-side.
  Future<bool> approve(String providerId) async {
    try {
      await _supabase.rpc('admin_verify_provider_license', params: {
        'target_user_id': providerId,
        'decision': 'verified',
      });
      await loadRequests();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Admin: rejects a request via the checked RPC, with a reason shown
  /// back to the applicant.
  Future<bool> reject(String providerId, String reason) async {
    try {
      await _supabase.rpc('admin_verify_provider_license', params: {
        'target_user_id': providerId,
        'decision': 'rejected',
        'reason': reason,
      });
      await loadRequests();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
