import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/referral_model.dart';

class ReferralProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ReferralModel> _referrals = [];
  bool _isLoading = false;
  String? _error;

  List<ReferralModel> get referrals => _referrals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Who referred each referral loaded for a patient, by referral id.
  Map<String, String> get referrerNames => _referrerNames;
  Map<String, String> _referrerNames = {};

  /// The referrals of [patientId], an account or a dependant profile,
  /// through `my_referrals()` (migration 048). It finds them however they
  /// were saved (doctors use the MediLink ID, CHWs the account id) and
  /// only for the person themselves or the guardian of that dependant.
  Future<void> loadPatientReferrals(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.rpc('my_referrals', params: {'p_patient_id': patientId});
      final rows = [for (final r in response as List) Map<String, dynamic>.from(r as Map)];
      _referrals = rows.map(ReferralModel.fromJson).toList();
      _referrerNames = {
        for (final r in rows)
          if ((r['from_provider_name'] as String?)?.trim().isNotEmpty ?? false)
            r['id'] as String: (r['from_provider_name'] as String).trim(),
      };
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('my_referrals failed: $e');
      _referrals = [];
      _referrerNames = {};
      _error = 'Could not load referrals.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProviderReferrals(String providerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('referrals')
          .select()
          .eq('from_provider_id', providerId)
          .order('created_at', ascending: false);

      _referrals = (response as List)
          .map((json) => ReferralModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitReferral(ReferralModel referral) async {
    try {
      await _supabase.from('referrals').insert(referral.toJson());
      _referrals.insert(0, referral);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? responseNotes,
  }) async {
    try {
      await _supabase.from('referrals').update({
        'status': ReferralModel.statusToString(status),
        'responded_at': DateTime.now().toIso8601String(),
        'response_notes': responseNotes,
      }).eq('id', referralId);

      final idx = _referrals.indexWhere((r) => r.id == referralId);
      if (idx != -1) {
        _referrals[idx] = ReferralModel(
          id: _referrals[idx].id,
          patientId: _referrals[idx].patientId,
          fromProviderId: _referrals[idx].fromProviderId,
          fromFacility: _referrals[idx].fromFacility,
          toFacility: _referrals[idx].toFacility,
          toDepartment: _referrals[idx].toDepartment,
          toSpecialist: _referrals[idx].toSpecialist,
          reason: _referrals[idx].reason,
          clinicalNotes: _referrals[idx].clinicalNotes,
          urgency: _referrals[idx].urgency,
          status: status,
          createdAt: _referrals[idx].createdAt,
          respondedAt: DateTime.now(),
          responseNotes: responseNotes,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
