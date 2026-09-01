import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/care_team_member_model.dart';
import '../models/user_model.dart';

class CareTeamProvider extends ChangeNotifier {
  List<CareTeamMemberModel> _members = [];
  List<UserModel> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  List<CareTeamMemberModel> get members => _members;
  List<UserModel> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load care team members for [patientId] (own UUID or dependent UUID).
  Future<void> loadCareTeam(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final teamResponse = await Supabase.instance.client
          .from('care_team')
          .select()
          .eq('patient_id', patientId)
          .order('created_at');

      final teamRows = teamResponse as List;
      if (teamRows.isEmpty) {
        _members = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch provider details separately to avoid join syntax issues
      final providerIds =
          teamRows.map((r) => (r['provider_id'] as String? ?? '').isEmpty
              ? null
              : r['provider_id'] as String).whereType<String>().toList();
      if (providerIds.isEmpty) {
        _members = [];
        _isLoading = false;
        notifyListeners();
        return;
      }
      final usersResponse = await Supabase.instance.client
          .from('users')
          .select('id, full_name, role, department, gender')
          .inFilter('id', providerIds);

      final userMap = <String, Map<String, dynamic>>{};
      for (final u in usersResponse as List) {
        userMap[u['id'] as String] = u as Map<String, dynamic>;
      }

      _members = teamRows.map((row) {
        final r = row as Map<String, dynamic>;
        final u = userMap[r['provider_id'] as String] ?? {};
        return CareTeamMemberModel.fromJson({
          ...r,
          'provider_name': u['full_name'] ?? 'Unknown Provider',
          'provider_role': u['role'] ?? 'doctor',
          'provider_department': u['department'],
          'provider_gender': u['gender'],
        });
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch providers from past appointments not yet in the care team.
  /// Uses appointments table only (works for both own profile and dependents).
  Future<void> fetchSuggestions(String patientId) async {
    try {
      final existingIds = _members.map((m) => m.providerId).toSet();

      final aptResponse = await Supabase.instance.client
          .from('appointments')
          .select('provider_id')
          .eq('patient_id', patientId)
          .order('scheduled_at', ascending: false)
          .limit(20);

      final providerIds = (aptResponse as List)
          .map((r) => r['provider_id'] as String)
          .where((id) => !existingIds.contains(id))
          .toSet()
          .toList();

      if (providerIds.isEmpty) {
        _suggestions = [];
        notifyListeners();
        return;
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('id', providerIds);

      _suggestions = (userResponse as List)
          .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      // Non-critical — suggestions can fail silently
    }
  }

  Future<bool> addMember(
    String patientId,
    String providerId, {
    String? specialtyLabel,
    bool isPrimary = false,
  }) async {
    try {
      await Supabase.instance.client.from('care_team').insert({
        'patient_id': patientId,
        'provider_id': providerId,
        'specialty_label': specialtyLabel,
        'is_primary': isPrimary,
      });
      await loadCareTeam(patientId);
      // Refresh suggestions after adding a member
      await fetchSuggestions(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCustomMember(String patientId, String customName) async {
    try {
      await Supabase.instance.client.from('care_team').insert({
        'patient_id': patientId,
        'provider_id': patientId,
        'specialty_label': customName,
        'is_primary': false,
        'notes': 'custom',
      });
      await loadCareTeam(patientId);
      await fetchSuggestions(patientId);
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        _error = 'This custom provider is already in your care team.';
      } else {
        _error = msg;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String memberId, String patientId) async {
    try {
      await Supabase.instance.client
          .from('care_team')
          .delete()
          .eq('id', memberId);
      await loadCareTeam(patientId);
      await fetchSuggestions(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLabel(
    String memberId,
    String patientId,
    String? newLabel,
  ) async {
    try {
      await Supabase.instance.client
          .from('care_team')
          .update({'specialty_label': newLabel})
          .eq('id', memberId);
      await loadCareTeam(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMemberNotes(
    String memberId,
    String patientId,
    String? phone,
    String? hospital,
  ) async {
    try {
      final notesMap = <String, dynamic>{};
      if (phone != null && phone.isNotEmpty) notesMap['phone'] = phone;
      if (hospital != null && hospital.isNotEmpty) notesMap['hospital'] = hospital;
      final notes = notesMap.isNotEmpty ? jsonEncode(notesMap) : null;
      await Supabase.instance.client
          .from('care_team')
          .update({'notes': notes})
          .eq('id', memberId);
      await loadCareTeam(patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
