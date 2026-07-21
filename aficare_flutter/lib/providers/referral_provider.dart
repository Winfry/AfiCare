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

  Future<void> loadPatientReferrals(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('referrals')
          .select()
          .eq('patient_id', patientId)
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
