import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_model.dart';
import '../models/department_model.dart';

class AdminFacilityProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<FacilityModel> _facilities = [];
  List<DepartmentModel> _departments = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _typeFilter = 'all';

  List<FacilityModel> get facilities => _facilities;
  List<DepartmentModel> get departments => _departments;
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

  void setSearchQuery(String q) { _searchQuery = q; notifyListeners(); }
  void setTypeFilter(String f) { _typeFilter = f; notifyListeners(); }

  Future<void> loadFacilities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('facilities')
          .select('*')
          .order('created_at', ascending: false);

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
}