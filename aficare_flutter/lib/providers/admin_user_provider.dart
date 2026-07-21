import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AdminUserProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  Set<String> _selectedIds = {};

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get roleFilter => _roleFilter;
  String get statusFilter => _statusFilter;
  Set<String> get selectedIds => _selectedIds;

  List<UserModel> get filteredUsers {
    var result = _users;
    if (_roleFilter != 'all') {
      result = result.where((u) => u.role.name == _roleFilter).toList();
    }
    if (_statusFilter != 'all') {
      result = result.where((u) => u.status.name == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        (u.medilinkId?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return result;
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setRoleFilter(String f) {
    _roleFilter = f;
    notifyListeners();
  }

  void setStatusFilter(String f) {
    _statusFilter = f;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(List<UserModel> users) {
    _selectedIds = users.map((u) => u.id).toSet();
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);

      _users = (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _supabase
          .from('users')
          .update({'role': newRole.name})
          .eq('id', userId);
      await loadUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserStatus(String userId, UserStatus status) async {
    try {
      await _supabase
          .from('users')
          .update({'status': status.name})
          .eq('id', userId);
      await loadUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> inviteUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? facilityId,
  }) async {
    try {
      await _supabase.from('users').insert({
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'status': 'invited',
        'facility_id': facilityId,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> bulkUpdateStatus(Set<String> ids, UserStatus status) async {
    try {
      for (final id in ids) {
        await _supabase
            .from('users')
            .update({'status': status.name})
            .eq('id', id);
      }
      _selectedIds.clear();
      await loadUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String userId) async {
    try {
      final user = _users.firstWhere((u) => u.id == userId);
      await _supabase.auth.resetPasswordForEmail(user.email);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}