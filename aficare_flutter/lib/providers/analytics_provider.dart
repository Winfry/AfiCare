import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  String _periodFilter = 'this_month';
  String _facilityFilter = 'all';

  int _totalUsers = 0;
  int _activeProviders = 0;
  int _referralsThisMonth = 0;
  int _missedAppointments = 0;
  int _totalConsultations = 0;
  int _totalFacilities = 0;

  List<Map<String, dynamic>> _usersOverTime = [];
  List<Map<String, dynamic>> _referralsByFacility = [];
  List<Map<String, dynamic>> _roleDistribution = [];
  List<Map<String, dynamic>> _triageBreakdown = [];
  List<Map<String, dynamic>> _appointmentTrend = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get periodFilter => _periodFilter;
  String get facilityFilter => _facilityFilter;

  int get totalUsers => _totalUsers;
  int get activeProviders => _activeProviders;
  int get referralsThisMonth => _referralsThisMonth;
  int get missedAppointments => _missedAppointments;
  int get totalConsultations => _totalConsultations;
  int get totalFacilities => _totalFacilities;

  List<Map<String, dynamic>> get usersOverTime => _usersOverTime;
  List<Map<String, dynamic>> get referralsByFacility => _referralsByFacility;
  List<Map<String, dynamic>> get roleDistribution => _roleDistribution;
  List<Map<String, dynamic>> get triageBreakdown => _triageBreakdown;
  List<Map<String, dynamic>> get appointmentTrend => _appointmentTrend;

  void setPeriodFilter(String f) { _periodFilter = f; notifyListeners(); }
  void setFacilityFilter(String f) { _facilityFilter = f; notifyListeners(); }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadCounts(),
        _loadUsersOverTime(),
        _loadReferralsByFacility(),
        _loadRoleDistribution(),
        _loadTriageBreakdown(),
        _loadAppointmentTrend(),
      ]);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCounts() async {
    try {
      final allUsers = await _supabase.from('users').select('id');
      _totalUsers = (allUsers as List).length;

      final activeProv = await _supabase
          .from('users')
          .select('id')
          .neq('role', 'patient')
          .eq('status', 'active');
      _activeProviders = (activeProv as List).length;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      final referrals = await _supabase
          .from('referrals')
          .select('id')
          .gte('created_at', monthStart);
      _referralsThisMonth = (referrals as List).length;

      final cancelled = await _supabase
          .from('appointments')
          .select('id')
          .eq('status', 'cancelled');
      _missedAppointments = (cancelled as List).length;

      final consultations = await _supabase.from('consultations').select('id');
      _totalConsultations = (consultations as List).length;

      final facilities = await _supabase.from('facilities').select('id');
      _totalFacilities = (facilities as List).length;
    } catch (e) {
      debugPrint('Counts error: $e');
    }
  }

  Future<void> _loadUsersOverTime() async {
    try {
      final response = await _supabase
          .from('users')
          .select('created_at')
          .order('created_at');
      final counts = <String, int>{};
      for (final r in response as List) {
        final date = (r['created_at'] as String).substring(0, 10);
        counts[date] = (counts[date] ?? 0) + 1;
      }
      _usersOverTime = counts.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } catch (e) {
      debugPrint('Users over time error: $e');
    }
  }

  Future<void> _loadReferralsByFacility() async {
    try {
      final response = await _supabase
          .from('referrals')
          .select('to_facility');
      final counts = <String, int>{};
      for (final r in response as List) {
        final f = (r['to_facility'] as String?) ?? 'Unknown';
        counts[f] = (counts[f] ?? 0) + 1;
      }
      _referralsByFacility = counts.entries
          .map((e) => {'facility': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      debugPrint('Referrals by facility error: $e');
    }
  }

  Future<void> _loadRoleDistribution() async {
    try {
      final response = await _supabase.from('users').select('role');
      final counts = <String, int>{};
      for (final r in response as List) {
        final role = r['role'] as String;
        counts[role] = (counts[role] ?? 0) + 1;
      }
      _roleDistribution = counts.entries
          .map((e) => {'role': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      debugPrint('Role distribution error: $e');
    }
  }

  Future<void> _loadTriageBreakdown() async {
    try {
      final response = await _supabase
          .from('triage_assessments')
          .select('triage_level');
      final counts = <String, int>{};
      for (final r in response as List) {
        final level = r['triage_level'] as String;
        counts[level] = (counts[level] ?? 0) + 1;
      }
      _triageBreakdown = counts.entries
          .map((e) => {'level': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      debugPrint('Triage breakdown error: $e');
    }
  }

  Future<void> _loadAppointmentTrend() async {
    try {
      final response = await _supabase
          .from('appointments')
          .select('scheduled_at')
          .order('scheduled_at');
      final counts = <String, int>{};
      for (final r in response as List) {
        final date = (r['scheduled_at'] as String).substring(0, 10);
        counts[date] = (counts[date] ?? 0) + 1;
      }
      _appointmentTrend = counts.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } catch (e) {
      debugPrint('Appointment trend error: $e');
    }
  }
}