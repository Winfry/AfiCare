import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/theme.dart';

/// B13 — Medication Adherence Log (History)
class AdherenceLogScreen extends StatefulWidget {
  const AdherenceLogScreen({super.key});

  @override
  State<AdherenceLogScreen> createState() => _AdherenceLogScreenState();
}

class _AdherenceLogScreenState extends State<AdherenceLogScreen> {
  bool _isLoading = true;
  int _range = 7; // 7 or 30

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id != null) await ad.loadHistory(id, days: _range);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherence Log'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _rangeToggle(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AdherenceProvider>(
              builder: (context, ad, _) {
                final bars = ad.weeklyBars(days: _range == 7 ? 7 : 30);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _streakCard(ad),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard('ADHERENCE',
                                '${ad.historyRate}%', 'this period')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _statCard('DOSES TAKEN',
                                '${ad.historyTaken}/${ad.historyTotal}', 'total')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Overview',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _chart(bars),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('Missed Doses',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (ad.missedDoses.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('NEEDS ATTENTION',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (ad.missedDoses.isEmpty)
                      _noMissed()
                    else
                      ...ad.missedDoses.map(_missedCard),
                  ],
                );
              },
            ),
    );
  }

  Widget _rangeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [7, 30].map((r) {
          final selected = _range == r;
          return GestureDetector(
            onTap: () {
              setState(() => _range = r);
              _load();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$r-day',
                  style: TextStyle(
                      color: selected
                          ? AfiCareTheme.primaryGreen
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _streakCard(AdherenceProvider ad) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIVE STREAK',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('${ad.streak}-day streak 🔥',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Keep it up! Consistency is key.',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AfiCareTheme.primaryGreen)),
                TextSpan(
                    text: '  $sub',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart(List<double> bars) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: BarChart(
        BarChartData(
          maxY: 1,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  final label = (bars.length <= 7 && i < dayLabels.length)
                      ? dayLabels[i]
                      : '${i + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label,
                        style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(bars.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i],
                  color: AfiCareTheme.primaryGreen,
                  width: bars.length <= 7 ? 18 : 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _missedCard(AdherenceLogModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.red.shade400, width: 4)),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.event_busy, color: Colors.red),
        ),
        title: Text(d.medicationName ?? 'Medication',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_dateTime(d.scheduledTime)),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }

  Widget _noMissed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text('No missed doses!',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime dt) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day} • $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}
