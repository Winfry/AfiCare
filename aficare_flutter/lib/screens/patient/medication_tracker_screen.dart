import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/adherence_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
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
      await ad.loadHistory(id, days: 7);
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
          builder: (_) => _AddMedicationScreen(patientId: patientId)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final firstName =
        (auth.currentUser?.fullName ?? 'there').split(' ').first;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: Column(
        children: [
          _MedicationHero(firstName: firstName),
          Expanded(
            child: Consumer<AdherenceProvider>(
              builder: (context, ad, _) {
                if (ad.todayDoses.isEmpty) return _buildEmptyState();
                return RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Score card sits cleanly below hero
                              const SizedBox(height: 20),
                              _ScoreCard(
                                score: ad.todayScore,
                                remaining: ad.todayRemaining,
                                firstName: firstName,
                                streak: ad.streak,
                              ),
                              const SizedBox(height: 26),
                              // Section header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Today\'s doses',
                                          style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2F7),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                            '${ad.todayDoses.length}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF3D5470))),
                                      ),
                                    ],
                                  ),
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
                              const SizedBox(height: 12),
                              ...ad.todayDoses.map((d) => _DoseCard(
                                    dose: d,
                                    onTake: () => _mark(
                                        d, AdherenceStatus.taken),
                                    onSkip: () => _mark(
                                        d, AdherenceStatus.skipped),
                                  )),
                              const SizedBox(height: 6),
                              _PastDosesToggle(
                                pastDoses: ad.history
                                    .where((d) =>
                                        d.status !=
                                            AdherenceStatus.pending &&
                                        d.scheduledTime.day !=
                                            DateTime.now().day)
                                    .take(10)
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 100),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/images/med-empty.png',
                      width: 140, height: 140, fit: BoxFit.contain),
                ),
                const SizedBox(height: 18),
                Text('No medications yet',
                    style: GoogleFonts.fraunces(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Tap "Add Medication" below to start tracking your daily pills.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF3D5470)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero (220px, photo on right 45%, strong gradient) ─────────

class _MedicationHero extends StatelessWidget {
  const _MedicationHero({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Container(
          width: double.infinity,
          height: 230,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/med-hero.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1D3557),
                const Color(0xFF1D3557),
                const Color(0xFF1D3557).withOpacity(0.82),
                const Color(0xFF1D3557).withOpacity(0.0),
              ],
              stops: const [0, 0.35, 0.55, 0.95],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                // Left: text content
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('MEDICATIONS',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: Colors.white.withOpacity(0.7))),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Colors.white, size: 16),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE65100),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF1D3557),
                                        width: 1.5),
                                  ),
                                  child: const Text('1',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700),
                                      textAlign: TextAlign.center),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Hello, $firstName',
                          style: GoogleFonts.fraunces(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          'Stay on track with your medication routine.',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.75))),
                    ],
                  ),
                ),
                // Right: spacer for photo area
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score card (3 information zones) ──────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.remaining,
    required this.firstName,
    required this.streak,
  });
  final int score;
  final int remaining;
  final String firstName;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE3EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15152A45),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Zone 1: Score ring
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFEAF6EE),
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score%',
                        style: GoogleFonts.fraunces(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32))),
                    const Text('TODAY',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3D5470))),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 60,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFFDCE3EA),
          ),
          // Zone 2: Remaining + message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                          text: remaining == 0
                              ? 'All done! '
                              : '$remaining dose${remaining == 1 ? '' : 's'} ',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const TextSpan(
                          text: 'remaining',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remaining == 0
                      ? 'Perfect adherence today, $firstName.'
                      : 'Keep going — you\'re doing great.',
                  style: const TextStyle(
                      fontSize: 13.5, color: Color(0xFF3D5470)),
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEEE3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 16, color: Color(0xFFE65100)),
                        const SizedBox(width: 5),
                        Text('$streak day streak',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF152A45))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Zone 3: Companion photo (hidden on mobile)
          if (MediaQuery.of(context).size.width > 600)
            Container(
              width: 220,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage('assets/images/med-companion.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Dose card (two-column: details left, time/status right) ────

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.dose, required this.onTake, required this.onSkip});
  final AdherenceLogModel dose;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final pending = dose.status == AdherenceStatus.pending;
    final taken = dose.status == AdherenceStatus.taken;
    final skipped = dose.status == AdherenceStatus.skipped;
    final stripeColor = taken
        ? const Color(0xFF2E7D32)
        : skipped
            ? const Color(0xFFE65100)
            : const Color(0xFF1D3557);
    final iconBg = taken
        ? const Color(0xFFEAF6EE)
        : skipped
            ? const Color(0xFFFDEEE3)
            : const Color(0xFFE9F1F5);
    final iconColor = taken
        ? const Color(0xFF2E7D32)
        : skipped
            ? const Color(0xFFE65100)
            : const Color(0xFF457B9D);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: stripeColor, width: 4),
          top: const BorderSide(color: Color(0xFFDCE3EA)),
          right: const BorderSide(color: Color(0xFFDCE3EA)),
          bottom: const BorderSide(color: Color(0xFFDCE3EA)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: icon + name/details
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Icon(Icons.medication_rounded,
                color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dose.medicationName ?? 'Medication',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
                Text(dose.dosage ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF3D5470))),
                if (pending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onTake,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF2E7D32),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 16, color: Color(0xFF2E7D32)),
                              SizedBox(width: 5),
                              Text('Taken',
                                  style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onSkip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE65100),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded,
                                  size: 16, color: Color(0xFFE65100)),
                              SizedBox(width: 5),
                              Text('Skip',
                                  style: TextStyle(
                                      color: Color(0xFFE65100),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: taken
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFFDEEE3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            taken
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            size: 14,
                            color: taken
                                ? Colors.white
                                : const Color(0xFFE65100)),
                        const SizedBox(width: 5),
                        Text(
                          taken ? 'Taken' : 'Skipped',
                          style: TextStyle(
                            color: taken
                                ? Colors.white
                                : const Color(0xFFE65100),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Right: time + period
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormat('h:mm a').format(dose.scheduledTime),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_periodIcon(dose.scheduledTime.hour),
                      size: 14, color: const Color(0xFF3D5470)),
                  const SizedBox(width: 4),
                  Text(_periodLabel(dose.scheduledTime.hour),
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3D5470),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _periodIcon(int hour) {
    if (hour < 12) return Icons.wb_twilight;
    if (hour < 17) return Icons.wb_sunny_outlined;
    if (hour < 21) return Icons.brightness_4_outlined;
    return Icons.nightlight_round;
  }

  String _periodLabel(int hour) {
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }
}

// ── Past doses toggle ──────────────────────────────────────────

class _PastDosesToggle extends StatefulWidget {
  const _PastDosesToggle({required this.pastDoses});
  final List<AdherenceLogModel> pastDoses;

  @override
  State<_PastDosesToggle> createState() => _PastDosesToggleState();
}

class _PastDosesToggleState extends State<_PastDosesToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.pastDoses.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE3EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Past doses (${widget.pastDoses.length})',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF3D5470)),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Opacity(
              opacity: 0.7,
              child: Column(
                children: widget.pastDoses
                    .map((d) => _DoseCard(
                          dose: d,
                          onTake: () {},
                          onSkip: () {},
                        ))
                    .toList(),
              ),
            ),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}

// ── Add medication button ──────────────────────────────────────

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
            const Color(0xFFEEF2F7).withOpacity(0),
            const Color(0xFFEEF2F7),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29152A45),
                      blurRadius: 16,
                      offset: Offset(0, 4),
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADD MEDICATION SCREEN
// ═══════════════════════════════════════════════════════════════

enum _MedCategory { antibiotic, heart, vitamin }

class _AddMedicationScreen extends StatefulWidget {
  final String patientId;
  const _AddMedicationScreen({required this.patientId});

  @override
  State<_AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<_AddMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  int _timesPerDay = 1;
  _MedCategory _category = _MedCategory.antibiotic;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name.')),
      );
      return;
    }
    if (_dosageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a dosage (e.g. 500 mg).')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final ad = Provider.of<AdherenceProvider>(context, listen: false);
      final ok = await ad.addMedication(
        patientId: widget.patientId,
        medicationName: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
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
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
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
                    bottom:
                        BorderSide(color: Color(0xFFDCE3EA), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add medication',
                      style: GoogleFonts.fraunces(
                          fontSize: 21, fontWeight: FontWeight.w700)),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              hintStyle:
                                  TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(12)),
                                borderSide: BorderSide(
                                    color: Color(0xFFDCE3EA),
                                    width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                              hintStyle:
                                  TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(12)),
                                borderSide: BorderSide(
                                    color: Color(0xFFDCE3EA),
                                    width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Category',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3D5470))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final cat in [
                                (_MedCategory.antibiotic, 'Antibiotic', '💊',
                                    const Color(0xFFE9F1F5),
                                    const Color(0xFF457B9D)),
                                (_MedCategory.heart, 'Heart / BP', '❤️',
                                    const Color(0xFFFBEAEA),
                                    const Color(0xFFB71C1C)),
                                (_MedCategory.vitamin, 'Vitamin', '🌿',
                                    const Color(0xFFEAF6EE),
                                    const Color(0xFF2E7D32)),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _category = cat.$1),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14,
                                                horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _category == cat.$1
                                                ? cat.$4
                                                : const Color(0xFFDCE3EA),
                                            width:
                                                _category == cat.$1 ? 2 : 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: cat.$4,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                              child: Center(
                                                child: Text(cat.$3,
                                                    style: const TextStyle(
                                                        fontSize: 16)),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(cat.$2,
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Times per day',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3D5470))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (int i = 1; i <= 4; i++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _timesPerDay = i),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        decoration: BoxDecoration(
                                          color: _timesPerDay == i
                                              ? const Color(0xFF1D3557)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _timesPerDay == i
                                                ? const Color(0xFF1D3557)
                                                : const Color(0xFFDCE3EA),
                                            width: _timesPerDay == i ? 2 : 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text('$i',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: _timesPerDay == i
                                                    ? Colors.white
                                                    : const Color(0xFF152A45),
                                              )),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Instructions (optional)',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3D5470))),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _instructionsCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Take with food, before meals…',
                              hintStyle:
                                  TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(12)),
                                borderSide: BorderSide(
                                    color: Color(0xFFDCE3EA),
                                    width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _submitting ? null : _submit,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D3557),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: _submitting
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('Add medication',
                                          style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
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