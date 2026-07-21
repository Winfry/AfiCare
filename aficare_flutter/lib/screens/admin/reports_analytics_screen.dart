import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../utils/theme.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: AfiCareTheme.adminColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(provider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadAll(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period + Facility filters
                      _buildFilters(provider),
                      const SizedBox(height: 16),
                      // KPI cards
                      _buildKpiRow(provider, isWide),
                      const SizedBox(height: 24),
                      // Charts
                      isWide ? _buildWideCharts(provider) : _buildNarrowCharts(provider),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilters(AnalyticsProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return Row(
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: provider.periodFilter,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Period', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                    DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                    DropdownMenuItem(value: 'this_quarter', child: Text('This Quarter')),
                    DropdownMenuItem(value: 'this_year', child: Text('This Year')),
                  ],
                  onChanged: (v) {
                    provider.setPeriodFilter(v ?? 'this_month');
                    provider.loadAll();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: provider.facilityFilter,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Facility', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Facilities')),
                  ],
                  onChanged: (v) {
                    provider.setFacilityFilter(v ?? 'all');
                    provider.loadAll();
                  },
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: provider.periodFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Period', isDense: true),
              items: const [
                DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                DropdownMenuItem(value: 'this_quarter', child: Text('This Quarter')),
                DropdownMenuItem(value: 'this_year', child: Text('This Year')),
              ],
              onChanged: (v) {
                provider.setPeriodFilter(v ?? 'this_month');
                provider.loadAll();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: provider.facilityFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Facility', isDense: true),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Facilities')),
              ],
              onChanged: (v) {
                provider.setFacilityFilter(v ?? 'all');
                provider.loadAll();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiRow(AnalyticsProvider provider, bool isWide) {
    final cards = [
      _KpiCard(title: 'Total Users', value: '${provider.totalUsers}', icon: Icons.people, color: Colors.blue),
      _KpiCard(title: 'Active Providers', value: '${provider.activeProviders}', icon: Icons.medical_services, color: Colors.green),
      _KpiCard(title: 'Referrals (Month)', value: '${provider.referralsThisMonth}', icon: Icons.swap_horiz, color: Colors.orange),
      _KpiCard(title: 'Missed Appts', value: '${provider.missedAppointments}', icon: Icons.cancel, color: Colors.red),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        childAspectRatio: isWide ? 2.5 : 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (ctx, i) => cards[i],
    );
  }

  Widget _buildWideCharts(AnalyticsProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildUsersChart(provider)),
        const SizedBox(width: 16),
        Expanded(child: _buildReferralsChart(provider)),
      ],
    );
  }

  Widget _buildNarrowCharts(AnalyticsProvider provider) {
    return Column(
      children: [
        _buildUsersChart(provider),
        const SizedBox(height: 16),
        _buildReferralsChart(provider),
        const SizedBox(height: 16),
        _buildRoleChart(provider),
        const SizedBox(height: 16),
        _buildTriageChart(provider),
      ],
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersChart(AnalyticsProvider provider) {
    final data = provider.usersOverTime;
    if (data.isEmpty) return _buildChartContainer('Users Over Time', const Center(child: Text('No data')));

    final maxCount = data.fold<int>(0, (max, d) => (d['count'] as int) > max ? (d['count'] as int) : max);
    return _buildChartContainer('Users Over Time', CustomPaint(
      painter: _BarChartPainter(data, maxCount, 'date', 'count', Colors.blue),
      size: const Size(double.infinity, 200),
    ));
  }

  Widget _buildReferralsChart(AnalyticsProvider provider) {
    final data = provider.referralsByFacility;
    if (data.isEmpty) return _buildChartContainer('Referrals by Facility', const Center(child: Text('No data')));

    final maxCount = data.fold<int>(0, (max, d) => (d['count'] as int) > max ? (d['count'] as int) : max);
    return _buildChartContainer('Referrals by Facility', CustomPaint(
      painter: _BarChartPainter(data, maxCount, 'facility', 'count', Colors.orange),
      size: const Size(double.infinity, 200),
    ));
  }

  Widget _buildRoleChart(AnalyticsProvider provider) {
    final data = provider.roleDistribution;
    if (data.isEmpty) return _buildChartContainer('User Roles', const Center(child: Text('No data')));

    final total = data.fold<int>(0, (sum, d) => sum + (d['count'] as int));
    final colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange];
    return _buildChartContainer('User Roles', Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _PieChartPainter(data.map((d) => (d['count'] as int).toDouble()).toList(), colors),
                  size: const Size(120, 120),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(data.length, (i) {
                    final pct = total > 0 ? ((data[i]['count'] as int) / total * 100).toStringAsFixed(1) : '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(2),
                          )),
                          const SizedBox(width: 6),
                          Text('${data[i]['role']} (${data[i]['count']})', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _buildTriageChart(AnalyticsProvider provider) {
    final data = provider.triageBreakdown;
    if (data.isEmpty) return _buildChartContainer('Triage Breakdown', const Center(child: Text('No data')));

    final maxCount = data.fold<int>(0, (max, d) => (d['count'] as int) > max ? (d['count'] as int) : max);
    return _buildChartContainer('Triage Breakdown', CustomPaint(
      painter: _BarChartPainter(data, maxCount, 'level', 'count', Colors.purple),
      size: const Size(double.infinity, 200),
    ));
  }

  void _exportPdf(AnalyticsProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting PDF...')),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxValue;
  final String labelKey;
  final String valueKey;
  final Color barColor;

  _BarChartPainter(this.data, this.maxValue, this.labelKey, this.valueKey, this.barColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;
    final paint = Paint()..color = barColor;
    final labelPaint = Paint()..color = Colors.grey;
    final barWidth = (size.width - 20) / data.length;

    for (int i = 0; i < data.length; i++) {
      final value = data[i][valueKey] as int;
      final barHeight = (value / maxValue) * (size.height - 30);
      final x = i * barWidth + 10;
      final y = size.height - 20 - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x + 2, y, barWidth - 4, barHeight), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        paint,
      );

      final tb = TextPainter(
        text: TextSpan(text: '$value', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tb.paint(canvas, Offset(x + (barWidth - tb.width) / 2, y - tb.height - 2));

      final lb = TextPainter(
        text: TextSpan(text: '${data[i][labelKey]}'.length > 6 ? '${data[i][labelKey]}'.substring(0, 6) : '${data[i][labelKey]}', style: TextStyle(color: Colors.grey[600], fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      lb.paint(canvas, Offset(x + (barWidth - lb.width) / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _PieChartPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -1.5708;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 6.28319;
      canvas.drawArc(rect, startAngle, sweepAngle, true, Paint()..color = colors[i % colors.length]);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}