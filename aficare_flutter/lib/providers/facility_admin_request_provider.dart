import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_admin_request_model.dart';

/// Manages facility admin requests: the anonymous "our facility wants to
/// join AfiCare" submission flow and the platform admin's review flow.
/// No account exists behind a request until it's approved -- approving
/// invokes the invite-facility-admin Edge Function, which creates the
/// account directly as role='facility_admin' (see
/// 017_facility_admin_invite_flow.sql). Follows the codebase's
/// "2-query, no embedded joins" convention (see CareTeamProvider) for
/// the facility name lookup.
class FacilityAdminRequestProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FacilityAdminRequestModel> _requests = [];
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'pending';
  String _searchQuery = '';

  List<FacilityAdminRequestModel> get requests => _requests;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<FacilityAdminRequestModel> get filteredRequests {
    var result = _requests;
    if (_statusFilter != 'all') {
      result = result.where((r) => r.status.name == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) =>
        r.applicantName.toLowerCase().contains(q) ||
        r.applicantEmail.toLowerCase().contains(q) ||
        (r.facilityName?.toLowerCase().contains(q) ?? false)
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

  /// A facility applying to join, with a named applicant -- no account
  /// required. RLS only allows this with user_id left null and status
  /// 'pending'.
  Future<bool> submitRequest({
    required String facilityId,
    required String applicantName,
    required String applicantEmail,
    String? title,
  }) async {
    try {
      await _supabase.from('facility_admin_requests').insert({
        'facility_id': facilityId,
        'applicant_name': applicantName,
        'applicant_email': applicantEmail,
        'title': title,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Admin: loads every request, newest first, with the facility's name
  /// attached from a follow-up query. Applicant name/email are stored
  /// directly on the row now (no account/join needed for those).
  Future<void> loadRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase
          .from('facility_admin_requests')
          .select('*')
          .order('created_at', ascending: false)
          .limit(500);

      final reqs = (rows as List)
          .map((json) => FacilityAdminRequestModel.fromJson(json))
          .toList();

      if (reqs.isEmpty) {
        _requests = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final facilityIds = reqs.map((r) => r.facilityId).toSet().toList();
      final facilities = await _supabase
          .from('facilities')
          .select('id, name')
          .inFilter('id', facilityIds);

      final facilityNameById = <String, String>{};
      for (final f in facilities as List) {
        facilityNameById[f['id'] as String] = f['name'] as String? ?? 'Unknown';
      }

      _requests = reqs
          .map((r) => r.copyWith(facilityName: facilityNameById[r.facilityId]))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin dashboard stat tile: a cheap count-only query.
  Future<void> loadPendingCount() async {
    try {
      final rows = await _supabase
          .from('facility_admin_requests')
          .select('id')
          .eq('status', 'pending')
          .limit(5000);
      _pendingCount = (rows as List).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Pending facility admin request count error: $e');
    }
  }

  /// Admin: approves a request via the invite-facility-admin Edge
  /// Function -- this is the only place a facility_admin account is
  /// ever created, and it's created directly with that role (never
  /// 'patient'). Slower than a plain RPC since it round-trips through
  /// Supabase Auth to send the actual invite email.
  Future<bool> approve(FacilityAdminRequestModel request) async {
    try {
      final response = await _supabase.functions.invoke(
        'invite-facility-admin',
        body: {
          'requestId': request.id,
          'email': request.applicantEmail,
          'fullName': request.applicantName,
          'facilityId': request.facilityId,
          'title': request.title,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['ok'] != true) {
        throw Exception((data?['error'] as String?) ?? 'Could not approve this request.');
      }
      await loadRequests();
      return true;
    } on FunctionException catch (e) {
      final details = e.details;
      _error = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Could not approve this request.';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Admin: rejects a request via the checked RPC, with a reason shown
  /// back to the applicant. No account is ever created for a rejected
  /// request.
  Future<bool> reject(String requestId, String reason) async {
    try {
      await _supabase.rpc('admin_reject_facility_admin_request', params: {
        'request_id': requestId,
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
