import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  String? _error;
  DateTimeRange? _dateRange;
  String _actionFilter = 'all';
  String _userFilter = '';

  List<Map<String, dynamic>> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTimeRange? get dateRange => _dateRange;
  String get actionFilter => _actionFilter;
  String get userFilter => _userFilter;

  void setDateRange(DateTimeRange? range) { _dateRange = range; notifyListeners(); }
  void setActionFilter(String f) { _actionFilter = f; notifyListeners(); }
  void setUserFilter(String u) { _userFilter = u; notifyListeners(); }

  List<String> get uniqueActions {
    return _logs.map((l) => l['action'] as String).toSet().toList()..sort();
  }

  List<Map<String, dynamic>> get filteredLogs {
    var result = _logs;
    if (_dateRange != null) {
      result = result.where((l) {
        final ts = DateTime.parse(l['timestamp'] as String);
        return ts.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
               ts.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    if (_actionFilter != 'all') {
      result = result.where((l) => l['action'] == _actionFilter).toList();
    }
    if (_userFilter.isNotEmpty) {
      final q = _userFilter.toLowerCase();
      result = result.where((l) =>
        (l['user_id'] as String?)?.toLowerCase().contains(q) ?? false
      ).toList();
    }
    return result;
  }

  Future<void> loadLogs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('audit_log')
          .select('*, users!audit_log_user_id_fkey(full_name, email)')
          .order('timestamp', ascending: false)
          .limit(500);

      _logs = List<Map<String, dynamic>>.from(response as List);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logEvent({
    required String action,
    String? userId,
    String? patientId,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _supabase.from('audit_log').insert({
        'action': action,
        'user_id': userId,
        'patient_id': patientId,
        'details': details ?? {},
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Audit log error: $e');
      return false;
    }
  }

  String? getActionLabel(String action) {
    final labels = {
      'user_created': 'User Created',
      'user_updated': 'User Updated',
      'user_suspended': 'User Suspended',
      'referral_created': 'Referral Created',
      'referral_updated': 'Referral Updated',
      'consultation_created': 'Consultation Created',
      'prescription_created': 'Prescription Created',
      'record_deleted': 'Record Deleted',
      'facility_created': 'Facility Created',
      'facility_updated': 'Facility Updated',
      'login': 'Login',
      'logout': 'Logout',
    };
    return labels[action] ?? action;
  }
}