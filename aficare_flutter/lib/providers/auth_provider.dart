import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/router.dart' show updateRouterProfile;

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  AuthProvider() {
    _initAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  void _initAuth() {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _loadUserProfile(session.user.id);
      }

      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          // Only load if we don't already have this user — avoids
          // racing with the explicit call in signUp / signIn methods.
          if (_currentUser?.id != session.user.id) {
            _loadUserProfile(session.user.id);
          }
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          updateRouterProfile(null);
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('AuthProvider init error: $e');
      _error = 'Authentication service unavailable';
    }
  }

  Future<void> _loadUserProfile(String userId, {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          _currentUser = UserModel.fromJson(response);
          _error = null;
          updateRouterProfile(_currentUser);
          notifyListeners();
          return;
        }

        // Row not visible yet — wait and retry (eventual consistency)
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        debugPrint('Error loading user profile (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        } else {
          _error = 'Could not load your profile. '
              'If your computer clock is wrong, sync it and try again. '
              'Details: $e';
          notifyListeners();
        }
      }
    }

    // All retries exhausted — row doesn't exist
    _error = _error ?? 'Your profile was not found. Please try logging in again.';
    notifyListeners();
  }

  // ── Patient direct registration (phone + PIN, no OTP) ───────────────

  /// Creates a patient account using [phone] + [pin] (6 digits) + [fullName].
  /// PIN hashing, Supabase auth password derivation, and the account
  /// creation itself all happen inside the `patient-auth` Edge Function —
  /// this client never sees the PIN hash or the derivation secret.
  /// Patients are auto-logged in on success.
  Future<bool> signUpPatientDirect({
    required String phone,
    required String fullName,
    required String pin,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (pin.length != 6 || int.tryParse(pin) == null) {
        throw Exception('PIN must be exactly 6 digits.');
      }

      final response = await _supabase.functions.invoke(
        'patient-auth',
        body: {
          'action': 'register',
          'phone': phone,
          'pin': pin,
          'fullName': fullName,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final accessToken = data?['access_token'] as String?;
      final refreshToken = data?['refresh_token'] as String?;

      if (accessToken == null || refreshToken == null) {
        // Account may still have been created (e.g. the immediate sign-in
        // failed) — surface the server's message rather than assume failure.
        throw Exception(
            (data?['error'] as String?) ?? 'Failed to create account. Please try again.');
      }

      final authResponse = await _supabase.auth.setSession(refreshToken);
      if (authResponse.user == null) {
        throw Exception('Account created but sign-in failed. Please try logging in.');
      }

      await _loadUserProfile(authResponse.user!.id);

      if (_currentUser == null) {
        throw Exception(
            'Your profile could not be loaded after registration. '
            'Please try logging in.');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FunctionException catch (e) {
      final details = e.details;
      _error = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Failed to create account. Please try again.';
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

  // ── Patient phone + PIN sign in ─────────────────────────────────────

  /// Signs in a patient using [phone] + [pin]. The lookup, bcrypt
  /// verification, lockout enforcement, and password derivation all
  /// happen inside the `patient-auth` Edge Function — the PIN hash is
  /// never fetched by this client.
  Future<bool> signInWithPhoneAndPin({
    required String phone,
    required String pin,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.functions.invoke(
        'patient-auth',
        body: {'action': 'login', 'phone': phone, 'pin': pin},
      );

      final data = response.data as Map<String, dynamic>?;
      final refreshToken = data?['refresh_token'] as String?;
      if (refreshToken == null) {
        throw Exception((data?['error'] as String?) ?? 'Invalid phone number or PIN.');
      }

      final authResponse = await _supabase.auth.setSession(refreshToken);
      if (authResponse.user == null) {
        throw Exception('Authentication failed. Please try again.');
      }

      await _loadUserProfile(authResponse.user!.id);

      // Verify profile actually loaded
      if (_currentUser == null) {
        throw Exception(
            'Your profile could not be loaded. '
            'Please try again or contact support.');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FunctionException catch (e) {
      final details = e.details;
      _error = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Invalid phone number or PIN.';
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

  // ── Email/password sign up (providers) ──────────────────────────────

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    String? facilityId,
    String? department,
    String? orgName,
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

      // If admin registered with an org name, create a facility first
      String? resolvedFacilityId = facilityId;
      if (orgName != null && orgName.trim().isNotEmpty && resolvedFacilityId == null) {
        final facilityResp = await _supabase
            .from('facilities')
            .insert({
              'name': orgName.trim(),
              'type': 'clinic',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        resolvedFacilityId = facilityResp['id'] as String;
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
      if (resolvedFacilityId != null) {
        userRecord['hospital_id'] = resolvedFacilityId;
        userRecord['facility_id'] = resolvedFacilityId;
      }
      if (department != null && department.trim().isNotEmpty) {
        userRecord['department'] = department.trim();
      }

      await _supabase.from('users').insert(userRecord);
      await _loadUserProfile(authResponse.user!.id);

      if (_currentUser == null) {
        throw Exception(
            'Your profile could not be loaded after registration. '
            'Please try logging in.');
      }

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

      if (response.user == null) {
        throw Exception('Authentication failed. Please try again.');
      }

      await _loadUserProfile(response.user!.id);

      if (_currentUser == null) {
        throw Exception(
            'Your profile could not be loaded. '
            'Please try again or contact support.');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
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
          .maybeSingle();

      final email = response?['email'] as String?;
      if (email == null) {
        _error = 'Invalid MediLink ID or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
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
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error during Supabase signOut: $e');
    }
    // Always clear local state even if remote signOut fails
    _currentUser = null;
    _error = null;
    updateRouterProfile(null);
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
