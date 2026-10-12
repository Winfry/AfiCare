import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/active_patient.dart';
import '../../models/adherence_model.dart';
import '../../models/appointment_model.dart';
import '../../models/lab_model.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../services/tts_service.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/app_strings.dart';
import 'appointments_screen.dart';
import 'medication_tracker_screen.dart';
import 'widgets/patient_ui.dart';

/// Shell tabs Home can switch to, so links stay inside the shell (and
/// keep the sidebar) instead of pushing a bare page on top of it.
const _tabVisits = 1, _tabMeds = 2, _tabMessages = 3;

/// Patient "Today" — built against the approved "AfiCare Today" design.
///
/// Two states. Until the account holder's essentials are saved (date of
/// birth and an emergency contact — the two things signup insists on) a
/// new patient sees a setup checklist. Once they are saved, the patient
/// is an existing user and gets the everyday Today page; the checklist
/// never comes back, whatever else is still empty.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key, this.loadFailed = false, this.onRetry, this.onOpenTab});

  /// Set by the shell when the data behind this summary didn't load. The
  /// summary is then suppressed: an empty dashboard after a failed load
  /// reads as "you have no appointments and nothing to take", which is a
  /// dangerous thing to tell someone who does.
  final bool loadFailed;
  final VoidCallback? onRetry;

  /// Switches the shell to one of its tabs.
  final ValueChanged<int>? onOpenTab;

  /// The essentials signup insists on. Blood type and allergies are
  /// optional there — plenty of people have no allergies — so requiring
  /// them would leave someone who finished signup stuck on the checklist.
  static bool profileIsComplete(PatientProfileProvider p) {
    final profile = p.profile;
    return profile != null &&
        profile.dateOfBirth != null &&
        (profile.emergencyContactName?.trim().isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesProvider>();
    final profileProvider = context.watch<PatientProfileProvider>();

    // Whose space this is. Greeting and allergies follow the selected
    // profile, never the account holder's when a child is on screen.
    final subject = ActivePatient.of(context);
    final lang = prefs.prefs?.language ?? 'en';

    // The checklist is about the account holder's own profile, so it is
    // never shown over a dependant's record. While the profile is still
    // loading, wait rather than flash the checklist at an existing user.
    final stillLoading = profileProvider.profile == null && profileProvider.isLoading;
    final needsSetup = !subject.isDependent && !stillLoading && !profileIsComplete(profileProvider);

    final ttsEnabled = prefs.prefs?.textToSpeech ?? false;

    void openTab(int tab) {
      if (onOpenTab != null) {
        onOpenTab!(tab);
      } else if (tab == _tabVisits) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen()));
      } else if (tab == _tabMeds) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()));
      } else {
        context.go('/patient/messages');
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayHero(
            subject: subject,
            lang: lang,
            isNew: needsSetup,
            ttsEnabled: ttsEnabled,
            showDoses: !loadFailed && !needsSetup,
            onBook: () => openTab(_tabVisits),
            onRecords: () => context.go('/patient/records'),
            onPlan: () => openTab(_tabMeds),
          ),
          // Allergies are safety information, so they sit directly under
          // the hero for every profile, new or not.
          if (subject.allergies != null && subject.allergies!.isNotEmpty) ...[
            const SizedBox(height: 15),
            _AllergyNote(
              allergies: subject.allergies!,
              isDependent: subject.isDependent,
              onReview: () => context.go('/patient/records'),
            ),
          ],
          const SizedBox(height: 4),
          if (loadFailed)
            Padding(
              padding: const EdgeInsets.only(top: 25),
              child: PLoadError(what: 'your health summary', onRetry: onRetry ?? () {}),
            )
          else if (stillLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (needsSetup)
            Padding(
              padding: const EdgeInsets.only(top: 25),
              child: _FirstRunBody(
                lang: lang,
                profileHasStarted: profileIsComplete(profileProvider),
              ),
            )
          else
            _TodayBody(openTab: openTab),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Hero — `.welcome`
// ═══════════════════════════════════════════════════════════════════════

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.subject,
    required this.lang,
    required this.isNew,
    required this.ttsEnabled,
    required this.showDoses,
    required this.onBook,
    required this.onRecords,
    required this.onPlan,
  });

  final ActivePatient subject;
  final String lang;
  final bool isNew;
  final bool ttsEnabled;
  final bool showDoses;
  final VoidCallback onBook;
  final VoidCallback onRecords;
  final VoidCallback onPlan;

  String _greeting() {
    final h = DateTime.now().hour;
    if (lang == 'sw') {
      final part = h < 12 ? 'asubuhi' : (h < 17 ? 'mchana' : 'jioni');
      return 'Habari za $part, ${subject.firstName}';
    }
    final part = h < 12 ? 'morning' : (h < 17 ? 'afternoon' : 'evening');
    return 'Good $part, ${subject.firstName}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PT.isMobile(context);
    final weekday = DateFormat('EEEE', lang == 'sw' ? 'sw' : 'en').format(DateTime.now()).toUpperCase();
    final dateLine = subject.isDependent ? "$weekday · ${subject.firstName.toUpperCase()}'S DAY" : 'YOUR $weekday, AT A GLANCE';
    final title = subject.isDependent ? "${subject.firstName}'s day" : _greeting();
    final body = subject.isDependent
        ? "Everything below is ${subject.firstName}'s, kept separate from your own."
        : isNew
            ? "Welcome to AfiCare. Let's get the essentials in place — it only takes a few minutes."
            : 'One day at a time. Here’s what may need your attention today.';

    final actions = Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        _HeroButton('＋  Book a visit', primary: true, onTap: onBook),
        _HeroButton('View ${subject.isDependent ? 'records' : 'my records'}  ↗', onTap: onRecords),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1, -0.6),
          end: Alignment(1, 0.6),
          colors: [Color(0xFF1C4259), Color(0xFF327A9B)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: PT.heroShadow,
      ),
      child: Stack(
        children: [
          // The design's faint concentric rings, top right.
          Positioned(
            right: -72,
            top: -125,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x19FFFFFF)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08FFFFFF), spreadRadius: 28),
                  BoxShadow(color: Color(0x06FFFFFF), spreadRadius: 58),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 20 : 30, isMobile ? 23 : 29, isMobile ? 20 : 30, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLine,
                              style: PT.label().copyWith(
                                  fontSize: 12, letterSpacing: .5, color: const Color(0xFFB8CFD9))),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: title),
                              const TextSpan(text: '.', style: TextStyle(color: Color(0xFFF5D99F))),
                            ]),
                            style: PT.h2().copyWith(fontSize: isMobile ? 29 : 37),
                          ),
                          const SizedBox(height: 8),
                          Text(body, style: PT.body().copyWith(color: const Color(0xFFD1E0E7), fontSize: 15)),
                        ],
                      ),
                    ),
                    if (ttsEnabled)
                      IconButton(
                        onPressed: () => tts.speak('$title. $body'),
                        tooltip: 'Listen',
                        icon: const Icon(Icons.volume_up_rounded, size: 20),
                        color: Colors.white70,
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.15)),
                      ),
                    if (!isMobile) ...[const SizedBox(width: 20), actions],
                  ],
                ),
                if (isMobile) ...[const SizedBox(height: 18), actions],
                if (showDoses) _TodayLine(onPlan: onPlan),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.todayline` — the one-line summary of today's doses.
class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.onPlan});

  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final adherence = context.watch<AdherenceProvider>();
    final total = adherence.todayDoses.length;
    final left = adherence.todayRemaining;

    final String status;
    final String note;
    if (total == 0) {
      status = 'Nothing to take today';
      note = 'Medicines you add will show up here.';
    } else if (left == 0) {
      status = 'All of today’s doses are done';
      note = 'Nicely done. Rest easy.';
    } else {
      status = 'You have $left dose${left == 1 ? '' : 's'} left today';
      note = 'You’re making your way through the day.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.only(top: 17),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x26FFFFFF)))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 13,
        runSpacing: 10,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF5D99F),
              boxShadow: [BoxShadow(color: Color(0x20F5D99F), spreadRadius: 6)],
            ),
          ),
          Text(status, style: PT.body().copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(note, style: PT.body().copyWith(color: const Color(0xFFC8DBE2), fontSize: 13)),
          _HeroButton('See today’s plan', onTap: onPlan),
        ],
      ),
    );
  }
}

/// `.btn.primary` (gold) and `.btn.quiet` (glass) on the blue hero.
class _HeroButton extends StatelessWidget {
  const _HeroButton(this.label, {this.primary = false, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? const Color(0xFFF5D99F) : const Color(0x16FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PT.rButton),
        side: BorderSide(color: primary ? const Color(0xFFF5D99F) : const Color(0x45FFFFFF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PT.rButton),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Text(label,
              style: PT.button().copyWith(color: primary ? const Color(0xFF283F48) : Colors.white)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Allergy note — `.allergy`
// ═══════════════════════════════════════════════════════════════════════

class _AllergyNote extends StatelessWidget {
  const _AllergyNote({required this.allergies, required this.isDependent, required this.onReview});

  final List<String> allergies;
  final bool isDependent;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        border: Border.all(color: PT.viewingBorder),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF9E6BF), borderRadius: BorderRadius.circular(11)),
            child: Text('!', style: PT.rowTitle().copyWith(color: const Color(0xFF8A6A2C))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A quick note for your care team', style: PT.rowTitle().copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'Allergies on file: ${allergies.join(', ')}. '
                  'Please check ${isDependent ? 'they are' : 'these are'} still correct.',
                  style: PT.rowSub().copyWith(fontSize: 12, color: const Color(0xFF866B3C)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TextLink('Review', onTap: onReview),
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(label, style: PT.button().copyWith(color: PT.teal, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// `.sectionhead`: Fraunces heading with a link or note on the right.
class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, {this.link, this.onLink, this.note});

  final String title;
  final String? link;
  final VoidCallback? onLink;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 29, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: PT.section())),
          if (link != null && onLink != null) _TextLink(link!, onTap: onLink!),
          if (note != null) Text(note!, style: PT.label()),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The everyday page
// ═══════════════════════════════════════════════════════════════════════

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.openTab});

  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final isMobile = PT.isMobile(context);
    final meds = _MedsTodayCard(onPlan: () => openTab(_tabMeds));
    final visit = _NextVisitCard(
      onView: () => openTab(_tabVisits),
      onMessage: () => openTab(_tabMessages),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('Let’s take today gently',
            link: 'Your medication plan ↗', onLink: () => openTab(_tabMeds)),
        if (isMobile)
          Column(children: [meds, const SizedBox(height: 16), visit])
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 112, child: meds),
                const SizedBox(width: 16),
                Expanded(flex: 88, child: visit),
              ],
            ),
          ),
        const _SectionHead('What would help right now?', note: 'Choose what you need'),
        _HelpActions(openTab: openTab),
        _SectionHead('A little recent activity',
            link: 'See health records ↗', onLink: () => context.go('/patient/records')),
        const _ActivityCard(),
      ],
    );
  }
}

/// The design's white card.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: PT.white,
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(PT.rCard),
        boxShadow: PT.cardShadow,
      ),
      child: child,
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon(this.icon, {this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: PT.calloutBg, borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(icon, size: size * .47, color: PT.teal),
    );
  }
}

class _CardHead extends StatelessWidget {
  const _CardHead({required this.title, required this.sub, required this.icon});

  final String title;
  final String sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PT.h3().copyWith(fontSize: 17)),
              const SizedBox(height: 3),
              Text(sub, style: PT.sub().copyWith(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _SoftIcon(icon),
      ],
    );
  }
}

/// "Today's medicines": count, progress and a tick-off list.
class _MedsTodayCard extends StatelessWidget {
  const _MedsTodayCard({required this.onPlan});

  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final adherence = context.watch<AdherenceProvider>();
    final doses = [...adherence.todayDoses]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final taken = doses.where((d) => d.status == AdherenceStatus.taken).length;
    final total = doses.length;

    final String encouragement;
    if (total == 0) {
      encouragement = 'No medicines scheduled for today.';
    } else if (taken == 0) {
      encouragement = 'Nothing recorded yet. Start whenever you’re ready.';
    } else if (taken == total) {
      encouragement = 'Every dose recorded today. Well done.';
    } else {
      encouragement = '$taken dose${taken == 1 ? '' : 's'} recorded. You can pick up where you are.';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHead(
            title: 'Today’s medicines',
            sub: 'Small steps count. Tick one off when you’re ready.',
            icon: Icons.medication_outlined,
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: total == 0 ? '—' : '$taken'),
              if (total > 0)
                TextSpan(text: ' / $total', style: PT.label().copyWith(fontSize: 19)),
            ]),
            style: PT.serif(fontSize: 38, color: PT.navy, height: 1),
          ),
          const SizedBox(height: 14),
          PProgress(total == 0 ? 0 : taken / total),
          const SizedBox(height: 9),
          Text(encouragement, style: PT.label()),
          if (total == 0) ...[
            const SizedBox(height: 16),
            PButton('Add a medicine', kind: PButtonKind.alt, dense: true, onPressed: onPlan),
          ] else ...[
            const SizedBox(height: 16),
            for (final d in doses.take(4)) _DoseRow(dose: d),
            if (doses.length > 4) _TextLink('See all ${doses.length} doses', onTap: onPlan),
          ],
        ],
      ),
    );
  }
}

/// `.dose`.
class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose});

  final AdherenceLogModel dose;

  @override
  Widget build(BuildContext context) {
    final done = dose.status == AdherenceStatus.taken;
    final skipped = dose.status == AdherenceStatus.skipped;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF6F9FA) : const Color(0xFFFAFBFC),
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(PT.rRow),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(DateFormat('h:mm a').format(dose.scheduledTime).toLowerCase(),
                style: PT.label().copyWith(fontSize: 11)),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done ? PT.calloutBg : const Color(0xFFEEEAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(done ? Icons.check_rounded : Icons.medication_rounded, size: 17, color: PT.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dose.medicationName ?? 'Medicine',
                    style: PT.rowTitle(), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (dose.dosage != null)
                  Text(dose.dosage!, style: PT.rowSub().copyWith(fontSize: 12), maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done || skipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: PT.calloutBg, borderRadius: BorderRadius.circular(PT.rPill)),
              child: Text(done ? 'Taken' : 'Skipped',
                  style: PT.badge().copyWith(fontSize: 12, color: const Color(0xFF39667A))),
            )
          else
            OutlinedButton(
              onPressed: () async {
                final ok = await context.read<AdherenceProvider>().markStatus(dose.id, AdherenceStatus.taken);
                if (!ok && context.mounted) pToast(context, 'Couldn’t record that dose. Please try again.');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: PT.teal,
                side: const BorderSide(color: Color(0xFFB9CBD7)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: PT.badge().copyWith(fontSize: 12),
              ),
              child: const Text('Mark taken'),
            ),
        ],
      ),
    );
  }
}

/// "Your next visit". The appointment row stores only a provider id, so
/// the display name is looked up separately.
class _NextVisitCard extends StatefulWidget {
  const _NextVisitCard({required this.onView, required this.onMessage});

  final VoidCallback onView;
  final VoidCallback onMessage;

  @override
  State<_NextVisitCard> createState() => _NextVisitCardState();
}

class _NextVisitCardState extends State<_NextVisitCard> {
  String? _providerName;
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
          .select('full_name')
          .eq('id', providerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _providerName = row?['full_name'] as String?);
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

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHead(
            title: 'Your next visit',
            sub: 'It’s okay to plan ahead.',
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 15),
          if (next == null)
            Text('Nothing booked yet. Book a visit whenever you need care.', style: PT.sub().copyWith(fontSize: 13))
          else
            Row(
              children: [
                Container(
                  width: 59,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(color: PT.calloutWarnBg, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Text('${next.scheduledAt.day}',
                          style: PT.serif(fontSize: 27, color: const Color(0xFF70501E), height: 1)),
                      Text(DateFormat('MMM').format(next.scheduledAt).toUpperCase(),
                          style: PT.badge().copyWith(
                              fontSize: 10, letterSpacing: 1, color: const Color(0xFF8C6A31))),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_providerName ?? 'Your provider', style: PT.rowTitle()),
                      Text(next.type == AppointmentType.inPerson ? 'In person' : 'Telehealth',
                          style: PT.rowSub()),
                      Text(DateFormat('EEEE, h:mm a').format(next.scheduledAt), style: PT.rowSub()),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PButton(next == null ? 'Book a visit' : 'View appointment', dense: true, onPressed: widget.onView),
              PButton('Message the team', kind: PButtonKind.alt, dense: true, onPressed: widget.onMessage),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 15),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
            child: Row(
              children: [
                const _SoftIcon(Icons.wb_sunny_outlined, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Need to change plans?', style: PT.rowTitle().copyWith(fontSize: 13)),
                      Text('You can reschedule or ask for help.', style: PT.label()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "What would help right now?" — four `.action` tiles.
class _HelpActions extends StatelessWidget {
  const _HelpActions({required this.openTab});

  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ActionTile(Icons.add_rounded, 'Book a visit', 'Find a time that works', () => openTab(_tabVisits)),
      _ActionTile(Icons.description_outlined, 'Understand my results', 'Records, labs and visits',
          () => context.go('/patient/records')),
      _ActionTile(Icons.favorite_border_rounded, 'Talk to my care team', 'Ask a question',
          () => openTab(_tabMessages)),
      _ActionTile(Icons.wb_sunny_outlined, 'Look after my medicines', 'Reminders and your plan',
          () => openTab(_tabMeds)),
    ];
    final cols = PT.isTablet(context) ? 2 : 4;
    return LayoutBuilder(builder: (context, c) {
      final gap = PT.isMobile(context) ? 8.0 : 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.icon, this.title, this.sub, this.onTap);

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PT.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: PT.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(PT.isMobile(context) ? 13 : 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoftIcon(icon),
              const SizedBox(height: 13),
              Text(title, style: PT.rowTitle()),
              const SizedBox(height: 3),
              Text(sub, style: PT.label()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "A little recent activity", derived from data the shell has already
/// loaded (labs, appointments, prescriptions) — no extra queries.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    final labs = context.watch<LabProvider>().orders;
    final appts = context.watch<AppointmentProvider>().appointments;
    final scripts = context.watch<PrescriptionProvider>().prescriptions;

    final events = <_Activity>[
      for (final l in labs)
        if (l.status == LabOrderStatus.completed)
          _Activity(Icons.check_rounded, 'Your ${l.testName} result is ready',
              'Open your results when you’re ready.', l.result?.resultedAt ?? l.orderedAt),
      for (final a in appts)
        if (a.status == AppointmentStatus.confirmed)
          _Activity(Icons.calendar_today_outlined, 'Your appointment is confirmed',
              DateFormat('EEEE, d MMMM \'at\' h:mm a').format(a.scheduledAt), a.scheduledAt),
      for (final p in scripts)
        _Activity(Icons.medication_outlined, 'Your medication list was updated', p.medicationName, p.issuedAt),
    ]..sort((a, b) => b.at.compareTo(a.at));
    final recent = events.take(3).toList();

    return _Card(
      child: recent.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Nothing yet. Results, confirmed visits and medication changes will appear here.',
                style: PT.sub().copyWith(fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < recent.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: i == recent.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: PT.line)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(color: PT.searchFill, borderRadius: BorderRadius.circular(12)),
                          child: Icon(recent[i].icon, size: 17, color: PT.teal),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(recent[i].title, style: PT.rowTitle().copyWith(fontSize: 13.5)),
                              Text(recent[i].sub, style: PT.label()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_when(recent[i].at), style: PT.label().copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return DateFormat('EEE').format(t);
    return DateFormat('d MMM').format(t);
  }
}

class _Activity {
  _Activity(this.icon, this.title, this.sub, this.at);

  final IconData icon;
  final String title;
  final String sub;
  final DateTime at;
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
