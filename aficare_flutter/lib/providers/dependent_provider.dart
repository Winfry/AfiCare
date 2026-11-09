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

  /// Whether the last load failed. Kept apart from [error], which a
  /// failed save also sets (that used to show as "could not load").
  bool get loadFailed => _loadFailed;
  bool _loadFailed = false;

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
    _loadFailed = false;
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
      debugPrint('Loading dependants failed: $e');
      _error = "We couldn't load the profiles you manage.";
      _loadFailed = true;
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
    List<String>? allergies,
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
        if (allergies != null) 'allergies': allergies,
        'medilink_id': medilinkId,
        'notes': notes,
      });
      await loadDependents(guardianId);
      return true;
    } catch (e) {
      debugPrint('Adding a dependant failed: $e');
      _error = "We couldn't add this person. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }

  /// Saves the edit form. Date of birth, gender and blood type are always
  /// sent, so choosing "Not known" (null) clears a wrong value; before,
  /// a null was skipped and the wrong value stayed.
  Future<bool> updateDependent(
    String id, {
    required String guardianId,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    String? relationship,
    String? bloodType,
    List<String>? allergies,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      updates['date_of_birth'] = dateOfBirth?.toIso8601String().split('T').first;
      updates['gender'] = gender;
      if (relationship != null) updates['relationship'] = relationship;
      updates['blood_type'] = bloodType;
      // Passed explicitly so an empty list can clear the list, which a
      // null-means-skip check would make impossible.
      if (allergies != null) updates['allergies'] = allergies;
      if (notes != null) updates['notes'] = notes;

      // .select() so an update the database quietly refused is caught.
      final rows = await Supabase.instance.client
          .from('dependent_profiles')
          .update(updates)
          .eq('id', id)
          .select('id');
      if ((rows as List).isEmpty) throw StateError('nothing was updated');
      await loadDependents(guardianId);
      return true;
    } catch (e) {
      debugPrint('Updating a dependant failed: $e');
      _error = "We couldn't save these changes. Check your connection and try again.";
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
      debugPrint('Removing a dependant failed: $e');
      _error = "We couldn't remove this profile. Check your connection and try again.";
      notifyListeners();
      return false;
    }
  }
}
