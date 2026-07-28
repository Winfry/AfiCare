import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _loadUserProfile(session.user.id);
      }

      _supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          _loadUserProfile(session.user.id);
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('AuthProvider init error: $e');
      _error = 'Authentication service unavailable';
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromJson(response);
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _error = 'Profile load failed: $e';
      notifyListeners();
    }
  }

  // ── Patient phone-OTP registration ─────────────────────────────────

  /// Sends an OTP via SMS to [phone] (must be in E.164 format).
  /// Stores [fullName] locally so it can be used after OTP verification.
  Future<bool> signUpPatient({
    required String phone,
    required String fullName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.auth.signInWithOtp(
        phone: phone,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifies the OTP sent to [phone]. On success, creates a patient
  /// record in the users table and sets [currentUser].
  Future<bool> verifyPatientOtp({
    required String phone,
    required String otp,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user == null) {
        throw Exception('Verification failed. Please try again.');
      }

      final userId = response.user!.id;
      final placeholderEmail = '${phone.replaceAll('+', '')}@patient.aficare';

      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('users').insert({
          'id': userId,
          'email': placeholderEmail,
          'full_name': '',
          'role': 'patient',
          'phone': phone,
          'medilink_id': UserModel.generateMedilinkId(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await _loadUserProfile(userId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Email/password sign up (providers) ──────────────────────────────

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    String? facilityId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create account');
      }

      String? medilinkId;
      if (role == UserRole.patient) {
        medilinkId = UserModel.generateMedilinkId();
      }

      final userRecord = <String, dynamic>{
        'id': authResponse.user!.id,
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'phone': phone,
        'medilink_id': medilinkId,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (facilityId != null) {
        userRecord['hospital_id'] = facilityId;
        userRecord['facility_id'] = facilityId;
      }

      await _supabase.from('users').insert(userRecord);
      await _loadUserProfile(authResponse.user!.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      if (e.statusCode == '422' || e.message.contains('already registered')) {
        _error = 'An account with this email already exists. Please log in instead.';
      } else {
        _error = e.message;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Sign In ─────────────────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithMedilinkId({
    required String medilinkId,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('users')
          .select('email')
          .eq('medilink_id', medilinkId)
          .single();

      final email = response['email'] as String;
      return await signIn(email: email, password: password);
    } catch (e) {
      _error = 'Invalid MediLink ID or password';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ── Update profile ──────────────────────────────────────────────────

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) return false;
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (metadata != null) updates['metadata'] = metadata;
      await _supabase.from('users').update(updates).eq('id', _currentUser!.id);
      await _loadUserProfile(_currentUser!.id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // ── Reset Password ──────────────────────────────────────────────────

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}
