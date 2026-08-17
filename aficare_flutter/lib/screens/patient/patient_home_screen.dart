import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/care_team_provider.dart';
import '../../utils/app_strings.dart';
import '../../models/appointment_model.dart';
import '../../models/disability_profile.dart';
import '../../models/prescription_model.dart';
import '../../models/adherence_model.dart';
import '../../models/care_team_member_model.dart';
import '../../services/pwd_rule_engine.dart';
import '../../services/tts_service.dart';
import 'health_summary.dart';
import 'share_records.dart';
import 'expenses_screen.dart';
import 'medication_tracker_screen.dart';
import 'appointments_screen.dart';

/// Design tokens from the AfiCare dashboard prototype.
class _C {
  static const ink = Color(0xFF152A45);
  static const canopy = Color(0xFF1D3557);
  static const canopy2 = Color(0xFF24456B);
  static const marigold = Color(0xFF64B5F6);
  static const sage = Color(0xFF2E7D32);
  static const mist = Color(0xFFEEF2F7);
  static const slate = Color(0xFF55708A);
  static const line = Color(0xFFDCE3EA);
  static const danger = Color(0xFFB71C1C);
  static const white = Color(0xFFFFFFFF);
  static const lBlue = Color(0xFF1565C0);
  static const medBg = Color(0xFFE8EDF3);

  // ── Returning dashboard tokens (spec §4 color system) ────────────
  static const heroDeep   = Color(0xFF102B4E);
  static const softBlue   = Color(0xFFEAF3FC);
  static const softGreen  = Color(0xFFEAF5EC);
  static const warmOrange = Color(0xFFF57F17);
  static const warmCream  = Color(0xFFFBF6EF);
  static const ringTrack  = Color(0xFFE3E8ED);
}

/// Patient home dashboard — mirrors the "Onboarding & First-Run Dashboard"
/// prototype. First run: hero banner, greeting, allergy strip, MediLink ID
/// card and a single-focus setup checklist (no quick actions — they would
/// overwhelm a new patient). Returning: the full quick-action + card grid.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  static const double _threeColBreakpoint = 940;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appointments = Provider.of<AppointmentProvider>(context);
    final adherence = Provider.of<AdherenceProvider>(context);
    final prefs = Provider.of<PreferencesProvider>(context);
    final prescriptions = Provider.of<PrescriptionProvider>(context);
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
        profile.dateOfBirth == null ||
        profile.emergencyContactName == null ||
        profile.bloodType == null ||
        allergies.isEmpty;

    final profileHasStarted = profile != null &&
        (profile.dateOfBirth != null ||
            profile.bloodType != null ||
            profile.emergencyContactName != null);

    final ttsEnabled = prefs.prefs?.textToSpeech ?? false;
    final listenText = ttsEnabled ? 'Habari, $firstName. $dateStr.' : null;
    final patientId = user?.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _threeColBreakpoint;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isWide ? 32 : 20,
            8,
            isWide ? 32 : 20,
            60,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: DefaultTextStyle(
                style: GoogleFonts.ibmPlexSans(color: _C.ink, fontSize: 14),
                child: needsOnboarding
                    ? _FirstRunDashboard(
                        firstName: firstName,
                        allergies: allergies,
                        fullName: fullName,
                        medilinkId: medilinkId,
                        hasAppointments: appointments.appointments.isNotEmpty,
                        hasMedications:
                            adherence.todayDoses.isNotEmpty ||
                                prescriptions.getActivePrescriptions().isNotEmpty,
                        profileHasStarted: profileHasStarted,
                        lang: lang,
                        listenText: listenText,
                        patientId: patientId,
                      )
                    : _ReturningDashboard(
                        firstName: firstName,
                        allergies: allergies,
                        lang: lang,
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
}

// ── First-run dashboard ────────────────────────────────────────────────

class _FirstRunDashboard extends StatelessWidget {
  const _FirstRunDashboard({
    required this.firstName,
    required this.allergies,
    required this.fullName,
    required this.medilinkId,
    required this.hasAppointments,
    required this.hasMedications,
    required this.profileHasStarted,
    required this.lang,
    this.listenText,
    this.patientId,
  });

  final String firstName;
  final List<String> allergies;
  final String fullName;
  final String medilinkId;
  final bool hasAppointments;
  final bool hasMedications;
  final bool profileHasStarted;
  final String lang;
  final String? listenText;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    const lang = 'en';
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Same hero as returning dashboard — greeting + 3 shortcuts
            _ReturningHero(
              firstName: firstName,
              lang: lang,
              listenText: listenText,
            ),
            if (allergies.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AllergyRow(allergies: allergies, lang: lang),
            ],
            const SizedBox(height: 20),
            // Row: MediLink ID card (left) + Caregiver alerts (right, if any)
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _MediLinkCard(
                        fullName: fullName, medilinkId: medilinkId, lang: lang),
                  ),
                  if (patientId != null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _CaregiverAlertsCard(patientId: patientId!),
                    ),
                  ],
                ],
              )
            else ...[
              _MediLinkCard(
                  fullName: fullName, medilinkId: medilinkId, lang: lang),
              if (patientId != null) ...[
                const SizedBox(height: 16),
                _CaregiverAlertsCard(patientId: patientId!),
              ],
            ],
            const SizedBox(height: 24),
            // Row: Onboarding checklist (left, wider) + Trust banner (right)
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _OnboardingChecklist(
                      hasAppointments: hasAppointments,
                      hasMedications: hasMedications,
                      profileHasStarted: profileHasStarted,
                      lang: lang,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    flex: 4,
                    child: _TrustBanner(lang: lang),
                  ),
                ],
              )
            else ...[
              _OnboardingChecklist(
                hasAppointments: hasAppointments,
                hasMedications: hasMedications,
                profileHasStarted: profileHasStarted,
                lang: lang,
              ),
              const SizedBox(height: 16),
              const _TrustBanner(lang: lang),
            ],
          ],
        );
      },
    );
  }
}

// ── Returning dashboard ────────────────────────────────────────────────
//
// Three-row architecture (spec §19):
//   1. Hero  — photo + navy overlay + greeting + 3 contextual shortcuts
//   2. Row 1 — Today's Summary · Upcoming Appointment · Active Medications
//   3. Row 2 — Care Team · Quick Actions · Health Tip  (placeholder)
//
// Responsive: 3 columns ≥940px, 2 ≥600px, 1 below.

class _ReturningDashboard extends StatelessWidget {
  const _ReturningDashboard({
    required this.firstName,
    required this.allergies,
    required this.lang,
    this.listenText,
    this.patientId,
  });

  final String firstName;
  final List<String> allergies;
  final String lang;
  final String? listenText;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 940
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReturningHero(
              firstName: firstName,
              lang: lang,
              listenText: listenText,
            ),
            if (allergies.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AllergyRow(allergies: allergies, lang: lang),
            ],
            const SizedBox(height: 20),
            _summaryRow(
              [
                const _TodaysSummaryCard(),
                const _UpcomingAppointmentCard(),
                const _ActiveMedicationsCard(),
              ],
              cols,
              16,
            ),
            if (patientId != null) ...[
              const SizedBox(height: 20),
              _CaregiverAlertsCard(patientId: patientId!),
            ],
            const SizedBox(height: 24),
            _summaryRow(
              [
                if (patientId != null)
                  _CareTeamCard(patientId: patientId!)
                else
                  const _Card(child: SizedBox(height: 40)),
                const _QuickActionsCard(),
                const _HealthTipCard(),
              ],
              cols,
              16,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(List<Widget> cards, int cols, double gap) {
    if (cols >= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) SizedBox(width: gap),
          ],
        ],
      );
    }
    if (cols == 2) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              SizedBox(width: gap),
              Expanded(child: cards[1]),
            ],
          ),
          SizedBox(height: gap),
          cards[2],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

// ── Returning hero ─────────────────────────────────────────────────────

class _ReturningHero extends StatelessWidget {
  const _ReturningHero({
    required this.firstName,
    required this.lang,
    this.listenText,
  });

  final String firstName;
  final String lang;
  final String? listenText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;

        final shortcuts = [
          _HeroShortcut(
            icon: Icons.medication_outlined,
            iconBg: _C.softGreen,
            iconColor: _C.sage,
            title: 'Stay on track',
            subtitle: 'Keep up with your medications',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MedicationTrackerScreen()),
            ),
          ),
          _HeroShortcut(
            icon: Icons.calendar_today_outlined,
            iconBg: _C.warmCream,
            iconColor: _C.canopy,
            title: 'Upcoming care',
            subtitle: 'View and manage your appointments',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          _HeroShortcut(
            icon: Icons.description_outlined,
            iconBg: _C.softBlue,
            iconColor: _C.lBlue,
            title: 'Your records',
            subtitle: 'Access your health information',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthSummary()),
            ),
          ),
        ];

        return Container(
          width: double.infinity,
          height: isWide ? 290 : 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            image: const DecorationImage(
              image: AssetImage('assets/images/hero.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Navy gradient overlay — fades left → right
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          _C.heroDeep,
                          _C.canopy.withOpacity(0.85),
                          _C.canopy.withOpacity(0.25),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.35, 0.65, 0.9],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 36 : 24,
                    isWide ? 32 : 24,
                    isWide ? 36 : 24,
                    isWide ? 28 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting + welcome line
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    AppStrings.greeting(firstName, lang),
                                    style: GoogleFonts.fraunces(
                                      fontSize: isWide ? 34 : 26,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (listenText != null)
                                  IconButton(
                                    onPressed: () => tts.speak(listenText!),
                                    tooltip: 'Listen',
                                    icon: const Icon(Icons.volume_up_rounded),
                                    color: Colors.white70,
                                    iconSize: 20,
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.15),
                                      minimumSize: const Size(36, 36),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang == 'sw'
                                  ? 'Karibu tena! Huu hapa ni muhtasari wa afya yako.'
                                  : "Welcome back! Here's your health overview.",
                              style: TextStyle(
                                fontSize: isWide ? 15 : 14,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Shortcut tiles
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            for (int i = 0; i < shortcuts.length; i++) ...[
                              Expanded(child: shortcuts[i]),
                              if (i < shortcuts.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        )
                      else
                        Column(
                          children: [
                            for (int i = 0; i < shortcuts.length; i++) ...[
                              shortcuts[i],
                              if (i < shortcuts.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
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
}

class _HeroShortcut extends StatelessWidget {
  const _HeroShortcut({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.75))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row 1: Today's Summary ─────────────────────────────────────────────

class _TodaysSummaryCard extends StatelessWidget {
  const _TodaysSummaryCard();

  @override
  Widget build(BuildContext context) {
    final adherence = Provider.of<AdherenceProvider>(context);
    final score = adherence.todayScore;
    final remaining = adherence.todayRemaining;
    final streak = adherence.streak;
    final hasDoses = adherence.todayDoses.isNotEmpty;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecHead(
            title: "Today's Summary",
            actionText: 'View all',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MedicationTrackerScreen()),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
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
                        value: hasDoses ? score / 100 : 0,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: _C.ringTrack,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_C.sage),
                      ),
                    ),
                    Text(
                      hasDoses ? '$score%' : '--',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDoses
                          ? (remaining > 0
                              ? '$remaining dose${remaining == 1 ? '' : 's'} remaining'
                              : 'All doses taken')
                          : 'No doses today',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasDoses
                          ? (remaining > 0
                              ? "Keep going — you're doing great."
                              : "Perfect! All done for today.")
                          : 'No medications scheduled today.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _C.slate,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (streak > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.warmOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '$streak day streak',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.warmOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Row 1: Upcoming Appointment ────────────────────────────────────────

class _UpcomingAppointmentCard extends StatefulWidget {
  const _UpcomingAppointmentCard();

  @override
  State<_UpcomingAppointmentCard> createState() =>
      _UpcomingAppointmentCardState();
}

class _UpcomingAppointmentCardState extends State<_UpcomingAppointmentCard> {
  String? _providerName;
  String? _providerDept;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProvider());
  }

  Future<void> _loadProvider() async {
    final appts =
        Provider.of<AppointmentProvider>(context, listen: false).appointments;
    final now = DateTime.now();
    final upcoming = appts
        .where((a) =>
            a.scheduledAt.isAfter(now) &&
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.completed)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (upcoming.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final prov = await Supabase.instance.client
          .from('users')
          .select('full_name, department')
          .eq('id', upcoming.first.providerId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _providerName = prov?['full_name'] as String?;
          _providerDept = prov?['department'] as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appts = Provider.of<AppointmentProvider>(context).appointments;
    final now = DateTime.now();
    final upcoming = appts
        .where((a) =>
            a.scheduledAt.isAfter(now) &&
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.completed)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = upcoming.isNotEmpty ? upcoming.first : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecHead(
            title: 'Upcoming Appointment',
            actionText: 'View all',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          const SizedBox(height: 20),
          if (next == null)
            _empty('No upcoming appointments')
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date tile
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _C.warmCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM')
                            .format(next.scheduledAt)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.warmOrange,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${next.scheduledAt.day}',
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _C.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM yyyy')
                            .format(next.scheduledAt),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _C.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm a').format(next.scheduledAt),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _C.slate,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loading
                            ? 'Loading provider…'
                            : (_providerName ?? 'Provider'),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _C.ink,
                        ),
                      ),
                      if (_providerDept != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _providerDept!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _C.slate,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.softBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          next.type == AppointmentType.inPerson
                              ? 'In-Person'
                              : 'Telehealth',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.lBlue,
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
}

// ── Row 1: Active Medications ──────────────────────────────────────────

class _ActiveMedicationsCard extends StatelessWidget {
  const _ActiveMedicationsCard();

  @override
  Widget build(BuildContext context) {
    final prescriptions =
        Provider.of<PrescriptionProvider>(context).getActivePrescriptions();
    final todayDoses = Provider.of<AdherenceProvider>(context).todayDoses;

    final meds = prescriptions.take(3).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SecHead(
            title: 'Active Medications',
            actionText: 'View all',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MedicationTrackerScreen()),
            ),
          ),
          const SizedBox(height: 16),
          if (meds.isEmpty)
            _empty('No active medications')
          else
            for (int i = 0; i < meds.length; i++)
              _medRow(meds[i], todayDoses, i),
        ],
      ),
    );
  }

  Widget _medRow(
      PrescriptionModel p, List<AdherenceLogModel> todayDoses, int index) {
    final dosesForRx =
        todayDoses.where((d) => d.prescriptionId == p.id).toList();
    final remaining =
        dosesForRx.where((d) => d.status == AdherenceStatus.pending).length;
    final isTaken = dosesForRx.isNotEmpty && remaining == 0;
    final hasDoses = dosesForRx.isNotEmpty;

    // Alternate blue / green icon tiles
    final iconBg = index % 2 == 0 ? _C.softBlue : _C.softGreen;
    final iconColor = index % 2 == 0 ? _C.lBlue : _C.sage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child:
                Icon(Icons.medication_outlined, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.medicationName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                const SizedBox(height: 2),
                Text(
                  '${p.dosage} • ${p.frequency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _C.slate),
                ),
              ],
            ),
          ),
          if (hasDoses)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isTaken ? 'Taken' : '$remaining dose${remaining == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isTaken ? _C.sage : _C.warmOrange,
                  ),
                ),
                Text(
                  isTaken ? 'today' : 'remaining',
                  style: TextStyle(
                    fontSize: 11,
                    color: isTaken ? _C.sage : _C.warmOrange,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Row 2: My Care Team ────────────────────────────────────────────────

class _CareTeamCard extends StatefulWidget {
  const _CareTeamCard({required this.patientId});

  final String patientId;

  @override
  State<_CareTeamCard> createState() => _CareTeamCardState();
}

class _CareTeamCardState extends State<_CareTeamCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ct = Provider.of<CareTeamProvider>(context, listen: false);
      if (ct.members.isEmpty && !ct.isLoading) {
        ct.loadCareTeam(widget.patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CareTeamProvider>(
      builder: (context, ct, _) {
        final members = ct.members;
        final primary = members.firstWhere(
          (m) => m.isPrimary,
          orElse: () => members.isNotEmpty ? members.first : _emptyMember(),
        );
        final hasMembers = members.isNotEmpty;

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecHead(
                title: AppStrings.careTeamTitle('en'),
                actionText: AppStrings.viewAll('en'),
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
                ),
              ),
              const SizedBox(height: 16),
              if (ct.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (!hasMembers)
                _empty(AppStrings.careTeamEmpty('en'))
              else
                _memberRow(primary),
              const SizedBox(height: 12),
              _addMemberButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _memberRow(CareTeamMemberModel m) {
    final initials = _initials(m.providerName);
    final isCustom = m.providerId == widget.patientId;
    final displayName = isCustom
        ? (m.specialtyLabel ?? m.providerName)
        : m.providerName;
    final specialty = m.specialtyLabel ?? m.providerDepartment ?? m.providerRole;

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _C.softBlue,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.canopy,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  if (m.isPrimary) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.softGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Primary',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _C.sage)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${_capitalize(specialty)}${m.providerDepartment != null ? '' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: _C.slate),
              ),
            ],
          ),
        ),
        if (!isCustom)
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.canopy,
              side: const BorderSide(color: _C.line),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Book', style: TextStyle(fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _addMemberButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _C.line,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 16, color: _C.canopy),
              const SizedBox(width: 6),
              Text(
                '+ ${AppStrings.careTeamAdd('en')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.canopy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CareTeamMemberModel _emptyMember() => CareTeamMemberModel(
        id: '',
        patientId: '',
        providerId: '',
        isPrimary: false,
        createdAt: DateTime.now(),
        providerName: '',
        providerRole: 'doctor',
      );

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Row 2: Quick Actions ───────────────────────────────────────────────
//
// Compact vertical action rows — NOT a 6-up grid. Each row has an icon tile,
// a label, and a chevron. Desktop hover subtly lifts the row.

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QaRowData(
        icon: Icons.calendar_today_outlined,
        iconBg: _C.softBlue,
        iconColor: _C.lBlue,
        label: 'Book an appointment',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        ),
      ),
      _QaRowData(
        icon: Icons.medication_outlined,
        iconBg: _C.softGreen,
        iconColor: _C.sage,
        label: 'Add medication',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
        ),
      ),
      _QaRowData(
        icon: Icons.description_outlined,
        iconBg: _C.warmCream,
        iconColor: _C.canopy,
        label: 'View health records',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HealthSummary()),
        ),
      ),
      _QaRowData(
        icon: Icons.receipt_long_outlined,
        iconBg: _C.medBg,
        iconColor: _C.slate,
        label: 'View expenses',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
        ),
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecHead(title: 'Quick Actions'),
          const SizedBox(height: 12),
          for (int i = 0; i < actions.length; i++) ...[
            _QuickActionRow(data: actions[i]),
            if (i < actions.length - 1)
              const Divider(height: 1, thickness: 0.5, color: _C.line),
          ],
        ],
      ),
    );
  }
}

class _QaRowData {
  const _QaRowData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionRow extends StatefulWidget {
  const _QuickActionRow({required this.data});

  final _QaRowData data;

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: _hovering
            ? Matrix4.translationValues(0, -1, 0)
            : Matrix4.identity(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.data.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.data.iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.data.icon,
                        size: 16, color: widget.data.iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.data.label,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: _hovering ? _C.canopy : _C.slate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Row 2: Health Tip ──────────────────────────────────────────────────
//
// Warm illustration tile + rotating tips with pagination dots.
// Auto-advances every 6 seconds; pauses on manual interaction.

class _HealthTipCard extends StatefulWidget {
  const _HealthTipCard();

  @override
  State<_HealthTipCard> createState() => _HealthTipCardState();
}

class _HealthTipCardState extends State<_HealthTipCard> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const _tips = [
    _HealthTipData(
      icon: Icons.medication_outlined,
      title: 'Small steps, big impact',
      body:
          'Taking your medication consistently helps you stay strong and healthy.',
    ),
    _HealthTipData(
      icon: Icons.water_drop_outlined,
      title: 'Stay hydrated',
      body: 'Drinking enough water each day supports your overall wellbeing.',
    ),
    _HealthTipData(
      icon: Icons.event_available,
      title: 'Keep your appointments',
      body: 'Regular check-ups help your care team catch issues early.',
    ),
    _HealthTipData(
      icon: Icons.share_outlined,
      title: 'Share your records',
      body: 'Use your MediLink QR to securely share your health information.',
    ),
    _HealthTipData(
      icon: Icons.favorite_outline,
      title: 'Preventive care matters',
      body: 'Small lifestyle choices today protect your health for tomorrow.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _tips.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onManualPage(int page) {
    setState(() => _currentPage = page);
    _timer?.cancel();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecHead(title: 'Health Tip'),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tips.length,
              onPageChanged: _onManualPage,
              itemBuilder: (context, index) {
                final tip = _tips[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warm illustration tile
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _C.warmCream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tip.icon, size: 36, color: _C.warmOrange),
                    ),
                    const SizedBox(height: 14),
                    Text(tip.title,
                        style: GoogleFonts.fraunces(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(tip.body,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: _C.slate,
                              height: 1.5)),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _tips.length; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage ? _C.canopy : _C.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i < _tips.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthTipData {
  const _HealthTipData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

// ── Shared widgets ─────────────────────────────────────────────────────

class _TrustBanner extends StatelessWidget {
  const _TrustBanner({this.lang = 'en'});
  final String lang;

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
                Text(AppStrings.trustTitle(lang),
                    style: GoogleFonts.fraunces(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  AppStrings.trustBody(lang),
                  style: const TextStyle(fontSize: 13.5, color: _C.slate, height: 1.5),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showPrivacyDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: _C.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _C.line),
                    ),
                    child: Text(
                      AppStrings.trustLearn(lang),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.canopy,
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
        title: Text(AppStrings.privacyTitle(lang)),
        content: Text(AppStrings.privacyBody(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.privacyGotIt(lang),
                style: const TextStyle(
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
            style: GoogleFonts.fraunces(
                fontSize: 16, fontWeight: FontWeight.w700, color: _C.ink)),
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
  const _AllergyRow({required this.allergies, this.lang = 'en'});

  final List<String> allergies;
  final String lang;

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
                  Flexible(
                    child: Text(
                      '${AppStrings.allergiesLabel(lang)}: $a',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.danger),
                    ),
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
  const _MediLinkCard({required this.fullName, required this.medilinkId, this.lang = 'en'});

  final String fullName;
  final String medilinkId;
  final String lang;

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
                  _chip(AppStrings.registeredPatient(lang)),
                  const SizedBox(width: 8),
                  _chip(AppStrings.nshaLinked(lang)),
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

/// First-run checklist — the single focus of the simplified first-run
/// dashboard. Pending steps get a prominent navy pill button; finished
/// steps are struck through with a filled check.
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({
    required this.hasAppointments,
    required this.hasMedications,
    required this.profileHasStarted,
    required this.lang,
  });

  final bool hasAppointments;
  final bool hasMedications;
  final bool profileHasStarted;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ChecklistData(
        label: AppStrings.checklistProfile(lang),
        sub: AppStrings.checklistProfileSub(lang),
        done: profileHasStarted,
        actionText: AppStrings.btnComplete(lang),
        onTap: () => context.go('/onboarding'),
      ),
      _ChecklistData(
        label: AppStrings.checklistAppointment(lang),
        sub: AppStrings.checklistAppointmentSub(lang),
        done: hasAppointments,
        actionText: AppStrings.btnBookNow(lang),
        onTap: () => _push(context, const AppointmentsScreen()),
      ),
      _ChecklistData(
        label: AppStrings.checklistMedication(lang),
        sub: AppStrings.checklistMedicationSub(lang),
        done: hasMedications,
        actionText: AppStrings.btnAddNow(lang),
        onTap: () => _push(context, const MedicationTrackerScreen()),
      ),
      _ChecklistData(
        label: AppStrings.checklistSharing(lang),
        sub: AppStrings.checklistSharingSub(lang),
        done: false,
        actionText: AppStrings.btnSetUp(lang),
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
              Text(AppStrings.checklistTitle(lang),
                  style: GoogleFonts.fraunces(
                      fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(AppStrings.checklistSub(lang),
                  style: const TextStyle(fontSize: 14.5, color: _C.slate)),
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
                    AppStrings.ofDone('$doneCount', '${items.length}', lang),
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
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: _C.canopy,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
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
