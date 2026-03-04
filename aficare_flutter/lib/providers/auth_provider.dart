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
      // Check if user is already logged in
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _loadUserProfile(session.user.id);
      }

      // Listen to auth state changes
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

  // Sign Up
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
      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create account');
      }

      // Generate MediLink ID for patients
      String? medilinkId;
      if (role == UserRole.patient) {
        medilinkId = UserModel.generateMedilinkId();
      }

      // Build user profile record
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
        userRecord['facility_id'] = facilityId;
      }

      // Create user profile
      await _supabase.from('users').insert(userRecord);

      // Load the user profile so currentUser is available before navigating
      await _loadUserProfile(authResponse.user!.id);

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

  // Sign In
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

      // Wait for the user profile to load before navigating
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

  // Sign In with MediLink ID
  Future<bool> signInWithMedilinkId({
    required String medilinkId,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find user by MediLink ID
      final response = await _supabase
          .from('users')
          .select('email')
          .eq('medilink_id', medilinkId)
          .single();

      final email = response['email'] as String;

      // Sign in with email
      return await signIn(email: email, password: password);
    } catch (e) {
      _error = 'Invalid MediLink ID or password';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Update profile (name, phone, metadata — e.g. blood type, prefs)
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

  // Reset Password
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
