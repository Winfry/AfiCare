import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dependent_profile_model.dart';

class DependentProvider extends ChangeNotifier {
  String? _ownId;
  String? _activePatientId;
  List<DependentProfileModel> _dependents = [];
  bool _isLoading = false;
  String? _error;

  String? get ownId => _ownId;

  /// The currently active patient UUID (own profile or a dependent).
  String? get activePatientId => _activePatientId ?? _ownId;

  List<DependentProfileModel> get dependents => _dependents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when viewing a dependent profile rather than own profile.
  bool get isViewingDependent =>
      _activePatientId != null &&
      _ownId != null &&
      _activePatientId != _ownId;

  /// The currently viewed dependent, or null if viewing own profile.
  DependentProfileModel? get activeDependent {
    if (!isViewingDependent) return null;
    try {
      return _dependents.firstWhere((d) => d.id == _activePatientId);
    } catch (_) {
      return null;
    }
  }

  /// Called during dashboard init with the authenticated user's UUID.
  /// Resets state if a different user is detected (e.g. after logout/re-login).
  void setOwnId(String id) {
    if (_ownId != id) {
      // Different user — full reset to own profile
      _ownId = id;
      _activePatientId = id;
      _dependents = [];
    }
    // If same user, preserve the current _activePatientId (may be a dependent)
    notifyListeners();
  }

  /// Switch the active profile to [patientId] (own UUID or a dependent UUID).
  void switchTo(String patientId) {
    _activePatientId = patientId;
    notifyListeners();
  }

  Future<void> loadDependents(String guardianId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await Supabase.instance.client
          .from('dependent_profiles')
          .select()
          .eq('guardian_id', guardianId)
          .order('created_at');
      _dependents = (response as List)
          .map((j) => DependentProfileModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDependent({
    required String guardianId,
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
    required String relationship,
    String? bloodType,
    String? notes,
  }) async {
    try {
      final medilinkId = DependentProfileModel.generateMedilinkId();
      await Supabase.instance.client.from('dependent_profiles').insert({
        'guardian_id': guardianId,
        'full_name': fullName,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'gender': gender,
        'relationship': relationship,
        'blood_type': bloodType,
        'medilink_id': medilinkId,
        'notes': notes,
      });
      await loadDependents(guardianId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDependent(
    String id, {
    required String guardianId,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? relationship,
    String? bloodType,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (dateOfBirth != null) {
        updates['date_of_birth'] =
            dateOfBirth.toIso8601String().split('T').first;
      }
      if (gender != null) updates['gender'] = gender;
      if (relationship != null) updates['relationship'] = relationship;
      if (bloodType != null) updates['blood_type'] = bloodType;
      if (notes != null) updates['notes'] = notes;

      await Supabase.instance.client
          .from('dependent_profiles')
          .update(updates)
          .eq('id', id);
      await loadDependents(guardianId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDependent(String id, String guardianId) async {
    try {
      await Supabase.instance.client
          .from('dependent_profiles')
          .delete()
          .eq('id', id);
      // If we were viewing this dependent, switch back to own profile
      if (_activePatientId == id) {
        _activePatientId = _ownId;
      }
      await loadDependents(guardianId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
