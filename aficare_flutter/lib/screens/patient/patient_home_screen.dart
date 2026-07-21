import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import 'health_summary.dart';
import 'share_records.dart';
import 'expenses_screen.dart';
import 'lab_results_screen.dart';
import 'medication_tracker_screen.dart';
import 'prescriptions_list_screen.dart';

/// Dashboard (Home) tab of the patient bottom-nav shell.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final firstName = (user?.fullName ?? 'there').split(' ').first;

    final actions = <_Action>[
      _Action('Prescriptions', Icons.medication,
          () => _push(context, const PrescriptionsListScreen())),
      _Action('Medications', Icons.check_circle_outline,
          () => _push(context, const MedicationTrackerScreen())),
      _Action('Lab Results', Icons.science_outlined,
          () => _push(context, const LabResultsScreen())),
      _Action('Health Summary', Icons.favorite_border,
          () => _push(context, const HealthSummary())),
      _Action('Share Records', Icons.qr_code,
          () => _push(context, const ShareRecords())),
      _Action('Expenses', Icons.receipt_long,
          () => _push(context, const ExpensesScreen())),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AfiCare'),
        leading: const Icon(Icons.menu),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hello, $firstName 👋',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Welcome back to your health dashboard',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),
          _medilinkCard(user?.medilinkId ?? '—', user?.fullName ?? ''),
          const SizedBox(height: 24),
          const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: actions.map((a) => _actionCard(a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _medilinkCard(String medilinkId, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AfiCareTheme.primaryGreen,
            AfiCareTheme.primaryGreenLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.white),
              SizedBox(width: 8),
              Text('MediLink ID',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(medilinkId,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _actionCard(_Action a) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: a.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AfiCareTheme.primaryGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AfiCareTheme.primaryGreen.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, color: AfiCareTheme.primaryGreen, size: 30),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(a.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Action {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Action(this.label, this.icon, this.onTap);
}
