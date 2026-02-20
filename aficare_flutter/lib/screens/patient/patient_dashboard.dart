import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math';

import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../models/user_model.dart';
import '../../models/consultation_model.dart';
import '../../utils/theme.dart';
import '../common/notifications_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _generatedAccessCode;
  DateTime? _accessCodeExpiry;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadPatientData();
  }

  void _loadPatientData() {
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    patientProvider.loadPatientData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PatientProvider>(
      builder: (context, authProvider, patientProvider, child) {
        final user = authProvider.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(user),
          body: Column(
            children: [
              _buildMedilinkHeader(user),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHealthSummaryTab(patientProvider),
                    _buildVisitHistoryTab(patientProvider),
                    if (user.gender?.toLowerCase() == 'female') ...[
                      _buildMaternalHealthTab(patientProvider),
                      _buildWomensHealthTab(patientProvider),
                    ],
                    _buildSharingTab(user),
                    _buildSettingsTab(user),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel user) {
    return AppBar(
      title: const Text(
        'AfiCare MediLink',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: AfiCareTheme.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, semanticLabel: 'Notifications'),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(userRole: 'patient'),
                ),
              );
            },
          ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) context.go('/login');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMedilinkHeader(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryGreen, AfiCareTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  user.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AfiCareTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'MediLink ID: ${user.medilinkId ?? 'ML-XXX-XXXX'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isWoman = user?.gender?.toLowerCase() == 'female';

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AfiCareTheme.primaryGreen,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AfiCareTheme.primaryGreen,
        tabs: [
          const Tab(icon: Icon(Icons.dashboard), text: 'Health'),
          const Tab(icon: Icon(Icons.local_hospital), text: 'Visits'),
          if (isWoman) ...[
            const Tab(icon: Icon(Icons.pregnant_woman), text: 'Maternal'),
            const Tab(icon: Icon(Icons.female), text: 'Women\'s Health'),
          ],
          const Tab(icon: Icon(Icons.share), text: 'Share'),
          const Tab(icon: Icon(Icons.settings), text: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHealthSummaryTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthMetrics(),
          const SizedBox(height: 20),
          _buildHealthAlerts(),
          const SizedBox(height: 20),
          _buildVitalSignsTrends(),
          const SizedBox(height: 20),
          _buildMedicationManagement(),
          const SizedBox(height: 20),
          _buildHealthGoals(),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Health Score',
                    '--',
                    'Complete profile to see',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Total Visits',
                    '0',
                    'No visits yet',
                    Icons.local_hospital,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Active Meds',
                    '0',
                    'None prescribed',
                    Icons.medication,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Risk Level',
                    '--',
                    'Pending assessment',
                    Icons.security,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Semantics(
      label: '$title, Value: $value, $subtitle',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
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
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthAlerts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Alerts & Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAlertItem(
              'Welcome! Complete your profile to get personalized health alerts.',
              Icons.info,
              Colors.blue,
            ),
            _buildAlertItem(
              'Visit a healthcare provider to record your first consultation.',
              Icons.local_hospital,
              Colors.green,
            ),
            _buildAlertItem(
              'Update your allergies and medications through your provider.',
              Icons.warning,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(String text, IconData icon, Color color) {
    return Semantics(
      label: 'Alert: $text',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: color == Colors.red ? Colors.red : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vital Signs Trends (Last 6 Months)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateSampleData(),
                      isCurved: true,
                      color: AfiCareTheme.primaryGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vital signs will be recorded during your consultations',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSampleData() {
    final random = Random();
    return List.generate(
      6,
      (index) => FlSpot(
        index.toDouble(),
        120 + random.nextDouble() * 20,
      ),
    );
  }

  Widget _buildMedicationManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Medication Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.medication_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No active medications',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prescribed medications will be tracked here',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
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

  Widget _buildMedicationItem(
    String name,
    String dosage,
    String frequency,
    String adherence,
    String nextRefill,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name $dosage',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  adherence,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Frequency: $frequency',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            'Next Refill: $nextRefill',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGoals() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Goals & Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildGoalItem('Weight Management', 0.8, '72kg target'),
            _buildGoalItem('Exercise Routine', 0.9, '5x/week target'),
            _buildGoalItem('Blood Sugar Control', 0.85, 'HbA1c <7%'),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String title, double progress, String target) {
    return Semantics(
      label: 'Goal: $title, Progress: ${(progress * 100).toInt()} percent, Target: $target',
      value: '${(progress * 100).toInt()}%',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: AfiCareTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AfiCareTheme.primaryGreen),
            ),
            const SizedBox(height: 4),
            Text(
              target,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitHistoryTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisitSummary(),
          const SizedBox(height: 20),
          _buildVisitHistory(),
        ],
      ),
    );
  }

  Widget _buildVisitSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visit Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Visits',
                    '0',
                    'No visits yet',
                    Icons.local_hospital,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Emergency Visits',
                    '0',
                    'None recorded',
                    Icons.emergency,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Visits',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.local_hospital_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No visits recorded yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your visit history will appear here after your first consultation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(Map<String, String> visit) {
    Color triageColor = visit['triage'] == 'URGENT' ? Colors.orange : Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visit['date']} - ${visit['hospital']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: triageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    visit['triage']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: triageColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Doctor: ${visit['doctor']}'),
            Text('Diagnosis: ${visit['diagnosis']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMaternalHealthTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maternal Health Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildPregnancyStatusCard(),
          const SizedBox(height: 20),
          _buildPreconceptionCare(),
        ],
      ),
    );
  }

  Widget _buildPregnancyStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Pregnancy Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'not_pregnant', child: Text('Not Pregnant')),
                DropdownMenuItem(value: 'trying', child: Text('Trying to Conceive')),
                DropdownMenuItem(value: 'pregnant', child: Text('Pregnant')),
                DropdownMenuItem(value: 'postpartum', child: Text('Postpartum')),
                DropdownMenuItem(value: 'breastfeeding', child: Text('Breastfeeding')),
              ],
              onChanged: (value) {
                // Handle status change
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreconceptionCare() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preconception Care Checklist',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildChecklistItem('Taking folic acid 400mcg daily', false),
            _buildChecklistItem('Maintaining healthy weight (BMI 18.5-24.9)', true),
            _buildChecklistItem('Regular exercise routine', true),
            _buildChecklistItem('Balanced nutrition', false),
            _buildChecklistItem('No smoking or alcohol', true),
            _buildChecklistItem('Up-to-date vaccinations', false),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AfiCareTheme.primaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Progress: 3/6 items completed (60%)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: (value) {
              // Handle checkbox change
            },
            activeColor: AfiCareTheme.primaryGreen,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWomensHealthTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Women\'s Health Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildScreeningOverview(),
          const SizedBox(height: 20),
          _buildReproductiveHealthConditions(),
          const SizedBox(height: 20),
          _buildMenstrualHealthTracking(),
        ],
      ),
    );
  }

  Widget _buildScreeningOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Screening Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Last Pap Smear',
                    '8 months ago',
                    'Due in 4 months',
                    Icons.medical_services,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Last Mammogram',
                    '14 months ago',
                    'Overdue',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReproductiveHealthConditions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reproductive Health Conditions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('PCOS Management'),
              leading: const Icon(Icons.medical_information),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Symptoms:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('Irregular periods')),
                          Chip(label: Text('Weight gain')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Endometriosis Management'),
              leading: const Icon(Icons.medical_information),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pain Assessment:'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Menstrual pain: '),
                          Expanded(
                            child: Slider(
                              value: 6,
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '6',
                              onChanged: (value) {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenstrualHealthTracking() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menstrual Health Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Cycle Length (days)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: '28',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Period Duration (days)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: '5',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Next expected period: February 15, 2024'),
          ],
        ),
      ),
    );
  }

  Widget _buildSharingTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Medical Records',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildAccessCodeGeneration(user),
          const SizedBox(height: 20),
          _buildQRCodeSharing(user),
          const SizedBox(height: 20),
          _buildActiveSessions(),
        ],
      ),
    );
  }

  Widget _buildAccessCodeGeneration(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Access Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Access Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full Medical History')),
                DropdownMenuItem(value: 'current', child: Text('Current Visit Only')),
                DropdownMenuItem(value: 'emergency', child: Text('Emergency Info Only')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Duration',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '1h', child: Text('1 hour')),
                DropdownMenuItem(value: '4h', child: Text('4 hours')),
                DropdownMenuItem(value: '24h', child: Text('24 hours')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateAccessCode,
                icon: const Icon(Icons.key),
                label: const Text('Generate Access Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AfiCareTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_generatedAccessCode != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Access Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatedAccessCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valid until: ${_accessCodeExpiry?.toString().substring(0, 16)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _generateAccessCode() {
    setState(() {
      _generatedAccessCode = (100000 + Random().nextInt(900000)).toString();
      _accessCodeExpiry = DateTime.now().add(const Duration(hours: 1));
    });
  }

  Widget _buildQRCodeSharing(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QR Code Sharing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: QrImageView(
                      data: jsonEncode({
                        'medilink_id': user.medilinkId,
                        'access_code': _generatedAccessCode ?? '123456',
                        'expires_at': DateTime.now()
                            .add(const Duration(hours: 1))
                            .toIso8601String(),
                      }),
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'My AfiCare MediLink ID: ${user.medilinkId}\n'
                        'Access Code: ${_generatedAccessCode ?? '123456'}\n'
                        'Valid for 1 hour',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Access Code'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Sharing Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active sessions',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildPersonalInformation(user),
          const SizedBox(height: 20),
          _buildPrivacySettings(),
          const SizedBox(height: 20),
          _buildNotificationSettings(),
        ],
      ),
    );
  }

  Widget _buildPersonalInformation(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user.fullName,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: user.email,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy & Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow emergency access when unconscious'),
              value: true,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
            SwitchListTile(
              title: const Text('Allow anonymized data for medical research'),
              value: false,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
            SwitchListTile(
              title: const Text('Enable AI health recommendations'),
              value: true,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Medication reminders'),
              value: true,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
            SwitchListTile(
              title: const Text('Appointment reminders'),
              value: true,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
            SwitchListTile(
              title: const Text('Health alerts'),
              value: true,
              onChanged: (value) {},
              activeColor: AfiCareTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}