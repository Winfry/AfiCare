import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_model.dart';

/// Tells the logged-in facility admin which facility they run, and lets
/// them edit its profile. Everything else facility-scoped (departments,
/// provider roster, stats) is handled by the existing methods on
/// [AdminFacilityProvider] — this provider only owns "which facility is
/// mine" and editing that facility's own profile fields.
class FacilityAdminProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  FacilityModel? _myFacility;
  bool _isLoading = false;
  String? _error;

  FacilityModel? get myFacility => _myFacility;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyFacility() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final link = await _supabase
          .from('facility_admins')
          .select('facility_id')
          .eq('user_id', uid)
          .limit(1)
          .maybeSingle();

      if (link == null) {
        _myFacility = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final facilityRow = await _supabase
          .from('facilities')
          .select('*')
          .eq('id', link['facility_id'] as String)
          .single();

      _myFacility = FacilityModel.fromJson(facilityRow);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves edits to the facility this admin runs, via the checked RPC
  /// (019_facility_admin_update_facility.sql) rather than a direct
  /// `.update()` -- RLS on `facilities` only allows the platform admin
  /// to write directly; this is the actual permission boundary.
  /// `status` is deliberately not a parameter here: verification stays
  /// platform-admin only.
  Future<bool> updateMyFacility({
    required String name,
    required String type,
    String? county,
    String? subCounty,
    String? address,
    String? phone,
    String? email,
    String? licenseNo,
  }) async {
    final facility = _myFacility;
    if (facility == null) return false;

    try {
      await _supabase.rpc('facility_admin_update_facility', params: {
        'target_facility_id': facility.id,
        'facility_name': name,
        'facility_type': type,
        'facility_county': county,
        'facility_sub_county': subCounty,
        'facility_address': address,
        'facility_phone': phone,
        'facility_email': email,
        'facility_license_no': licenseNo,
      });

      _myFacility = facility.copyWith(
        name: name,
        type: type,
        county: county,
        subCounty: subCounty,
        address: address,
        phone: phone,
        email: email,
        licenseNo: licenseNo,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
