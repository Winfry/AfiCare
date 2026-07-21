import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/theme.dart';

class ResourceDashboardScreen extends StatefulWidget {
  const ResourceDashboardScreen({super.key});

  @override
  State<ResourceDashboardScreen> createState() => _ResourceDashboardScreenState();
}

class _ResourceDashboardScreenState extends State<ResourceDashboardScreen> {
  Map<String, dynamic>? _resources;
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
      // Try to load from facilities table; fallback to mock data
      Map<String, dynamic> resources;

      try {
        final facilityResp = await supabase
            .from('facilities')
            .select('name, bed_count, equipment, supplies')
            .limit(1)
            .single();
        resources = Map<String, dynamic>.from(facilityResp);
      } catch (_) {
        // No facilities table or no records — use mock data
        resources = {
          'name': 'AfiCare MediLink Facility',
          'beds': {'total': 50, 'occupied': 32, 'available': 18},
          'equipment': [
            {'name': 'Ventilators', 'total': 8, 'in_use': 5, 'available': 3},
            {'name': 'X-Ray Machines', 'total': 3, 'in_use': 1, 'available': 2},
            {'name': 'Ultrasound', 'total': 4, 'in_use': 3, 'available': 1},
            {'name': 'ECG Machines', 'total': 6, 'in_use': 2, 'available': 4},
            {'name': 'Defibrillators', 'total': 5, 'in_use': 1, 'available': 4},
          ],
          'supplies': [
            {'name': 'ART Drugs', 'stock': 'Adequate', 'color': Colors.green},
            {'name': 'Malaria RDTs', 'stock': 'Low (20 remaining)', 'color': Colors.orange},
            {'name': 'Antibiotics', 'stock': 'Adequate', 'color': Colors.green},
            {'name': 'IV Fluids', 'stock': 'Adequate', 'color': Colors.green},
            {'name': 'PPEs', 'stock': 'Critical (5 remaining)', 'color': Colors.red},
          ],
        };
      }

      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility name
                    Text(
                      _resources?['name'] ?? 'Facility Dashboard',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Bed occupancy
                    const Text('Bed Occupancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildBedOccupancy(),
                    const SizedBox(height: 24),

                    // Equipment
                    const Text('Equipment Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._buildEquipmentList(),
                    const SizedBox(height: 24),

                    // Supplies
                    const Text('Supplies Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._buildSuppliesList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBedOccupancy() {
    final beds = _resources?['beds'];
    if (beds == null) return const SizedBox.shrink();

    final total = (beds['total'] as num?)?.toInt() ?? 0;
    final occupied = (beds['occupied'] as num?)?.toInt() ?? 0;
    final available = (beds['available'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? occupied / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _bedStat('Total', '$total', Colors.blue),
              _bedStat('Occupied', '$occupied', Colors.orange),
              _bedStat('Available', '$available', Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                pct > 0.8 ? Colors.red : pct > 0.6 ? Colors.orange : Colors.green,
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(pct * 100).toStringAsFixed(0)}% occupancy',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _bedStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  List<Widget> _buildEquipmentList() {
    final equipment = _resources?['equipment'] as List? ?? [];
    if (equipment.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Text('No equipment data', style: TextStyle(color: Colors.grey))),
        ),
      ];
    }

    return equipment.map<Widget>((e) {
      final name = e['name'] ?? '';
      final total = (e['total'] as num?)?.toInt() ?? 0;
      final inUse = (e['in_use'] as num?)?.toInt() ?? 0;
      final pct = total > 0 ? inUse / total : 0.0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        pct > 0.8 ? Colors.red : pct > 0.6 ? Colors.orange : Colors.green,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$inUse/$total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildSuppliesList() {
    final supplies = _resources?['supplies'] as List? ?? [];
    if (supplies.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Text('No supplies data', style: TextStyle(color: Colors.grey))),
        ),
      ];
    }

    return supplies.map<Widget>((s) {
      final name = s['name'] ?? '';
      final stock = s['stock'] ?? '';
      final color = s['color'];

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color?.withOpacity(0.08) ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color?.withOpacity(0.2) ?? Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_2, size: 20, color: color ?? Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$stock', style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
