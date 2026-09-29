import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/appointment_model.dart';
import '../../models/lab_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../services/tts_service.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/app_strings.dart';
import 'appointments_screen.dart';
import 'health_summary.dart';
import 'medication_tracker_screen.dart';
import 'widgets/patient_ui.dart';

/// Patient Home — the daily summary, rebuilt on the shared patient
/// primitives against `docs/patient_prototype.html`.
///
/// Two states, as before: an onboarding checklist until the profile has
/// the essentials, then the full dashboard. Sections that now have their
/// own destination in the redesigned sidebar (Care Team, MediLink,
/// PWD/Disability) are no longer duplicated here — Home is deliberately
/// a summary, not a second medical record.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<PreferencesProvider>();
    final profile = context.watch<PatientProfileProvider>().profile;

    final user = auth.currentUser;
    final lang = prefs.prefs?.language ?? 'en';
    final firstName = (user?.fullName ?? 'there').trim().split(' ').first;
    final allergies = profile?.allergies ?? const <String>[];

    final dateStr = DateFormat('EEEE · d MMMM yyyy', lang == 'sw' ? 'sw' : 'en')
        .format(DateTime.now());

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

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: PScreen(
        eyebrow: 'Patient',
        title: 'Home',
        subtitle: 'Your daily health space',
        children: [
          PHero(
            chip: dateStr,
            title: AppStrings.greeting(firstName, lang),
            body: lang == 'sw'
                ? 'Karibu tena! Huu hapa ni muhtasari wa afya yako.'
                : "Here's what's happening with your health today. Your important care information stays in one place.",
            trailing: listenText == null
                ? null
                : IconButton(
                    onPressed: () => tts.speak(listenText),
                    tooltip: 'Listen',
                    icon: const Icon(Icons.volume_up_rounded),
                    color: Colors.white70,
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
            action: PButton(
              'Book an appointment',
              kind: PButtonKind.alt,
              onPressed: () => _push(context, const AppointmentsScreen()),
            ),
          ),
          // Kept even though the spec's Home omits it: allergies are
          // safety information and dropping them would be a regression.
          if (allergies.isNotEmpty) ...[
            _AllergyRow(allergies: allergies, lang: lang),
            const SizedBox(height: 16),
          ],
          if (needsOnboarding)
            _FirstRunBody(lang: lang, profileHasStarted: profileHasStarted)
          else
            const _ReturningBody(),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Returning dashboard
// ═══════════════════════════════════════════════════════════════════════

class _ReturningBody extends StatelessWidget {
  const _ReturningBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PGrid(
          columns: 3,
          children: const [
            _AdherenceMetric(),
            _NextAppointmentMetric(),
            _ActiveMedicationsMetric(),
          ],
        ),
        const SizedBox(height: 16),
        PGrid(
          columns: 2,
          children: const [
            _QuickActionsCard(),
            _RecentActivityCard(),
          ],
        ),
      ],
    );
  }
}

class _AdherenceMetric extends StatelessWidget {
  const _AdherenceMetric();

  @override
  Widget build(BuildContext context) {
    final adherence = context.watch<AdherenceProvider>();
    final hasDoses = adherence.todayDoses.isNotEmpty;
    final remaining = adherence.todayRemaining;

    return PMetric(
      label: 'Medication adherence',
      value: hasDoses ? '${adherence.todayScore}%' : '--',
      note: !hasDoses
          ? 'No medications scheduled today'
          : remaining > 0
              ? '$remaining dose${remaining == 1 ? '' : 's'} remaining today'
              : 'All doses taken today',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
      ),
    );
  }
}

/// The appointment record stores only a provider id, so the display name
/// is resolved separately here (same approach the previous Home used).
class _NextAppointmentMetric extends StatefulWidget {
  const _NextAppointmentMetric();

  @override
  State<_NextAppointmentMetric> createState() => _NextAppointmentMetricState();
}

class _NextAppointmentMetricState extends State<_NextAppointmentMetric> {
  String? _providerName;
  String? _providerDept;
  String? _loadedForId;

  AppointmentModel? _next(BuildContext context) {
    final appts = context.watch<AppointmentProvider>().appointments;
    final now = DateTime.now();
    final upcoming = appts
        .where((a) =>
            a.scheduledAt.isAfter(now) &&
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.completed)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _loadProvider(String providerId) async {
    _loadedForId = providerId;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('full_name, department')
          .eq('id', providerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _providerName = row?['full_name'] as String?;
        _providerDept = row?['department'] as String?;
      });
    } catch (e) {
      debugPrint('patient_home_screen: loading provider name failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _next(context);

    if (next != null && next.providerId != _loadedForId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProvider(next.providerId);
      });
    }

    if (next == null) {
      return PMetric(
        label: 'Next appointment',
        value: 'None',
        valueFontSize: 20,
        note: 'Book when you need care',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        ),
      );
    }

    final typeLabel = next.type == AppointmentType.inPerson ? 'In person' : 'Telehealth';

    return PMetric(
      label: 'Next appointment',
      value: DateFormat('d MMM · HH:mm').format(next.scheduledAt),
      valueFontSize: 20,
      note: '${_providerName ?? 'Provider'} · $typeLabel',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
      ),
    );
  }
}

class _ActiveMedicationsMetric extends StatelessWidget {
  const _ActiveMedicationsMetric();

  @override
  Widget build(BuildContext context) {
    final active = context.watch<PrescriptionProvider>().getActivePrescriptions();

    return PMetric(
      label: 'Active medications',
      value: '${active.length}',
      note: active.isEmpty ? 'Nothing active right now' : "View today's doses →",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Quick actions'),
          PQuickActions([
            PQuickAction(
              emoji: '📅',
              label: 'Book appointment',
              note: 'Find a provider or service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
              ),
            ),
            PQuickAction(
              emoji: '💊',
              label: 'Add medication',
              note: 'Keep your list current',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
              ),
            ),
            PQuickAction(
              emoji: '📋',
              label: 'View records',
              note: 'Results, visits & history',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthSummary()),
              ),
            ),
            PQuickAction(
              emoji: '💬',
              label: 'Message care team',
              note: 'Continue a conversation',
              onTap: () => context.go('/patient/messages'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Recent activity, derived client-side from data the shell has already
/// loaded (labs, appointments, prescriptions) — no extra queries.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    final labs = context.watch<LabProvider>().orders;
    final appts = context.watch<AppointmentProvider>().appointments;
    final scripts = context.watch<PrescriptionProvider>().prescriptions;

    final events = <_Activity>[];

    for (final l in labs) {
      if (l.status == LabOrderStatus.completed) {
        events.add(_Activity(
          emoji: '🧪',
          title: 'Your lab result is ready',
          subtitle: l.testName,
          at: l.result?.resultedAt ?? l.orderedAt,
          badge: 'Ready',
          tone: PTone.ok,
        ));
      }
    }

    for (final a in appts) {
      if (a.status == AppointmentStatus.confirmed) {
        events.add(_Activity(
          emoji: '📅',
          title: 'Appointment confirmed',
          subtitle: DateFormat('d MMM · HH:mm').format(a.scheduledAt),
          at: a.scheduledAt,
          badge: 'Confirmed',
          tone: PTone.blue,
        ));
      }
    }

    for (final p in scripts) {
      events.add(_Activity(
        emoji: '💊',
        title: 'Prescription updated',
        subtitle: p.medicationName,
        at: p.issuedAt,
      ));
    }

    events.sort((a, b) => b.at.compareTo(a.at));
    final recent = events.take(3).toList();

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            'Recent activity',
            trailing: PButton(
              'View all',
              kind: PButtonKind.alt,
              dense: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthSummary()),
              ),
            ),
          ),
          if (recent.isEmpty)
            const PEmpty(
              emoji: '🗓️',
              title: 'Nothing yet',
              body: 'Results, confirmed appointments and prescription changes will show up here.',
            )
          else
            for (final e in recent)
              PRow(
                leadingEmoji: e.emoji,
                title: e.title,
                subtitle: '${e.subtitle} · ${_relative(e.at)}',
                trailing: [if (e.badge != null) PBadge(e.badge!, tone: e.tone)],
              ),
        ],
      ),
    );
  }

  static String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    final ago = !diff.isNegative;
    final d = diff.abs();
    final String label;
    if (d.inMinutes < 60) {
      label = '${d.inMinutes}m';
    } else if (d.inHours < 24) {
      label = '${d.inHours}h';
    } else {
      label = '${d.inDays}d';
    }
    return ago ? '$label ago' : 'in $label';
  }
}

class _Activity {
  _Activity({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.at,
    this.badge,
    this.tone = PTone.gray,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final DateTime at;
  final String? badge;
  final PTone tone;
}

// ═══════════════════════════════════════════════════════════════════════
// First-run dashboard
// ═══════════════════════════════════════════════════════════════════════

class _FirstRunBody extends StatelessWidget {
  const _FirstRunBody({required this.lang, required this.profileHasStarted});

  final String lang;
  final bool profileHasStarted;

  @override
  Widget build(BuildContext context) {
    final hasAppointments = context.watch<AppointmentProvider>().appointments.isNotEmpty;
    final adherence = context.watch<AdherenceProvider>();
    final prescriptions = context.watch<PrescriptionProvider>();
    final hasMedications =
        adherence.todayDoses.isNotEmpty || prescriptions.getActivePrescriptions().isNotEmpty;

    final steps = <_Step>[
      _Step(
        title: AppStrings.checklistProfile(lang),
        subtitle: AppStrings.checklistProfileSub(lang),
        done: profileHasStarted,
        actionLabel: AppStrings.btnComplete(lang),
        onTap: () => context.go('/onboarding'),
      ),
      _Step(
        title: AppStrings.checklistAppointment(lang),
        subtitle: AppStrings.checklistAppointmentSub(lang),
        done: hasAppointments,
        actionLabel: AppStrings.btnBookNow(lang),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        ),
      ),
      _Step(
        title: AppStrings.checklistMedication(lang),
        subtitle: AppStrings.checklistMedicationSub(lang),
        done: hasMedications,
        actionLabel: AppStrings.btnAddNow(lang),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
        ),
      ),
      _Step(
        title: AppStrings.checklistSharing(lang),
        subtitle: AppStrings.checklistSharingSub(lang),
        done: false,
        actionLabel: AppStrings.btnSetUp(lang),
        onTap: () => context.go('/patient/share'),
      ),
    ];

    final doneCount = steps.where((s) => s.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.checklistTitle(lang), style: PT.h3().copyWith(fontSize: 21)),
              const SizedBox(height: 6),
              Text(AppStrings.checklistSub(lang), style: PT.sub()),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: PProgress(doneCount / steps.length)),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.ofDone('$doneCount', '${steps.length}', lang),
                    style: PT.rowSub().copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < steps.length; i++)
                PStepRow(
                  number: i + 1,
                  title: steps[i].title,
                  subtitle: steps[i].subtitle,
                  done: steps[i].done,
                  action: PButton(
                    steps[i].actionLabel,
                    dense: true,
                    onPressed: steps[i].onTap,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCallout(
          title: AppStrings.trustTitle(lang),
          body: AppStrings.trustBody(lang),
          trailing: PButton(
            AppStrings.trustLearn(lang),
            kind: PButtonKind.alt,
            dense: true,
            onPressed: () => _showPrivacy(context, lang),
          ),
        ),
      ],
    );
  }

  void _showPrivacy(BuildContext context, String lang) {
    showPModal<void>(
      context: context,
      title: AppStrings.privacyTitle(lang),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.privacyBody(lang), style: PT.body()),
          const SizedBox(height: 18),
          PButton(
            AppStrings.privacyGotIt(lang),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final String actionLabel;
  final VoidCallback onTap;
}

// ═══════════════════════════════════════════════════════════════════════
// Allergies
// ═══════════════════════════════════════════════════════════════════════

class _AllergyRow extends StatelessWidget {
  const _AllergyRow({required this.allergies, required this.lang});

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
              color: PT.badgeRedBg,
              borderRadius: BorderRadius.circular(PT.rPill),
              border: Border.all(color: PT.danger.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 13, color: PT.badgeRedFg),
                const SizedBox(width: 6),
                Text(
                  '${AppStrings.allergiesLabel(lang)}: $a',
                  style: PT.badge().copyWith(fontSize: 12, color: PT.badgeRedFg),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
