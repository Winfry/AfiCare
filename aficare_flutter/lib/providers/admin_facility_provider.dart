import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_model.dart';
import '../models/department_model.dart';
import '../models/provider_facility_model.dart';

class AdminFacilityProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FacilityModel> _facilities = [];
  List<DepartmentModel> _departments = [];
  List<ProviderFacilityModel> _facilityProviders = [];
  List<Map<String, dynamic>> _providerSearchResults = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _typeFilter = 'all';

  List<FacilityModel> get facilities => _facilities;
  List<DepartmentModel> get departments => _departments;
  List<ProviderFacilityModel> get facilityProviders => _facilityProviders;
  List<Map<String, dynamic>> get providerSearchResults => _providerSearchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;

  List<FacilityModel> get filteredFacilities {
    var result = _facilities;
    if (_typeFilter != 'all') {
      result = result.where((f) => f.type == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((f) =>
        f.name.toLowerCase().contains(q) ||
        (f.county?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return result;
  }

  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// With 10,000+ facilities (the full KMHFL list), [loadFacilities]
  /// deliberately only loads a recent-200 browse page — searching must hit
  /// the database directly rather than filter what's already in memory, or
  /// anything outside that first page would silently appear "not found".
  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyServerFilters);
  }

  void setTypeFilter(String f) {
    _typeFilter = f;
    notifyListeners();
    _applyServerFilters();
  }

  /// Queries the database with whatever search text / type filter is
  /// currently set, replacing [_facilities] with the matches (up to 500).
  /// Falls back to the plain recent-200 browse view when both are cleared.
  Future<void> _applyServerFilters() async {
    if (_searchQuery.isEmpty && _typeFilter == 'all') {
      await loadFacilities();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var query = _supabase.from('facilities').select('*');
      if (_typeFilter != 'all') {
        query = query.eq('type', _typeFilter);
      }
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }
      final response = await query.order('name', ascending: true).limit(500);

      _facilities = (response as List)
          .map((json) => FacilityModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFacilities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('facilities')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);

      _facilities = (response as List)
          .map((json) => FacilityModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addFacility(Map<String, dynamic> data) async {
    try {
      await _supabase.from('facilities').insert(data);
      await loadFacilities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateFacility(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('facilities').update(data).eq('id', id);
      await loadFacilities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFacility(String id) async {
    try {
      await _supabase.from('facilities').delete().eq('id', id);
      await loadFacilities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadDepartments(String facilityId) async {
    try {
      final response = await _supabase
          .from('departments')
          .select('*')
          .eq('facility_id', facilityId)
          .order('name');
      _departments = (response as List)
          .map((json) => DepartmentModel.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addDepartment(Map<String, dynamic> data) async {
    try {
      await _supabase.from('departments').insert(data);
      await loadDepartments(data['facility_id'] as String);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, int>> getFacilityStats(String facilityId) async {
    try {
      final providers = await _supabase
          .from('users')
          .select('id')
          .eq('facility_id', facilityId)
          .neq('role', 'patient');
      final depts = await _supabase
          .from('departments')
          .select('id')
          .eq('facility_id', facilityId);
      return {
        'providers': (providers as List).length,
        'departments': (depts as List).length,
      };
    } catch (e) {
      return {'providers': 0, 'departments': 0};
    }
  }

  /// Loads the roster of providers linked to a facility (provider_facilities
  /// joined to users, done as two queries per the codebase's no-embedded-
  /// join convention — see CareTeamProvider).
  Future<void> loadFacilityProviders(String facilityId) async {
    try {
      final links = await _supabase
          .from('provider_facilities')
          .select('*')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false);

      final rows = links as List;
      if (rows.isEmpty) {
        _facilityProviders = [];
        notifyListeners();
        return;
      }

      final providerIds = rows.map((r) => r['provider_id'] as String).toSet().toList();
      final users = await _supabase
          .from('users')
          .select('id, full_name')
          .inFilter('id', providerIds);

      final nameById = <String, String>{
        for (final u in users as List) u['id'] as String: u['full_name'] as String? ?? 'Unknown',
      };

      _facilityProviders = rows
          .map((r) => ProviderFacilityModel.fromJson(r as Map<String, dynamic>)
              .copyWith(providerName: nameById[r['provider_id']]))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Searches verified providers by name for the "add provider to this
  /// facility" picker. Two-query: search users by name, then keep only
  /// the ones with a verified provider_credentials row — an unverified
  /// person should never show up as linkable staff.
  Future<void> searchVerifiedProviders(String query) async {
    if (query.trim().isEmpty) {
      _providerSearchResults = [];
      notifyListeners();
      return;
    }
    try {
      final candidates = await _supabase
          .from('users')
          .select('id, full_name, email')
          .ilike('full_name', '%$query%')
          .limit(20);

      final ids = (candidates as List).map((u) => u['id'] as String).toList();
      if (ids.isEmpty) {
        _providerSearchResults = [];
        notifyListeners();
        return;
      }

      final verified = await _supabase
          .from('provider_credentials')
          .select('provider_id, specialty')
          .inFilter('provider_id', ids)
          .eq('verification_status', 'verified');

      final specialtyById = <String, String?>{
        for (final v in verified as List) v['provider_id'] as String: v['specialty'] as String?,
      };

      _providerSearchResults = candidates
          .where((u) => specialtyById.containsKey(u['id']))
          .map((u) => {
                'id': u['id'],
                'full_name': u['full_name'],
                'email': u['email'],
                'specialty': specialtyById[u['id']],
              })
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> linkProviderToFacility(
    String providerId,
    String facilityId, {
    String? specialty,
    bool isPrimary = false,
  }) async {
    try {
      await _supabase.rpc('admin_link_provider_to_facility', params: {
        'target_user_id': providerId,
        'target_facility_id': facilityId,
        'provider_specialty': specialty,
        'make_primary': isPrimary,
      });
      await loadFacilityProviders(facilityId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlinkProviderFromFacility(String providerId, String facilityId) async {
    try {
      await _supabase.rpc('admin_unlink_provider_from_facility', params: {
        'target_user_id': providerId,
        'target_facility_id': facilityId,
      });
      await loadFacilityProviders(facilityId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}