import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lab_model.dart';

class LabProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<LabOrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<LabOrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<LabOrderModel> get pending => _orders.where((o) => o.isPending).toList();
  List<LabOrderModel> get completed =>
      _orders.where((o) => o.isCompleted).toList();
  List<LabOrderModel> get critical =>
      _orders.where((o) => o.isCritical).toList();
  bool get hasCritical => _orders.any((o) => o.isCritical);

  Future<void> loadOrders(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Embedded select brings lab_results alongside each order.
      final response = await _supabase
          .from('lab_orders')
          .select('*, lab_results(*)')
          .eq('patient_id', patientId)
          .order('ordered_at', ascending: false);

      _orders = (response as List)
          .map((j) => LabOrderModel.fromJson(j as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Fallback: try without the embedded join (in case relationship
      // metadata is unavailable) so the list still renders.
      try {
        final response = await _supabase
            .from('lab_orders')
            .select()
            .eq('patient_id', patientId)
            .order('ordered_at', ascending: false);
        _orders = (response as List)
            .map((j) => LabOrderModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        notifyListeners();
      } catch (e2) {
        _error = e2.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createOrder(LabOrderModel order) async {
    try {
      final data = order.toJson();
      data.remove('id');
      await _supabase.from('lab_orders').insert(data);
      await loadOrders(order.patientId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
