import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/app_strings.dart';
import 'adherence_log_screen.dart';

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
    if (id != null) {
      await ad.ensureTodayDoses(id);
      await ad.loadToday(id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _mark(AdherenceLogModel dose, AdherenceStatus status) async {
    final ad = Provider.of<AdherenceProvider>(context, listen: false);
    await ad.markStatus(dose.id, status);
  }

  void _openAddMedication() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final patientId = dep.activePatientId ?? auth.currentUser?.id ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMedicationScreen(patientId: patientId),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final firstName =
        (auth.currentUser?.fullName ?? 'there').split(' ').first;

    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _MedicationHero(firstName: firstName),
          Expanded(
            child: Consumer<AdherenceProvider>(
              builder: (context, ad, _) {
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    children: [
                      if (ad.todayDoses.isEmpty)
                        _buildEmptyState()
                      else ...[
                        _ScoreCard(
                            score: ad.todayScore,
                            remaining: ad.todayRemaining,
                            firstName: firstName),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Today\'s doses',
                                style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700)),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdherenceLogScreen()),
                              ),
                              child: const Text('View history',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D3557))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...ad.todayDoses.map((d) => _DoseCard(
                              dose: d,
                              onTake: () => _mark(
                                  d, AdherenceStatus.taken),
                              onSkip: () => _mark(
                                  d, AdherenceStatus.skipped),
                            )),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          _AddMedicationButton(onPressed: _openAddMedication),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.medication_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text('No medications yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(
                'Tap "Add Medication" below to track\nyour daily pills.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

// ── Hero header ─────────────────────────────────────────────

class _MedicationHero extends StatelessWidget {
  const _MedicationHero({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D3557), Color(0xFF24456B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medications',
              style: GoogleFonts.fraunces(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Hello, $firstName 👋',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Track your daily pills',
              style: TextStyle(
                  fontSize: 13.5, color: Color(0xFFC7D2DC))),
        ],
      ),
    );
  }
}

// ── Score card ──────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.remaining,
    required this.firstName,
  });
  final int score;
  final int remaining;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFEEF2F7),
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                Text('$score%',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32))),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    remaining == 0
                        ? 'All done for today! 🎉'
                        : '$remaining dose${remaining == 1 ? '' : 's'} remaining',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  remaining == 0
                      ? 'Perfect adherence today, $firstName.'
                      : 'Keep going — you\'re doing great.',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF3D5470)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dose card ───────────────────────────────────────────────

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.onTake,
    required this.onSkip,
  });
  final AdherenceLogModel dose;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final pending = dose.status == AdherenceStatus.pending;
    final taken = dose.status == AdherenceStatus.taken;
    final skipped = dose.status == AdherenceStatus.skipped;

    final stripe = taken
        ? const Color(0xFF2E7D32)
        : skipped
            ? const Color(0xFFE65100)
            : const Color(0xFF1D3557);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3EA)),
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
                  child: Icon(Icons.medication_rounded,
                      color: stripe, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dose.medicationName ?? 'Medication',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      if (dose.dosage != null &&
                          dose.dosage!.isNotEmpty)
                        Text(dose.dosage!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF3D5470))),
                    ],
                  ),
                ),
                Text(
                    DateFormat('h:mm a')
                        .format(dose.scheduledTime),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3D5470))),
              ],
            ),
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onTake,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded,
                                size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Taken',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: onSkip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEEE3),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFE65100)
                                  .withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded,
                                size: 18, color: Color(0xFFE65100)),
                            SizedBox(width: 6),
                            Text('Skip',
                                style: TextStyle(
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                          ],
                        ),
                      ),
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
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: stripe.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    taken ? 'Taken ✓' : 'Skipped',
                    style: TextStyle(
                        color: stripe,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add medication button ───────────────────────────────────

class _AddMedicationButton extends StatelessWidget {
  const _AddMedicationButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC).withOpacity(0),
            const Color(0xFFF8FAFC),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D3557),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D3557).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Add Medication',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADD MEDICATION SCREEN
// ═══════════════════════════════════════════════════════════════

class _AddMedicationScreen extends StatefulWidget {
  final String patientId;
  const _AddMedicationScreen({required this.patientId});

  @override
  State<_AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<_AddMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  int _timesPerDay = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name.')),
      );
      return;
    }
    if (dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a dosage (e.g. 500 mg).')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final ad = Provider.of<AdherenceProvider>(context,
          listen: false);
      final ok = await ad.addMedication(
        patientId: widget.patientId,
        medicationName: name,
        dosage: dosage,
        timesPerDay: _timesPerDay,
        instructions: _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _submitting = false);
        if (ok) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Medication added!'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not add — try again'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: Color(0xFFDCE3EA), width: 1)),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add medication',
                      style: GoogleFonts.fraunces(
                          fontSize: 21,
                          fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF3D5470)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medication name
                      const Text('Medication name',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D5470))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Amoxicillin',
                          hintStyle: TextStyle(
                              color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Dosage
                      const Text('Dosage',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D5470))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dosageCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 500 mg',
                          hintStyle: TextStyle(
                              color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Times per day
                      const Text('Times per day',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D5470))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (int i = 1; i <= 4; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _timesPerDay = i),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _timesPerDay == i
                                        ? const Color(0xFF1D3557)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _timesPerDay == i
                                          ? const Color(
                                              0xFF1D3557)
                                          : const Color(
                                              0xFFDCE3EA),
                                      width: _timesPerDay == i
                                          ? 2
                                          : 1.5,
                                    ),
                                  ),
                                  child: Text('$i',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: _timesPerDay == i
                                            ? Colors.white
                                            : const Color(
                                                0xFF3D5470),
                                      )),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Instructions (optional)
                      const Text('Instructions (optional)',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D5470))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _instructionsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Take with food, before meals…',
                          hintStyle: TextStyle(
                              color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Submit
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap:
                            _submitting ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D3557),
                            borderRadius:
                                BorderRadius.circular(999),
                          ),
                          child: _submitting
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                      'Add medication',
                                      style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight:
                                              FontWeight.w700,
                                          color:
                                              Colors.white)),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}