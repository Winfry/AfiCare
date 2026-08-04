import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/triage_provider.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../models/appointment_model.dart';
import '../../models/triage_model.dart';
import 'health_summary.dart';
import 'share_records.dart';
import 'expenses_screen.dart';
import 'lab_results_screen.dart';
import 'medication_tracker_screen.dart';
import 'prescriptions_list_screen.dart';
import 'appointments_screen.dart';

/// Design tokens from the AfiCare dashboard prototype.
class _C {
  static const ink = Color(0xFF152A45);
  static const canopy = Color(0xFF1D3557);
  static const canopy2 = Color(0xFF24456B);
  static const marigold = Color(0xFF64B5F6);
  static const marigold2 = Color(0xFF457B9D);
  static const sage = Color(0xFF2E7D32);
  static const mist = Color(0xFFEEF2F7);
  static const slate = Color(0xFF55708A);
  static const line = Color(0xFFDCE3EA);
  static const danger = Color(0xFFB71C1C);
  static const white = Color(0xFFFFFFFF);
  static const lBlue = Color(0xFF1565C0);
  static const medMist = Color(0xFFE9F1F5);
  static const medIce = Color(0xFFEFF6FA);
  static const medSky = Color(0xFFE5F2FD);
  static const medBg = Color(0xFFE8EDF3);
  static const medGreen = Color(0xFFEAF6EE);
}

/// Patient home dashboard — mirrors the "Onboarding & First-Run Dashboard"
/// prototype: greeting, allergy banner, MediLink ID card, quick actions,
/// vitals trend, active prescriptions, pending lab orders and clinical notes.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  static const double _twoColBreakpoint = 720;
  static const double _qaBreakpoint = 640;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appointments = Provider.of<AppointmentProvider>(context);
    final triage = Provider.of<TriageProvider>(context);
    final adherence = Provider.of<AdherenceProvider>(context);
    final prefs = Provider.of<PreferencesProvider>(context);
    final prescriptions = Provider.of<PrescriptionProvider>(context);
    final labs = Provider.of<LabProvider>(context);
    final consultations = Provider.of<PatientProvider>(context).consultations;
    final profile = Provider.of<PatientProfileProvider>(context).profile;

    final user = auth.currentUser;
    final lang = prefs.prefs?.language ?? 'en';
    final firstName = (user?.fullName ?? 'there').trim().split(' ').first;
    final fullName = user?.fullName ?? 'Patient';
    final medilinkId = (user?.medilinkId?.isNotEmpty ?? false)
        ? user!.medilinkId!
        : 'ML-XXX-XXXX';
    final allergies = profile?.allergies ?? const <String>[];
    final now = DateTime.now();
    final dateStr =
        DateFormat('EEEE, d MMMM', lang == 'sw' ? 'sw' : 'en').format(now);

    final needsOnboarding = profile == null ||
        (profile.dateOfBirth == null &&
            profile.emergencyContactName == null &&
            profile.bloodType == null &&
            allergies.isEmpty);

    final upcoming = _upcomingAppointments(appointments.appointments);
    final todayMeds = adherence.todayDoses;
    final activeRx = prescriptions.getActivePrescriptions();
    final patientAssessments = triage.assessments
        .where((a) => a.patientId == (user?.id ?? ''))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCol = constraints.maxWidth >= _twoColBreakpoint;
        final isQaWide = constraints.maxWidth >= _qaBreakpoint;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: DefaultTextStyle(
                style: GoogleFonts.ibmPlexSans(color: _C.ink, fontSize: 14),
                child: needsOnboarding
                    ? _FirstRunDashboard(
                        firstName: firstName,
                        dateStr: dateStr,
                        allergies: allergies,
                        fullName: fullName,
                        medilinkId: medilinkId,
                        hasAppointments: appointments.appointments.isNotEmpty,
                        hasMedications: todayMeds.isNotEmpty || activeRx.isNotEmpty,
                        isQaWide: isQaWide,
                      )
                    : _ReturningDashboard(
                        firstName: firstName,
                        dateStr: dateStr,
                        allergies: allergies,
                        fullName: fullName,
                        medilinkId: medilinkId,
                        upcomingCount: upcoming.length,
                        assessments: patientAssessments,
                        activeRx: activeRx,
                        labOrders: labs.orders,
                        consultations: consultations,
                        isTwoCol: isTwoCol,
                        isQaWide: isQaWide,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<AppointmentModel> _upcomingAppointments(List<AppointmentModel> all) {
    final upcoming = all.where((a) =>
        a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed).toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming;
  }
}

// ── First-run dashboard ────────────────────────────────────────────────

class _FirstRunDashboard extends StatelessWidget {
  const _FirstRunDashboard({
    required this.firstName,
    required this.dateStr,
    required this.allergies,
    required this.fullName,
    required this.medilinkId,
    required this.hasAppointments,
    required this.hasMedications,
    required this.isQaWide,
  });

  final String firstName;
  final String dateStr;
  final List<String> allergies;
  final String fullName;
  final String medilinkId;
  final bool hasAppointments;
  final bool hasMedications;
  final bool isQaWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Greeting(name: firstName, subtitle: dateStr),
        const SizedBox(height: 16),
        if (allergies.isNotEmpty) ...[
          _AllergyRow(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        const SizedBox(height: 28),
        const _SecHead(title: 'Quick actions'),
        const SizedBox(height: 12),
        _QuickActionsGrid(isWide: isQaWide),
        const SizedBox(height: 28),
        _OnboardingChecklist(
          hasAppointments: hasAppointments,
          hasMedications: hasMedications,
        ),
      ],
    );
  }
}

// ── Returning dashboard ────────────────────────────────────────────────

class _ReturningDashboard extends StatelessWidget {
  const _ReturningDashboard({
    required this.firstName,
    required this.dateStr,
    required this.allergies,
    required this.fullName,
    required this.medilinkId,
    required this.upcomingCount,
    required this.assessments,
    required this.activeRx,
    required this.labOrders,
    required this.consultations,
    required this.isTwoCol,
    required this.isQaWide,
  });

  final String firstName;
  final String dateStr;
  final List<String> allergies;
  final String fullName;
  final String medilinkId;
  final int upcomingCount;
  final List<TriageAssessment> assessments;
  final List<dynamic> activeRx;
  final List<dynamic> labOrders;
  final List<dynamic> consultations;
  final bool isTwoCol;
  final bool isQaWide;

  @override
  Widget build(BuildContext context) {
    final apptLine = upcomingCount == 1
        ? 'you have 1 upcoming appointment'
        : 'you have $upcomingCount upcoming appointments';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Greeting(name: firstName, subtitle: '$dateStr — $apptLine'),
        const SizedBox(height: 16),
        if (allergies.isNotEmpty) ...[
          _AllergyRow(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        const SizedBox(height: 28),
        const _SecHead(title: 'Quick actions'),
        const SizedBox(height: 12),
        _QuickActionsGrid(isWide: isQaWide),
        const SizedBox(height: 28),
        _rowPair(
          _VitalsTrendCard(assessments: assessments),
          const _ActivePrescriptionsCard(),
          flexLeft: 14,
          flexRight: 10,
          isTwoCol: isTwoCol,
        ),
        const SizedBox(height: 22),
        _rowPair(
          const _PendingLabsCard(),
          const _NotesCard(),
          flexLeft: 10,
          flexRight: 10,
          isTwoCol: isTwoCol,
        ),
      ],
    );
  }

  Widget _rowPair(Widget left, Widget right,
      {required int flexLeft, required int flexRight, required bool isTwoCol}) {
    if (!isTwoCol) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 22),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexLeft, child: left),
        const SizedBox(width: 16),
        Expanded(flex: flexRight, child: right),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habari, $name 👋',
          style: GoogleFonts.fraunces(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _C.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: _C.slate)),
      ],
    );
  }
}

class _SecHead extends StatelessWidget {
  const _SecHead({required this.title, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (actionText != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(actionText!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.canopy)),
            ),
          ),
      ],
    );
  }
}

class _AllergyRow extends StatelessWidget {
  const _AllergyRow({required this.allergies});

  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in allergies)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _C.danger.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: _C.danger),
                const SizedBox(width: 6),
                Text(
                  'Allergy: $a',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.danger),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// MediLink ID card — the digital identity card shown at the top of the
/// dashboard.
class _MediLinkCard extends StatelessWidget {
  const _MediLinkCard({required this.fullName, required this.medilinkId});

  final String fullName;
  final String medilinkId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.canopy, _C.canopy2, Color(0xFF14335A)],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x4764B5F6), Colors.transparent],
                  stops: [0, 0.65],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MEDILINK ID',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fullName,
                          style: GoogleFonts.fraunces(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          medilinkId,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _C.marigold,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      'P',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _chip('Registered patient'),
                  const SizedBox(width: 8),
                  _chip('NHIF/SHA linked'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white)),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: isWide ? 6 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isWide ? 1.4 : 1.1,
      children: [
        _QaCard(
          icon: Icons.medication_outlined,
          label: 'Prescriptions',
          iconColor: _C.canopy,
          iconBg: _C.medBg,
          onTap: () => _push(context, const PrescriptionsListScreen()),
        ),
        _QaCard(
          icon: Icons.check_circle_outline,
          label: 'Medications',
          iconColor: _C.marigold2,
          iconBg: _C.medMist,
          onTap: () => _push(context, const MedicationTrackerScreen()),
        ),
        _QaCard(
          icon: Icons.science_outlined,
          label: 'Lab results',
          iconColor: _C.marigold2,
          iconBg: _C.medIce,
          onTap: () => _push(context, const LabResultsScreen()),
        ),
        _QaCard(
          icon: Icons.description_outlined,
          label: 'Health summary',
          iconColor: _C.lBlue,
          iconBg: _C.medSky,
          onTap: () => _push(context, const HealthSummary()),
        ),
        _QaCard(
          icon: Icons.qr_code,
          label: 'Share records',
          iconColor: _C.canopy,
          iconBg: _C.medBg,
          onTap: () => _push(context, const ShareRecords()),
        ),
        _QaCard(
          icon: Icons.receipt_long_outlined,
          label: 'Expenses',
          iconColor: _C.sage,
          iconBg: _C.medGreen,
          onTap: () => _push(context, const ExpensesScreen()),
        ),
      ],
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _QaCard extends StatelessWidget {
  const _QaCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _C.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run checklist that nudges the patient toward a complete setup.
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({
    required this.hasAppointments,
    required this.hasMedications,
  });

  final bool hasAppointments;
  final bool hasMedications;

  @override
  Widget build(BuildContext context) {
    final done = [false, hasAppointments, hasMedications, false];
    final doneCount = done.where((d) => d).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Let's get you started",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                '$doneCount of 4',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.slate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: doneCount / 4,
              minHeight: 5,
              backgroundColor: _C.line,
              valueColor: const AlwaysStoppedAnimation<Color>(_C.sage),
            ),
          ),
          const SizedBox(height: 6),
          _ChecklistRow(
            label: 'Complete your health profile',
            done: done[0],
            onTap: () => context.go('/onboarding'),
          ),
          _ChecklistRow(
            label: 'Book your first appointment',
            done: done[1],
            onTap: () => _push(context, const AppointmentsScreen()),
          ),
          _ChecklistRow(
            label: 'Add a medication',
            done: done[2],
            onTap: () => _push(context, const MedicationTrackerScreen()),
          ),
          _ChecklistRow(
            label: 'Set up sharing (QR code)',
            done: done[3],
            onTap: () => _push(context, const ShareRecords()),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _C.sage : Colors.transparent,
                border: Border.all(
                  color: done ? _C.sage : _C.line,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? _C.slate : _C.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: _C.slate),
          ],
        ),
      ),
    );
  }
}

// ── Returning dashboard cards ──────────────────────────────────────────

class _VitalsTrendCard extends StatelessWidget {
  const _VitalsTrendCard({required this.assessments});

  final List<TriageAssessment> assessments;

  @override
  Widget build(BuildContext context) {
    final sorted = [...assessments]
      ..sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
    final latest = sorted.isNotEmpty ? sorted.first : null;
    final bars = _vitalsBars();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 Vitals trend (last 30 days)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++)
                  Expanded(
                    child: Container(
                      height: bars[i],
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: i == bars.length - 1
                            ? _C.canopy
                            : _C.marigold2.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _readout(
                    'BP',
                    (latest?.systolicBP != null &&
                            latest?.diastolicBP != null)
                        ? '${latest!.systolicBP}/${latest.diastolicBP}'
                        : '—'),
                _readout(
                    'HR',
                    latest?.heartRate != null
                        ? '${latest!.heartRate} bpm'
                        : '—'),
                _readout(
                    'SpO2',
                    latest?.oxygenSaturation != null
                        ? '${latest!.oxygenSaturation!.toInt()}%'
                        : '—'),
                _readout(
                    'Temp',
                    latest?.temperature != null
                        ? '${latest!.temperature!.toStringAsFixed(1)}°C'
                        : '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readout(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: _C.slate)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink)),
      ],
    );
  }

  List<double> _vitalsBars() {
    final rates = assessments
        .where((a) => a.heartRate != null)
        .map((a) => a.heartRate!)
        .take(10)
        .toList();
    if (rates.length < 2) {
      return [55, 62, 48, 70, 90, 66, 58, 74, 86, 94]
          .map((h) => h * 0.9)
          .toList();
    }
    final min = rates.reduce((a, b) => a < b ? a : b).toDouble();
    final max = rates.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (max - min) < 1 ? 1.0 : (max - min);
    return rates
        .map((r) => 20 + ((r - min) / span) * 70)
        .map((h) => h.clamp(15.0, 95.0))
        .toList();
  }
}

class _ActivePrescriptionsCard extends StatelessWidget {
  const _ActivePrescriptionsCard();

  @override
  Widget build(BuildContext context) {
    final prescriptions = Provider.of<PrescriptionProvider>(context)
        .getActivePrescriptions();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecHead(
            title: '📄 Active prescriptions',
            actionText: 'View all',
            onAction: () => _push(context, const PrescriptionsListScreen()),
          ),
          const SizedBox(height: 2),
          if (prescriptions.isEmpty)
            _empty('No active prescriptions')
          else
            for (final p in prescriptions.take(4)) _rxRow(p),
        ],
      ),
    );
  }

  Widget _rxRow(dynamic p) {
    final name = p.medicationName as String;
    final instr = (p.instructions as String?)?.isNotEmpty ?? false
        ? p.instructions as String
        : '${p.frequency}${(p.dosage as String).isNotEmpty ? ' · ${p.dosage}' : ''}';
    final expiresAt = p.expiresAt as DateTime?;
    final days = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inDays
        : -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _C.canopy)),
          const SizedBox(height: 4),
          Text(instr,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: _C.ink,
                  height: 1.4)),
          const SizedBox(height: 6),
          Text(
            days > 0 ? '$days days remaining' : 'Active',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: days > 0 ? _C.canopy : _C.sage,
            ),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _PendingLabsCard extends StatelessWidget {
  const _PendingLabsCard();

  @override
  Widget build(BuildContext context) {
    final orders = Provider.of<LabProvider>(context).orders;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧪 Pending lab orders',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (orders.isEmpty)
            _empty('No lab orders yet')
          else
            for (var i = 0; i < orders.take(5).length; i++)
              _labRow(orders[i], isLast: i == orders.take(5).length - 1),
        ],
      ),
    );
  }

  Widget _labRow(dynamic order, {required bool isLast}) {
    final status = _labStatusLabel(order.status as dynamic);
    final (bg, fg) = _labStatusColors(status);
    final orderedAt = order.orderedAt as DateTime;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.testName as String,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Ordered: ${DateFormat('MMM d, yyyy').format(orderedAt)}',
                  style: const TextStyle(fontSize: 12, color: _C.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }

  String _labStatusLabel(dynamic status) {
    switch (status.toString()) {
      case 'LabOrderStatus.processing':
        return 'Processing';
      case 'LabOrderStatus.completed':
        return 'Completed';
      case 'LabOrderStatus.cancelled':
        return 'Cancelled';
      default:
        return 'Scheduled';
    }
  }

  (Color, Color) _labStatusColors(String label) {
    switch (label) {
      case 'Processing':
        return (_C.marigold2.withOpacity(0.12), _C.marigold2);
      case 'Completed':
        return (_C.mist, _C.slate);
      default:
        return (_C.mist, _C.slate);
    }
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    final consultations = Provider.of<PatientProvider>(context).consultations;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecHead(
            title: '📄 Recent clinical notes',
            actionText: 'View all',
            onAction: () => _push(context, const HealthSummary()),
          ),
          const SizedBox(height: 6),
          if (consultations.isEmpty)
            _empty('No clinical notes yet')
          else
            for (final c in consultations.take(3)) _noteCard(c),
        ],
      ),
    );
  }

  Widget _noteCard(dynamic c) {
    final chief = c.chiefComplaint as String;
    final timestamp = c.timestamp as DateTime;
    final notes = c.notes as String?;
    final symptoms = (c.symptoms as List?) ?? const [];
    final snippet = (notes != null && notes.isNotEmpty)
        ? notes
        : symptoms.isNotEmpty
            ? symptoms.join(', ')
            : 'No additional details recorded.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _C.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chief.isNotEmpty ? 'Visit — $chief' : 'Consultation',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, size: 15, color: _C.slate),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('MMM d, yyyy').format(timestamp),
            style: const TextStyle(
                fontSize: 11.5, color: _C.slate, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _C.ink, height: 1.5),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ── Shared containers ──────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: child,
    );
  }
}

Widget _empty(String message) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(message,
        style: const TextStyle(fontSize: 13.5, color: _C.slate)),
  );
}
