import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/theme.dart';
import '../../utils/snackbar_utils.dart';

class ResourceDashboardScreen extends StatefulWidget {
  const ResourceDashboardScreen({super.key});

  @override
  State<ResourceDashboardScreen> createState() => _ResourceDashboardScreenState();
}

class _ResourceDashboardScreenState extends State<ResourceDashboardScreen> {
  List<Map<String, dynamic>> _facilities = [];
  int _appointmentsToday = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    try {
      final facilityResp = await supabase
          .from('facilities')
          .select('id, name, type, county, sub_county, address, phone')
          .order('name', ascending: true);

      final facilities = <Map<String, dynamic>>[];
      for (final f in facilityResp as List) {
        final map = Map<String, dynamic>.from(f as Map);
        map['staff_count'] = await _countUsers(supabase, map['id'], isStaff: true);
        map['patient_count'] = await _countUsers(supabase, map['id'], isStaff: false);
        facilities.add(map);
      }

      final now = DateTime.now();
      final apptResp = await supabase
          .from('appointments')
          .select('id')
          .gte('scheduled_at', DateTime(now.year, now.month, now.day).toIso8601String())
          .lt('scheduled_at', DateTime(now.year, now.month, now.day + 1).toIso8601String());

      if (mounted) {
        setState(() {
          _facilities = facilities;
          _appointmentsToday = (apptResp as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('resource_dashboard_screen: loading resource data failed: $e');
      showErrorSnackBar(context, 'Could not load resource data');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _countUsers(SupabaseClient supabase, dynamic facilityId, {required bool isStaff}) async {
    try {
      final roles = isStaff ? ['doctor', 'nurse', 'radiologist'] : ['patient'];
      final resp = await supabase
          .from('users')
          .select('id')
          .eq('hospital_id', facilityId)
          .inFilter('role', roles)
          .limit(1000);
      return (resp as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Dashboard'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResources,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Facilities',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appointments scheduled today: $_appointmentsToday',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  if (_facilities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No facilities registered yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    for (final f in _facilities) _buildFacilityCard(f),
                ],
              ),
            ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    final type = facility['type'] ?? 'clinic';
    final county = facility['county'] ?? '';
    final phone = facility['phone'] ?? '';
    final staff = (facility['staff_count'] as int?) ?? 0;
    final patients = (facility['patient_count'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.local_hospital, color: AfiCareTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facility['name'] ?? 'Unnamed facility',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      if (county.isNotEmpty)
                        Text(
                          '${type[0].toUpperCase()}${type.substring(1)}'
                          '${county.isNotEmpty ? ' · $county County' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _facilityStat('Staff', '$staff', Icons.medical_services, AfiCareTheme.primaryBlue),
                const SizedBox(width: 12),
                _facilityStat('Patients', '$patients', Icons.people_outline, AfiCareTheme.canopy),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _facilityStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
