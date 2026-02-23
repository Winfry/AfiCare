import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../models/user_model.dart';
import '../../models/consultation_model.dart';
import '../../utils/theme.dart';

class HealthSummary extends StatefulWidget {
  const HealthSummary({super.key});

  @override
  State<HealthSummary> createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {
  // ----------------------------------------------------------------
  // Helpers: health score
  // ----------------------------------------------------------------

  int? _calcHealthScore(VitalSigns? v) {
    if (v == null) return null;
    int checks = 0, passed = 0;
    if (v.temperature != null) {
      checks++;
      if (v.temperature! >= 36.1 && v.temperature! <= 37.2) passed++;
    }
    if (v.systolicBP != null) {
      checks++;
      if (v.systolicBP! >= 90 && v.systolicBP! <= 120) passed++;
    }
    if (v.diastolicBP != null) {
      checks++;
      if (v.diastolicBP! >= 60 && v.diastolicBP! <= 80) passed++;
    }
    if (v.pulseRate != null) {
      checks++;
      if (v.pulseRate! >= 60 && v.pulseRate! <= 100) passed++;
    }
    if (v.oxygenSaturation != null) {
      checks++;
      if (v.oxygenSaturation! >= 95) passed++;
    }
    if (checks == 0) return null;
    return ((passed / checks) * 100).round();
  }

  ({String label, Color color}) _scoreInfo(int? score) {
    if (score == null) return (label: 'No data', color: Colors.grey);
    if (score >= 80) return (label: 'Excellent', color: Colors.green);
    if (score >= 60) return (label: 'Good', color: AfiCareTheme.primaryGreen);
    if (score >= 40) return (label: 'Fair', color: Colors.orange);
    return (label: 'Needs Attention', color: Colors.red);
  }

  // ----------------------------------------------------------------
  // Helpers: vital status labels
  // ----------------------------------------------------------------

  ({String label, Color color}) _tempStatus(double? t) {
    if (t == null) return (label: 'No data', color: Colors.grey);
    if (t < 36.1) return (label: 'Low', color: Colors.blue);
    if (t <= 37.2) return (label: 'Normal', color: Colors.green);
    if (t <= 38.0) return (label: 'Low fever', color: Colors.orange);
    return (label: 'Fever', color: Colors.red);
  }

  ({String label, Color color}) _bpStatus(int? sys, int? dia) {
    if (sys == null || dia == null) return (label: 'No data', color: Colors.grey);
    if (sys < 90 || dia < 60) return (label: 'Low', color: Colors.blue);
    if (sys <= 120 && dia <= 80) return (label: 'Normal', color: Colors.green);
    if (sys <= 130) return (label: 'Elevated', color: Colors.orange);
    return (label: 'High', color: Colors.red);
  }

  ({String label, Color color}) _hrStatus(int? hr) {
    if (hr == null) return (label: 'No data', color: Colors.grey);
    if (hr < 60) return (label: 'Low', color: Colors.blue);
    if (hr <= 100) return (label: 'Normal', color: Colors.green);
    return (label: 'High', color: Colors.red);
  }

  ({String label, Color color}) _spo2Status(double? s) {
    if (s == null) return (label: 'No data', color: Colors.grey);
    if (s >= 95) return (label: 'Normal', color: Colors.green);
    if (s >= 90) return (label: 'Low', color: Colors.orange);
    return (label: 'Critical', color: Colors.red);
  }

  double? _calcBMI(VitalSigns? v) {
    if (v?.weight == null || v?.height == null || v!.height! <= 0) return null;
    return v.weight! / (v.height! * v.height!);
  }

  ({String label, Color color}) _bmiStatus(double? bmi) {
    if (bmi == null) return (label: 'No data', color: Colors.grey);
    if (bmi < 18.5) return (label: 'Underweight', color: Colors.blue);
    if (bmi < 25) return (label: 'Normal', color: Colors.green);
    if (bmi < 30) return (label: 'Overweight', color: Colors.orange);
    return (label: 'Obese', color: Colors.red);
  }

  // ----------------------------------------------------------------
  // Helpers: data slicing
  // ----------------------------------------------------------------

  /// Last 7 consultations in chronological order (oldest → newest)
  List<ConsultationModel> _bpTrend(List<ConsultationModel> all) {
    final sorted = List<ConsultationModel>.from(all)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
  }

  /// Consultations where a follow-up is required and not yet past
  List<ConsultationModel> _upcomingFollowUps(List<ConsultationModel> all) {
    final now = DateTime.now();
    return all
        .where((c) =>
            c.followUpRequired &&
            c.followUpDate != null &&
            c.followUpDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PatientProvider>(
      builder: (context, authProvider, patientProvider, child) {
        final user = authProvider.currentUser;
        final consultations = patientProvider.consultations;
        final latestVitals =
            consultations.isNotEmpty ? consultations.first.vitalSigns : null;
        final score = _calcHealthScore(latestVitals);
        final trend = _bpTrend(consultations);
        final upcoming = _upcomingFollowUps(consultations);
        final latestRecs = consultations.isNotEmpty
            ? consultations.first.recommendations
            : <String>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Health Summary'),
            backgroundColor: AfiCareTheme.primaryGreen,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share health summary',
                onPressed: () => _shareHealthSummary(user, latestVitals, score),
              ),
            ],
          ),
          body: patientProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(user, consultations.length),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHealthScoreCard(score),
                            const SizedBox(height: 16),
                            _buildVitalSignsCard(latestVitals),
                            const SizedBox(height: 16),
                            _buildVitalsTrendChart(trend),
                            const SizedBox(height: 16),
                            _buildRecommendationsCard(latestRecs, consultations),
                            const SizedBox(height: 16),
                            _buildAllergiesCard(),
                            const SizedBox(height: 16),
                            _buildRecentVisitsCard(consultations),
                            const SizedBox(height: 16),
                            _buildUpcomingAppointmentsCard(upcoming),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // Header
  // ----------------------------------------------------------------

  Widget _buildHeader(UserModel? user, int totalVisits) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryGreen, AfiCareTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AfiCareTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? 'Patient',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MediLink ID: ${user?.medilinkId ?? 'ML-XXX-XXXX'}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalVisits > 0
                ? '$totalVisits consultation${totalVisits == 1 ? '' : 's'} recorded'
                : 'No consultations yet',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Health Score
  // ----------------------------------------------------------------

  Widget _buildHealthScoreCard(int? score) {
    final info = _scoreInfo(score);
    final display = score?.toString() ?? '--';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Health Score',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: info.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    info.label,
                    style: TextStyle(
                      color: info.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Semantics(
                label: 'Health score $display out of 100, ${info.label}',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: score != null ? score / 100 : 0,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(info.color),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          display,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: info.color,
                          ),
                        ),
                        Text(
                          score != null ? 'out of 100' : 'Complete a visit',
                          style: const TextStyle(color: Color(0xFF616161)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              score != null
                  ? 'Score based on your latest vital signs. Visit your provider regularly to keep it updated.'
                  : 'Visit a healthcare provider to have your vitals recorded. Your health score will appear here.',
              style: const TextStyle(color: Color(0xFF616161), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Vital Signs
  // ----------------------------------------------------------------

  Widget _buildVitalSignsCard(VitalSigns? v) {
    final bmi = _calcBMI(v);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Latest Vital Signs',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  v != null ? 'From last visit' : 'No data',
                  style: const TextStyle(
                      color: Color(0xFF616161), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalItem(
                    Icons.thermostat,
                    'Temperature',
                    v?.temperature != null
                        ? '${v!.temperature!.toStringAsFixed(1)}°C'
                        : '--',
                    Colors.orange,
                    _tempStatus(v?.temperature),
                  ),
                ),
                Expanded(
                  child: _buildVitalItem(
                    Icons.favorite,
                    'Blood Pressure',
                    v != null ? v.bloodPressure : '--/--',
                    Colors.red,
                    _bpStatus(v?.systolicBP, v?.diastolicBP),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalItem(
                    Icons.monitor_heart,
                    'Heart Rate',
                    v?.pulseRate != null ? '${v!.pulseRate} bpm' : '-- bpm',
                    Colors.pink,
                    _hrStatus(v?.pulseRate),
                  ),
                ),
                Expanded(
                  child: _buildVitalItem(
                    Icons.air,
                    'SpO₂',
                    v?.oxygenSaturation != null
                        ? '${v!.oxygenSaturation!.toStringAsFixed(0)}%'
                        : '--%',
                    Colors.blue,
                    _spo2Status(v?.oxygenSaturation),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalItem(
                    Icons.scale,
                    'Weight',
                    v?.weight != null
                        ? '${v!.weight!.toStringAsFixed(1)} kg'
                        : '-- kg',
                    Colors.purple,
                    (label: 'Recorded', color: Colors.purple),
                  ),
                ),
                Expanded(
                  child: _buildVitalItem(
                    Icons.height,
                    'BMI',
                    bmi != null ? bmi.toStringAsFixed(1) : '--',
                    Colors.teal,
                    _bmiStatus(bmi),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalItem(
    IconData icon,
    String label,
    String value,
    Color color,
    ({String label, Color color}) status,
  ) {
    return Semantics(
      label: '$label: $value, status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                  fontSize: 10,
                  color: status.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // BP Trend Chart
  // ----------------------------------------------------------------

  Widget _buildVitalsTrendChart(List<ConsultationModel> trend) {
    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];

    for (int i = 0; i < trend.length; i++) {
      final v = trend[i].vitalSigns;
      if (v.systolicBP != null) {
        systolicSpots.add(FlSpot(i.toDouble(), v.systolicBP!.toDouble()));
      }
      if (v.diastolicBP != null) {
        diastolicSpots.add(FlSpot(i.toDouble(), v.diastolicBP!.toDouble()));
      }
    }

    final hasData = systolicSpots.length >= 2 || diastolicSpots.length >= 2;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blood Pressure Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              hasData
                  ? 'Last ${trend.length} consultation${trend.length == 1 ? '' : 's'}'
                  : 'Need at least 2 visits with BP recorded to show trend',
              style:
                  const TextStyle(color: Color(0xFF616161), fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.show_chart,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Chart will appear after 2+ visits',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                        show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= trend.length) {
                              return const Text('');
                            }
                            final d = trend[i].timestamp;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${d.day}/${d.month}',
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      if (systolicSpots.length >= 2)
                        LineChartBarData(
                          spots: systolicSpots,
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                      if (diastolicSpots.length >= 2)
                        LineChartBarData(
                          spots: diastolicSpots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                    ],
                    minY: 40,
                    maxY: 180,
                  ),
                ),
              ),
            if (hasData) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Systolic', Colors.red),
                  const SizedBox(width: 24),
                  _buildLegendItem('Diastolic', Colors.blue),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ----------------------------------------------------------------
  // Recommendations (from latest consultation)
  // ----------------------------------------------------------------

  Widget _buildRecommendationsCard(
      List<String> recs, List<ConsultationModel> consultations) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Clinical Recommendations',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (consultations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'From visit on ${_formatDate(consultations.first.timestamp)}',
                style: const TextStyle(
                    color: Color(0xFF616161), fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            if (recs.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.medical_information_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No recommendations yet',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clinical recommendations will appear here after a consultation',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...recs.map(
                (rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18,
                          color: AfiCareTheme.primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(rec,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Allergies
  // ----------------------------------------------------------------

  Widget _buildAllergiesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber,
                    color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Known Allergies',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No allergies recorded',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your allergies through your healthcare provider',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Recent Visits
  // ----------------------------------------------------------------

  Widget _buildRecentVisitsCard(List<ConsultationModel> consultations) {
    final recent = consultations.take(5).toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Visits',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (consultations.length > 5)
                  Text(
                    '${consultations.length} total',
                    style: const TextStyle(
                        color: Color(0xFF616161), fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (recent.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.local_hospital_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No visits recorded yet',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your visit history will appear here after consultations',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...recent.map(
                (c) => _buildVisitItem(
                  c.chiefComplaint,
                  _formatDate(c.timestamp),
                  c.triageLevel,
                  _triageColor(c.triageLevel),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitItem(
      String title, String date, String type, Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AfiCareTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_hospital,
                color: AfiCareTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  date,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  color: typeColor,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Upcoming Appointments
  // ----------------------------------------------------------------

  Widget _buildUpcomingAppointmentsCard(List<ConsultationModel> upcoming) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Follow-ups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (upcoming.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No upcoming follow-ups',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled follow-ups from consultations will appear here',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...upcoming.map(
                (c) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event,
                            color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow-up for: ${c.chiefComplaint}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatDate(c.followUpDate!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DUE',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Utilities
  // ----------------------------------------------------------------

  String _formatDate(DateTime dt) =>
      '${dt.day} ${_month(dt.month)} ${dt.year}';

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Color _triageColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      case 'semi-urgent':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  void _shareHealthSummary(
      UserModel? user, VitalSigns? v, int? score) {
    final sb = StringBuffer();
    sb.writeln('AfiCare MediLink — Health Summary');
    sb.writeln('Patient: ${user?.fullName ?? 'Unknown'}');
    sb.writeln('MediLink ID: ${user?.medilinkId ?? 'N/A'}');
    sb.writeln('Date: ${_formatDate(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Health Score: ${score?.toString() ?? 'No data'}');
    if (v != null) {
      sb.writeln('');
      sb.writeln('Latest Vital Signs:');
      if (v.temperature != null) {
        sb.writeln('  Temperature: ${v.temperature!.toStringAsFixed(1)}°C');
      }
      sb.writeln('  Blood Pressure: ${v.bloodPressure} mmHg');
      if (v.pulseRate != null) sb.writeln('  Heart Rate: ${v.pulseRate} bpm');
      if (v.oxygenSaturation != null) {
        sb.writeln('  SpO₂: ${v.oxygenSaturation}%');
      }
    }
    SharePlus.instance.share(ShareParams(text: sb.toString()));
  }
}
