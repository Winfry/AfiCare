import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id;
    if (providerId == null) return;

    final supabase = Supabase.instance.client;

    try {
      // Get date filter
      final now = DateTime.now();
      DateTime since;
      switch (_selectedPeriod) {
        case 'day':
          since = now.subtract(const Duration(days: 1));
          break;
        case 'month':
          since = DateTime(now.year, now.month - 1, now.day);
          break;
        default:
          since = now.subtract(const Duration(days: 7));
      }
      final sinceStr = since.toIso8601String();

      // Total consultations
      final totalConsults = await supabase
          .from('consultations')
          .select('id')
          .eq('provider_id', providerId)
          .gte('timestamp', sinceStr);

      // Triage breakdown
      final emergencyCount = await supabase
          .from('consultations')
          .select('id')
          .eq('provider_id', providerId)
          .eq('triage_level', 'emergency')
          .gte('timestamp', sinceStr);

      final urgentCount = await supabase
          .from('consultations')
          .select('id')
          .eq('provider_id', providerId)
          .eq('triage_level', 'urgent')
          .gte('timestamp', sinceStr);

      // Total patients
      final totalPatients = await supabase
          .from('users')
          .select('id')
          .eq('role', 'patient');

      // Total referrals
      final totalReferrals = await supabase
          .from('referrals')
          .select('id')
          .eq('from_provider_id', providerId)
          .gte('created_at', sinceStr);

      // Total prescriptions
      final totalRx = await supabase
          .from('prescriptions')
          .select('id')
          .eq('provider_id', providerId)
          .gte('issued_at', sinceStr);

      setState(() {
        _stats = {
          'consults': totalConsults.length,
          'emergency': emergencyCount.length,
          'urgent': urgentCount.length,
          'patients': totalPatients.length,
          'referrals': totalReferrals.length,
          'prescriptions': totalRx.length,
        };
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
        title: const Text('Reports'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Row(
                      children: [
                        _periodChip('Day', 'day'),
                        const SizedBox(width: 8),
                        _periodChip('Week', 'week'),
                        const SizedBox(width: 8),
                        _periodChip('Month', 'month'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(child: _statTile('Consultations', '${_stats?['consults'] ?? 0}', Icons.chat, Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _statTile('Patients', '${_stats?['patients'] ?? 0}', Icons.people, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _statTile('Prescriptions', '${_stats?['prescriptions'] ?? 0}', Icons.medication, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _statTile('Referrals', '${_stats?['referrals'] ?? 0}', Icons.transfer_within_a_station, Colors.purple)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Triage breakdown
                    Text('Triage Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    const SizedBox(height: 12),
                    _triageBar('Emergency', _stats?['emergency'] ?? 0, Colors.red),
                    const SizedBox(height: 8),
                    _triageBar('Urgent', _stats?['urgent'] ?? 0, Colors.orange),
                    const SizedBox(height: 8),
                    _triageBar('Non-Urgent', _stats?['consults'] - _stats?['emergency'] - _stats?['urgent'] ?? 0, Colors.green),

                    const SizedBox(height: 24),
                    Text('Period: ${_selectedPeriod == 'day' ? 'Last 24 hours' : _selectedPeriod == 'week' ? 'Last 7 days' : 'Last 30 days'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = _selectedPeriod == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: selected,
        selectedColor: AfiCareTheme.primaryBlue,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() => _selectedPeriod = value);
          _loadStats();
        },
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _triageBar(String label, int count, Color color) {
    final total = (_stats?['consults'] as int?) ?? 1;
    final pct = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const Spacer(),
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
