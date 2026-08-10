import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../models/disability_profile.dart';
import '../../services/pwd_rule_engine.dart';
import '../../services/tts_service.dart';
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
/// prototype. First run: hero banner, greeting, allergy strip, MediLink ID
/// card and a single-focus setup checklist (no quick actions — they would
/// overwhelm a new patient). Returning: the full quick-action + card grid.
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

    final ttsEnabled = prefs.prefs?.textToSpeech ?? false;
    final listenText = ttsEnabled
        ? 'Habari, $firstName. $dateStr. '
            '${upcoming.isEmpty ? "You have no upcoming appointments." : "You have ${upcoming.length} upcoming appointment${upcoming.length == 1 ? '' : 's'}."}'
        : null;
    final patientId = user?.id;

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
                        listenText: listenText,
                        patientId: patientId,
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
                        listenText: listenText,
                        patientId: patientId,
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
    this.listenText,
    this.patientId,
  });

  final String firstName;
  final String dateStr;
  final List<String> allergies;
  final String fullName;
  final String medilinkId;
  final bool hasAppointments;
  final bool hasMedications;
  final String? listenText;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroBanner(),
        const SizedBox(height: 20),
        _Greeting(name: firstName, subtitle: dateStr, listenText: listenText),
        const SizedBox(height: 16),
        if (allergies.isNotEmpty) ...[
          _AllergyRow(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        if (patientId != null) ...[
          const SizedBox(height: 20),
          _CaregiverAlertsCard(patientId: patientId!),
        ],
        const SizedBox(height: 28),
        _OnboardingChecklist(
          hasAppointments: hasAppointments,
          hasMedications: hasMedications,
        ),
        const SizedBox(height: 24),
        const _TrustBanner(),
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
    this.listenText,
    this.patientId,
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
  final String? listenText;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    final apptLine = upcomingCount == 1
        ? 'you have 1 upcoming appointment'
        : 'you have $upcomingCount upcoming appointments';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Greeting(
            name: firstName,
            subtitle: '$dateStr — $apptLine',
            listenText: listenText),
        const SizedBox(height: 16),
        if (allergies.isNotEmpty) ...[
          _AllergyRow(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        if (patientId != null) ...[
          const SizedBox(height: 20),
          _CaregiverAlertsCard(patientId: patientId!),
        ],
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
  const _Greeting({required this.name, required this.subtitle, this.listenText, this.avatarImage});

  final String name;
  final String subtitle;
  final String? listenText;
  final ImageProvider? avatarImage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
              Text(subtitle,
                  style: const TextStyle(fontSize: 14, color: _C.slate)),
            ],
            ),
          ),
        if (avatarImage != null)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: avatarImage!, fit: BoxFit.cover),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x29152A45),
                    blurRadius: 16,
                    offset: Offset(0, 6)),
              ],
            ),
          ),
        if (listenText != null)
          IconButton(
            onPressed: () => tts.speak(listenText!),
            tooltip: 'Listen',
            icon: const Icon(Icons.volume_up_rounded),
            color: _C.canopy,
            iconSize: 22,
            style: IconButton.styleFrom(
              backgroundColor: _C.mist,
              minimumSize: const Size(42, 42),
            ),
          ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: const DecorationImage(
          image: AssetImage('assets/images/hero.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _C.canopy.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: -50,
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
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              'Warm. Human. Reassuring.\nEvery step here is here to help you.',
              style: GoogleFonts.fraunces(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.mist,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/Trust.jpeg',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You're in good hands",
                    style: GoogleFonts.fraunces(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Your health information is private and secure. '
                  'Only you decide who sees it.',
                  style: TextStyle(fontSize: 13.5, color: _C.slate, height: 1.5),
                ),
                const SizedBox(height: 12),
                Material(
                  color: _C.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: _C.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showPrivacyDialog(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      child: Text(
                        'Learn how we protect you',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _C.canopy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("You're in good hands"),
        content: const Text(
          'AfiCare keeps your health information private and secure.\n\n'
          '• Your records are encrypted at rest and in transit.\n'
          '• Sharing is always on your terms — you set the access codes.\n'
          '• You can revoke access at any time, right from your settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it',
                style: TextStyle(
                    color: _C.canopy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
  const _MediLinkCard({required this.fullName, required this.medilinkId, this.photo});

  final String fullName;
  final String medilinkId;
  final ImageProvider? photo;

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
                  if (photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image(image: photo!, width: 56, height: 56, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _C.marigold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 21,
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

/// First-run checklist — the single focus of the simplified first-run
/// dashboard. Pending steps get a prominent navy pill button; finished
/// steps are struck through with a filled check.
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({
    required this.hasAppointments,
    required this.hasMedications,
  });

  final bool hasAppointments;
  final bool hasMedications;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ChecklistData(
        label: 'Complete your health profile',
        sub: 'Tell us a bit about you',
        done: false,
        actionText: 'Complete',
        onTap: () => context.go('/onboarding'),
      ),
      _ChecklistData(
        label: 'Book your first appointment',
        sub: 'Find a doctor and book',
        done: hasAppointments,
        actionText: 'Book now',
        onTap: () => _push(context, const AppointmentsScreen()),
      ),
      _ChecklistData(
        label: 'Add a medication',
        sub: 'Keep track of your medicines',
        done: hasMedications,
        actionText: 'Add now',
        onTap: () => _push(context, const MedicationTrackerScreen()),
      ),
      _ChecklistData(
        label: 'Set up sharing (QR code)',
        sub: 'Share your records securely',
        done: false,
        actionText: 'Set up',
        onTap: () => _push(context, const ShareRecords()),
      ),
    ];
    final doneCount = items.where((i) => i.done).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          final checklistContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Let's get you started",
                  style: GoogleFonts.fraunces(
                      fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text("A few simple steps — take them whenever you're ready.",
                  style: TextStyle(fontSize: 14.5, color: _C.slate)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: doneCount / items.length,
                        minHeight: 8,
                        backgroundColor: _C.line,
                        valueColor: const AlwaysStoppedAnimation<Color>(_C.sage),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$doneCount of ${items.length} done',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.slate),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final item in items)
                _ChecklistRow(
                  label: item.label,
                  sub: item.sub,
                  done: item.done,
                  actionText: item.done ? null : item.actionText,
                  onTap: item.onTap,
                ),
            ],
          );

          final photo = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/checklist.png',
              fit: BoxFit.cover,
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 130,
                  child: photo,
                ),
                const SizedBox(height: 18),
                checklistContent,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: checklistContent),
              const SizedBox(width: 22),
              SizedBox(width: 180, child: photo),
            ],
          );
        },
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ChecklistData {
  const _ChecklistData({
    required this.label,
    required this.sub,
    required this.done,
    required this.actionText,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool done;
  final String actionText;
  final VoidCallback onTap;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.sub,
    required this.done,
    required this.onTap,
    this.actionText,
  });

  final String label;
  final String sub;
  final bool done;
  final VoidCallback onTap;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _C.line.withOpacity(0.7)),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _C.sage : Colors.transparent,
              border: Border.all(
                color: done ? _C.sage : _C.line,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? _C.slate : _C.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 13, color: _C.slate),
                ),
              ],
            ),
          ),
          if (actionText != null) ...[
            const SizedBox(width: 10),
            Material(
              color: _C.canopy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  child: Text(
                    actionText!,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Caregiver alerts card ─────────────────────────────────────────────

class _CaregiverAlertsCard extends StatelessWidget {
  const _CaregiverAlertsCard({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final future = Supabase.instance.client
        .from('disability_profiles')
        .select()
        .eq('patient_id', patientId)
        .maybeSingle();

    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();

        DisabilityProfile profile;
        try {
          profile = DisabilityProfile.fromMap(data);
        } catch (_) {
          return const SizedBox.shrink();
        }
        if (!profile.hasCaregiver) return const SizedBox.shrink();

        final caregiver = profile.caregiver!;
        final alerts = const PwdRuleEngine()
            .getProviderNotes(profile)
            .where((r) =>
                r.category == RecommendationCategory.caregiverAlert)
            .toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.medBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt_rounded,
                      size: 18, color: _C.canopy),
                  SizedBox(width: 8),
                  Text(
                    'Caregiver access active',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${caregiver.name} (${caregiver.relationship}) can see: '
                '${caregiver.permissions.join(', ')}',
                style: const TextStyle(fontSize: 12.5, color: _C.slate),
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final alert in alerts.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.sage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: _C.ink,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Caregiver alerts will appear here as your care plan updates.',
                  style: TextStyle(fontSize: 12.5, color: _C.slate),
                ),
              ],
            ],
          ),
        );
      },
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
