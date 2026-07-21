import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/theme.dart';
import 'adherence_log_screen.dart';

/// B12 — Medication Adherence (Today's check-in)
class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  State<MedicationTrackerScreen> createState() =>
      _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    final id = dep.activePatientId ?? auth.currentUser?.id;
    if (id != null) await ad.loadToday(id);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _mark(AdherenceLogModel dose, AdherenceStatus status) async {
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    await ad.markStatus(dose.id, status);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final firstName =
        (auth.currentUser?.fullName ?? 'there').split(' ').first;
    return Scaffold(
      appBar: AppBar(title: const Text('Medication Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AdherenceProvider>(
              builder: (context, ad, _) {
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('MEDICATION TRACKER',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                              color: AfiCareTheme.primaryGreen)),
                      Text(_todayLabel(),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _scoreCard(ad, firstName),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Upcoming Doses',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdherenceLogScreen()),
                            ),
                            child: const Text('View History'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (ad.todayDoses.isEmpty)
                        _emptyDoses()
                      else
                        ...ad.todayDoses.map(_doseCard),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _scoreCard(AdherenceProvider ad, String firstName) {
    final score = ad.todayScore;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 14,
                    backgroundColor: Colors.grey.shade200,
                    color: AfiCareTheme.primaryGreen,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score%',
                        style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: AfiCareTheme.primaryGreen)),
                    const Text('Daily Score',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Keep it up, $firstName!',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            ad.todayRemaining == 0
                ? 'All doses done for today.'
                : 'Only ${ad.todayRemaining} dose(s) left for a perfect day.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _doseCard(AdherenceLogModel dose) {
    final pending = dose.status == AdherenceStatus.pending;
    final taken = dose.status == AdherenceStatus.taken;
    final Color stripe = taken
        ? Colors.green
        : dose.status == AdherenceStatus.skipped
            ? Colors.orange
            : AfiCareTheme.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: pending
                ? AfiCareTheme.primaryGreen.withOpacity(0.3)
                : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: stripe.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication, color: stripe),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dose.medicationName ?? 'Medication',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(dose.dosage ?? '',
                          style:
                              TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(_time(dose.scheduledTime),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _mark(dose, AdherenceStatus.taken),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Take'),
                      style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _mark(dose, AdherenceStatus.skipped),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stripe.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    taken ? 'Taken' : 'Skipped',
                    style: TextStyle(
                        color: stripe, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyDoses() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No doses scheduled today',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  String _time(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return 'Today, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
