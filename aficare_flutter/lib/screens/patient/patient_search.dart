import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/appointment_model.dart';
import '../../models/care_team_member_model.dart';
import '../../models/prescription_model.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/dose_frequency.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// What the patient's search finds: the app's pages, and her own
/// medicines, appointments and care team (for the profile being viewed).
///
/// It searches what is already on her phone, as she types. It used to
/// search every account's name in the database, which showed staff she
/// had never met and opened nothing when tapped.
enum PatientSearchKind { page, medicine, appointment, careTeam }

class PatientSearchHit {
  const PatientSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final PatientSearchKind kind;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Where tapping it goes.
  final String route;
}

class PatientSearch {
  PatientSearch._();

  /// Other words people use for each page, so "pills", "BP" or
  /// "pregnancy" find the right one.
  static const pageWords = <String, String>{
    PatientRoutes.today: 'home today dashboard summary start',
    PatientRoutes.appointments: 'appointment appointments visit visits book booking clinic doctor schedule calendar',
    PatientRoutes.medications: 'medicine medicines medication pills tablets drugs prescription prescriptions dose doses tracker taken',
    PatientRoutes.records: 'records record history results summary vitals blood pressure bp temperature weight readings',
    PatientRoutes.messages: 'message messages chat inbox write doctor nurse contact',
    PatientRoutes.more: 'more everything all pages',
    '/patient/labs': 'lab labs laboratory test tests results blood urine',
    '/patient/adherence': 'adherence missed doses taken history log',
    '/patient/care-team': 'care team doctor doctors nurse nurses clinician my doctor',
    '/patient/referrals': 'referral referrals referred hospital specialist transfer',
    '/patient/share': 'share sharing code access doctor records qr',
    '/patient/emergency': 'emergency sos urgent help ambulance 999 112 crisis',
    '/patient/mental-health': 'mental health wellbeing mood depression anxiety stress phq gad feelings',
    '/patient/vaccinations': 'vaccine vaccines vaccination vaccinations immunisation immunization jab jabs injection',
    '/patient/medication-reminders': 'reminder reminders alarm alarms alert notification medicine time',
    '/patient/drug-interactions': 'medicine checker interaction interactions mix safe together drug',
    '/patient/anc': 'maternal pregnancy pregnant antenatal anc baby expecting due date',
    PatientRoutes.womensHealth: 'women period periods cycle menstrual screening pap breast contraception fertility',
    '/patient/mens-health': 'men prostate heart erectile sexual metabolic lifestyle',
    '/patient/pwd': 'disability pwd accessibility wheelchair support',
    '/patient/accessibility': 'accessibility text size font contrast reading',
    '/patient/caregiver-portal': 'caregiver carer share family trust access code',
    PatientRoutes.profile: 'profile medilink id account name details me',
    PatientRoutes.dependents: 'children child dependants dependents family kids people i care for',
    '/patient/medication-costs': 'cost costs price money pay medicine',
    '/patient/receipt-upload': 'receipt receipts upload photo payment',
    '/patient/insurance-claims': 'insurance sha nhif claim claims cover',
    '/patient/expenses': 'expenses spending money budget costs',
  };

  /// Shown before she types anything.
  static const suggestedRoutes = [
    PatientRoutes.appointments,
    PatientRoutes.medications,
    PatientRoutes.records,
    PatientRoutes.messages,
    '/patient/medication-reminders',
    '/patient/emergency',
  ];

  /// Every hit for [query], best first: pages, then her medicines,
  /// appointments and care team. Each word she types must match.
  static List<PatientSearchHit> run(
    String query, {
    required List<PatientDest> pages,
    List<PrescriptionModel> medicines = const [],
    List<AppointmentModel> appointments = const [],
    List<CareTeamMemberModel> careTeam = const [],
    DateTime? now,
  }) {
    final words = _words(query);
    if (words.isEmpty) return const [];
    final today = now ?? DateTime.now();
    final names = {for (final m in careTeam) m.providerId: _memberName(m)};

    final scored = <(int, PatientSearchHit)>[];

    void consider(PatientSearchHit hit, String title, String extra, int base) {
      final t = _norm(title);
      final all = '$t ${_norm(extra)}';
      if (!words.every((w) => _hasWordStartingWith(all, w))) return;
      // A title that starts with what she typed comes first.
      final score = base + (t.startsWith(words.first) ? 0 : 10) + (words.every((w) => _hasWordStartingWith(t, w)) ? 0 : 5);
      scored.add((score, hit));
    }

    final seenRoutes = <String>{};
    for (final p in pages) {
      if (!seenRoutes.add(p.route)) continue;
      consider(
        PatientSearchHit(
          kind: PatientSearchKind.page,
          title: p.label,
          subtitle: 'Page',
          icon: p.icon,
          route: p.route,
        ),
        p.label,
        pageWords[p.route] ?? '',
        0,
      );
    }

    for (final m in medicines) {
      final active = m.status == PrescriptionStatus.active;
      final how = DoseFrequency.explain(m.frequency);
      consider(
        PatientSearchHit(
          kind: PatientSearchKind.medicine,
          title: m.medicationName,
          subtitle: [
            if (m.dosage.trim().isNotEmpty) m.dosage.trim(),
            if (how.trim().isNotEmpty) how.trim(),
            active ? 'Taking now' : 'Past medicine',
          ].join(' · '),
          icon: Icons.medication_outlined,
          route: PatientRoutes.medications,
        ),
        m.medicationName,
        '${m.dosage} ${m.instructions ?? ''} medicine ${active ? 'current active taking' : 'past old finished'}',
        active ? 20 : 30,
      );
    }

    final sortedAppointments = [...appointments]..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    for (final a in sortedAppointments) {
      final when = a.scheduledAt.toLocal();
      final upcoming = when.isAfter(today) && a.status != AppointmentStatus.cancelled;
      final who = names[a.providerId];
      final reason = (a.chiefComplaint ?? '').trim();
      final title = reason.isEmpty ? 'Appointment' : reason;
      consider(
        PatientSearchHit(
          kind: PatientSearchKind.appointment,
          title: title,
          subtitle: [
            DateFormat('EEE d MMM yyyy, HH:mm').format(when),
            if (who != null) who,
            _statusLabel(a.status, upcoming),
          ].join(' · '),
          icon: Icons.calendar_today_outlined,
          route: PatientRoutes.appointments,
        ),
        title,
        'appointment visit ${who ?? ''} ${DateFormat('EEEE MMMM d yyyy').format(when)} '
            '${_statusLabel(a.status, upcoming)} ${a.type == AppointmentType.telehealth ? 'video call online telehealth' : 'in person clinic'}',
        upcoming ? 40 : 50,
      );
    }

    for (final m in careTeam) {
      final name = _memberName(m);
      final what = m.specialtyLabel ?? m.providerDepartment ?? m.providerRole;
      consider(
        PatientSearchHit(
          kind: PatientSearchKind.careTeam,
          title: name,
          subtitle: [_capitalize(what), if (m.isPrimary) 'Primary', 'Care team'].join(' · '),
          icon: Icons.person_outline,
          route: '/patient/care-team',
        ),
        name,
        '${m.providerRole} $what ${m.providerDepartment ?? ''} care team doctor nurse',
        60,
      );
    }

    final indexed = [for (final (i, s) in scored.indexed) (i, s)];
    indexed.sort((a, b) {
      final byScore = a.$2.$1.compareTo(b.$2.$1);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    return [for (final (_, s) in indexed) s.$2];
  }

  static String _statusLabel(AppointmentStatus s, bool upcoming) => switch (s) {
        AppointmentStatus.cancelled => 'Cancelled',
        AppointmentStatus.completed => 'Done',
        _ => upcoming ? 'Upcoming' : 'Past',
      };

  static String _memberName(CareTeamMemberModel m) =>
      m.providerName.trim().isEmpty ? (m.specialtyLabel ?? 'Care team member') : m.providerName.trim();

  static String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Lower case, accents and punctuation to spaces.
  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']+"), ' ').replaceAll("'", '').trim();

  static List<String> _words(String query) =>
      _norm(query).split(' ').where((w) => w.isNotEmpty).toList();

  static bool _hasWordStartingWith(String text, String word) =>
      text == word || text.startsWith(word) || text.contains(' $word');
}

/// The search sheet the top bar opens. Searches as she types, for the
/// profile being viewed; tapping a result goes there.
class PatientSearchSheet extends StatefulWidget {
  const PatientSearchSheet({
    super.key,
    required this.pages,
    required this.medicines,
    required this.appointments,
    required this.careTeam,
    this.forName,
  });

  /// The pages this profile can open.
  final List<PatientDest> pages;
  final List<PrescriptionModel> medicines;
  final List<AppointmentModel> appointments;
  final List<CareTeamMemberModel> careTeam;

  /// A dependant's first name when searching their profile.
  final String? forName;

  @override
  State<PatientSearchSheet> createState() => _PatientSearchSheetState();
}

class _PatientSearchSheetState extends State<PatientSearchSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(route);
  }

  List<PatientSearchHit> _hits() => PatientSearch.run(
        _query.text,
        pages: widget.pages,
        medicines: widget.medicines,
        appointments: widget.appointments,
        careTeam: widget.careTeam,
      );

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final hits = _hits();
    final suggested = [
      for (final r in PatientSearch.suggestedRoutes)
        for (final p in widget.pages.where((p) => p.route == r).take(1)) p,
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: PT.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                // Worked out again here: Enter can come before the rebuild
                // for the last letter typed.
                onSubmitted: (_) {
                  final best = _hits();
                  if (best.isNotEmpty) _open(best.first.route);
                },
                decoration: pInput(
                  hint: widget.forName == null
                      ? 'Search pages, your medicines, appointments…'
                      : "Search ${widget.forName}'s medicines, appointments…",
                ).copyWith(
                  prefixIcon: const Icon(Icons.search, size: 18, color: PT.muted),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: query.isEmpty
                      ? [
                          Text('Go to', style: PT.label()),
                          const SizedBox(height: 8),
                          for (final p in suggested)
                            _row(PatientSearchHit(
                              kind: PatientSearchKind.page,
                              title: p.label,
                              subtitle: 'Page',
                              icon: p.icon,
                              route: p.route,
                            )),
                        ]
                      : hits.isEmpty
                          ? [
                              const SizedBox(height: 30),
                              Text('Nothing found for "$query"',
                                  textAlign: TextAlign.center, style: PT.rowTitle()),
                              const SizedBox(height: 6),
                              Text(
                                'Try a medicine, a doctor\'s name, or a page such as "vaccinations" or "reminders".',
                                textAlign: TextAlign.center,
                                style: PT.sub(),
                              ),
                            ]
                          : [
                              for (final kind in PatientSearchKind.values)
                                if (hits.any((h) => h.kind == kind)) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    child: Text(_heading(kind), style: PT.label()),
                                  ),
                                  for (final h in hits.where((h) => h.kind == kind)) _row(h),
                                ],
                            ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _heading(PatientSearchKind kind) => switch (kind) {
        PatientSearchKind.page => 'Pages',
        PatientSearchKind.medicine => widget.forName == null ? 'Your medicines' : "${widget.forName}'s medicines",
        PatientSearchKind.appointment => 'Appointments',
        PatientSearchKind.careTeam => 'Care team',
      };

  Widget _row(PatientSearchHit h) => PRow(
        leading: PSoftIcon(h.icon, size: 38),
        title: h.title,
        subtitle: h.subtitle,
        trailing: const [Icon(Icons.chevron_right, size: 18, color: PT.muted)],
        onTap: () => _open(h.route),
      );
}
