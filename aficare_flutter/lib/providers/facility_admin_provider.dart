import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facility_model.dart';

/// Tells the logged-in facility admin which facility they run. Everything
/// else (departments, provider roster, stats) is handled by the existing,
/// already facility-scoped methods on [AdminFacilityProvider] — this
/// provider's only job is answering "which facility is mine".
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
}
