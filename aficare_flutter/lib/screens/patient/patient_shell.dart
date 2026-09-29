import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/triage_provider.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../providers/care_team_provider.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/app_shell.dart';
import 'widgets/patient_ui.dart';
import 'patient_home_screen.dart';
import 'appointments_screen.dart';
import 'medication_tracker_screen.dart';
import 'messages_screen.dart';
import 'patient_profile_screen.dart';
import 'manage_dependents_screen.dart';

/// Where a patient nav entry goes. Either an [IndexedStack] tab (kept in
/// the shell so its state survives navigation) or a pushed route.
class _Dest {
  const _Dest({
    required this.icon,
    required this.label,
    this.tab,
    this.route,
    this.adultOnly = false,
  });

  final IconData icon;
  final String label;
  final int? tab;
  final String? route;

  /// Hidden while a guardian is viewing a child's profile (the spec's
  /// `data-adult`): these sections are meaningless for a dependent.
  final bool adultOnly;
}

/// One table that the sidebar, the bottom nav and the mobile "More"
/// sheet all resolve through. Before this existed, sidebar indices and
/// bottom-nav indices meant different things and most of these sections
/// had no path at all on a phone.
const _navGroups = <String, List<_Dest>>{
  'Patient': [
    _Dest(icon: Icons.dashboard_outlined, label: 'Home', tab: 0),
    _Dest(icon: Icons.calendar_today_outlined, label: 'Appointments', tab: 1),
    _Dest(icon: Icons.medication_outlined, label: 'Medications', tab: 2),
    _Dest(icon: Icons.check_circle_outline, label: 'Adherence Log', route: '/patient/adherence'),
    _Dest(icon: Icons.description_outlined, label: 'Health Records', route: '/patient/records'),
    _Dest(icon: Icons.science_outlined, label: 'Lab Results', route: '/patient/labs'),
    _Dest(icon: Icons.chat_bubble_outline, label: 'Messages', tab: 3),
    _Dest(icon: Icons.groups_2_outlined, label: 'Care Team', route: '/patient/care-team'),
    _Dest(icon: Icons.north_east, label: 'Referrals', route: '/patient/referrals'),
    _Dest(icon: Icons.ios_share, label: 'Share Records', route: '/patient/share'),
  ],
  'Health tools': [
    _Dest(icon: Icons.emergency_outlined, label: 'Emergency SOS', route: '/patient/emergency'),
    _Dest(icon: Icons.psychology_outlined, label: 'Mental Health', route: '/patient/mental-health', adultOnly: true),
    _Dest(icon: Icons.vaccines_outlined, label: 'Vaccinations', route: '/patient/vaccinations'),
    _Dest(icon: Icons.alarm_outlined, label: 'Med Reminders', route: '/patient/medication-reminders'),
    _Dest(icon: Icons.manage_search, label: 'Drug Checker', route: '/patient/drug-interactions'),
    _Dest(icon: Icons.pregnant_woman_outlined, label: 'Maternal Care', route: '/patient/anc', adultOnly: true),
    _Dest(icon: Icons.male_outlined, label: "Men's Health", route: '/patient/mens-health', adultOnly: true),
  ],
  'Financial': [
    _Dest(icon: Icons.credit_card_outlined, label: 'Medication Costs', route: '/patient/medication-costs'),
    _Dest(icon: Icons.receipt_long_outlined, label: 'Receipts', route: '/patient/receipt-upload'),
    _Dest(icon: Icons.shield_outlined, label: 'Insurance', route: '/patient/insurance-claims'),
  ],
  'Access': [
    _Dest(icon: Icons.handshake_outlined, label: 'Caregiver Access', route: '/patient/caregiver-portal', adultOnly: true),
    _Dest(icon: Icons.accessible, label: 'PWD / Disability', route: '/patient/pwd'),
    _Dest(icon: Icons.accessibility_new_outlined, label: 'Accessibility', route: '/patient/accessibility'),
    _Dest(icon: Icons.person_outline, label: 'Profile & MediLink', tab: 4),
  ],
};

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _tab = 0;

  final _screens = const [
    PatientHomeScreen(),
    AppointmentsScreen(),
    MedicationTrackerScreen(),
    MessagesScreen(),
    PatientProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  // ── Data loading ──────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id == null) return;

    dep.setOwnId(id);

    try {
      await Future.wait([
        dep.loadDependents(id),
        // Account-level, never per-dependent.
        Provider.of<PreferencesProvider>(context, listen: false).loadPreferences(id),
        Provider.of<PatientProfileProvider>(context, listen: false).loadProfile(id),
        _loadForPatient(dep.activePatientId ?? id),
      ]);
    } catch (_) {
      // Non-fatal; screens render their own empty states.
    }

    _maybeRouteToOnboarding(id);
  }

  /// Everything keyed by the *active* patient UUID, so switching to a
  /// dependent actually shows that dependent's data.
  Future<void> _loadForPatient(String patientId) async {
    if (!mounted) return;
    await Future.wait([
      Provider.of<AppointmentProvider>(context, listen: false).loadAppointments(patientId),
      Provider.of<TriageProvider>(context, listen: false).loadAssessments(patientId),
      Provider.of<AdherenceProvider>(context, listen: false).loadToday(patientId),
      Provider.of<AdherenceProvider>(context, listen: false).loadHistory(patientId, days: 7),
      Provider.of<PatientProvider>(context, listen: false).loadConsultations(patientId),
      Provider.of<LabProvider>(context, listen: false).loadOrders(patientId),
      Provider.of<PrescriptionProvider>(context, listen: false).loadPrescriptions(patientId),
      Provider.of<CareTeamProvider>(context, listen: false).loadCareTeam(patientId),
    ]);
  }

  Future<void> _maybeRouteToOnboarding(String userId) async {
    final profileProvider = Provider.of<PatientProfileProvider>(context, listen: false);
    final profile = profileProvider.profile;
    final incomplete = profile == null ||
        (profile.dateOfBirth == null &&
            profile.emergencyContactName == null &&
            (profile.allergies.isEmpty) &&
            profile.bloodType == null);
    if (!incomplete) return;

    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getBool('onboarding_skip_$userId') ?? false;
    if (!mounted || skipped) return;
    context.go('/onboarding');
  }

  // ── Navigation ────────────────────────────────────────────────────────

  /// Visible destinations for the current profile, flattened in sidebar
  /// order. Adult-only entries drop out on a dependent profile, which is
  /// why the selected index has to be derived from this list rather than
  /// stored.
  List<_Dest> _visibleDests(bool isDependent) => [
        for (final group in _navGroups.values)
          for (final d in group)
            if (!(isDependent && d.adultOnly)) d,
      ];

  List<SidebarEntry> _sidebarEntries(bool isDependent) {
    final entries = <SidebarEntry>[];
    _navGroups.forEach((group, dests) {
      final visible = dests.where((d) => !(isDependent && d.adultOnly)).toList();
      if (visible.isEmpty) return;
      entries.add(SidebarGroupLabel(group));
      for (final d in visible) {
        entries.add(SidebarNavItem(icon: d.icon, label: d.label));
      }
    });
    return entries;
  }

  void _openDest(_Dest d) {
    if (d.tab != null) {
      setState(() => _tab = d.tab!);
    } else if (d.route != null) {
      context.go(d.route!);
    }
  }

  // ── Profile switching ─────────────────────────────────────────────────

  Future<void> _switchTo(String patientId) async {
    final dep = context.read<DependentProvider>();
    dep.switchTo(patientId);
    setState(() => _tab = 0);
    await _loadForPatient(patientId);
  }

  void _openSwitcher({required bool fromTop}) {
    final isMobile = PT.isMobile(context);

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: PT.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
          child: _switcherPanel(ctx),
        ),
      );
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.18),
      barrierLabel: 'Close profile switcher',
      pageBuilder: (ctx, _, __) => Align(
        alignment: fromTop ? Alignment.topRight : Alignment.bottomLeft,
        child: Padding(
          padding: fromTop
              ? const EdgeInsets.only(top: 74, right: 20)
              : const EdgeInsets.only(left: 12, bottom: 76),
          child: Material(
            color: PT.white,
            borderRadius: BorderRadius.circular(PT.rCard),
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: PT.line),
                borderRadius: BorderRadius.circular(PT.rCard),
                boxShadow: PT.popoverShadow,
              ),
              child: _switcherPanel(ctx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _switcherPanel(BuildContext sheetContext) {
    final auth = context.read<AuthProvider>();
    final ownName = auth.currentUser?.fullName ?? 'My profile';
    final ownSub = auth.currentUser?.medilinkId ?? 'Patient';

    // Consumer rather than context.watch: this panel is built inside a
    // dialog/sheet builder, not during this State's build, and watching
    // the State's context from there throws at runtime.
    // Note the builder's context is deliberately unused: the action
    // closures below run *after* the sheet is popped, so they must use
    // this State's long-lived context, not the dialog's.
    return Consumer<DependentProvider>(
      builder: (_, dep, __) {
        final activeId = dep.activePatientId;
        return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Text('SWITCH PROFILE', style: PT.eyebrow().copyWith(color: PT.muted)),
        ),
        _switcherItem(
          sheetContext: sheetContext,
          initials: _initials(ownName),
          name: ownName,
          sub: 'Patient · $ownSub',
          selected: !dep.isViewingDependent,
          isDependent: false,
          onTap: () {
            final own = dep.ownId;
            if (own != null) _switchTo(own);
          },
        ),
        for (final d in dep.dependents)
          _switcherItem(
            sheetContext: sheetContext,
            initials: _initials(d.fullName),
            name: d.fullName,
            sub: '${d.relationship} · ${d.medilinkId}',
            selected: activeId == d.id,
            isDependent: true,
            onTap: () => _switchTo(d.id),
          ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
          child: Column(
            children: [
              _switcherAction(
                sheetContext: sheetContext,
                icon: Icons.add,
                label: 'Add a child profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageDependentsScreen()),
                ),
              ),
              // The spec has no log-out anywhere; keeping it reachable
              // here rather than leaving real users stranded.
              _switcherAction(
                sheetContext: sheetContext,
                icon: Icons.logout,
                label: 'Log out',
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                  if (mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ],
        );
      },
    );
  }

  Widget _switcherItem({
    required BuildContext sheetContext,
    required String initials,
    required String name,
    required String sub,
    required bool selected,
    required bool isDependent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? PT.calloutBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(sheetContext);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              PAvatar(initials: initials, size: 36, isDependent: isDependent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: PT.rowTitle(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(sub, style: PT.rowSub().copyWith(fontSize: 11.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.check, size: 18, color: PT.teal),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switcherAction({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(sheetContext);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: PT.navy),
              const SizedBox(width: 11),
              Text(label, style: PT.rowTitle()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile "More" sheet ───────────────────────────────────────────────

  void _openMoreSheet(bool isDependent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .82),
        decoration: const BoxDecoration(
          color: PT.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('All sections', style: PT.h3().copyWith(fontSize: 18)),
              for (final group in _navGroups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                  child: Text(group.key.toUpperCase(),
                      style: PT.eyebrow().copyWith(color: PT.muted)),
                ),
                for (final d in group.value)
                  if (!(isDependent && d.adultOnly))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Material(
                        color: PT.searchFill,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDest(d);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(13),
                            child: Row(
                              children: [
                                Icon(d.icon, size: 18, color: PT.navy),
                                const SizedBox(width: 12),
                                Expanded(child: Text(d.label, style: PT.body())),
                                const Icon(Icons.chevron_right, size: 18, color: PT.muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dep = context.watch<DependentProvider>();
    final auth = context.watch<AuthProvider>();
    final isDependent = dep.isViewingDependent;
    final activeDependent = dep.activeDependent;

    final visible = _visibleDests(isDependent);
    final selectedIndex = visible.indexWhere((d) => d.tab == _tab);

    final ownName = auth.currentUser?.fullName ?? 'My profile';
    final displayName = isDependent ? (activeDependent?.fullName ?? 'Dependent') : ownName;
    final displaySub = isDependent
        ? '${activeDependent?.relationship ?? 'Dependent'} · ${activeDependent?.medilinkId ?? ''}'
        : 'Patient · ${auth.currentUser?.medilinkId ?? ''}';

    return AppShell(
      shellTheme: AppShellTheme(
        pageBackground: PT.page,
        contentMaxWidth: PT.maxContentWidth,
        collapseWidth: PT.bpMobile,
        railWidth: PT.railWidth,
        railDecoration: const BoxDecoration(gradient: PT.rail),
        railPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        railActiveColor: PT.railActive,
        railItemColor: PT.railText,
        railItemRadius: PT.rButton,
        railItemStyle: PT.navItem(),
        railGroupStyle: PT.navGroup(),
        topBarHeight: PT.topBarHeight,
        topBarBottomBorder:
            isDependent ? const BorderSide(color: PT.teal, width: 3) : const BorderSide(color: PT.line),
        searchFill: PT.searchFill,
        searchRadius: PT.rButton,
        searchMaxWidth: 580,
        bottomNavActiveColor: PT.navy,
      ),
      brandMark: const _PatientBrandMark(),
      sidebarFooter: _MiniProfileButton(
        name: displayName,
        sub: displaySub,
        initials: _initials(displayName),
        isDependent: isDependent,
        onTap: () => _openSwitcher(fromTop: false),
      ),
      sidebarEntries: _sidebarEntries(isDependent),
      bottomNavItems: const [
        BottomNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
        BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Visits'),
        BottomNavItem(icon: Icons.medication_outlined, label: 'Meds'),
        BottomNavItem(icon: Icons.menu, label: 'More'),
      ],
      selectedIndex: PT.isMobile(context) ? (_tab <= 2 ? _tab : -1) : selectedIndex,
      onSelect: (i) {
        if (i >= 0 && i < visible.length) _openDest(visible[i]);
      },
      onBottomNavSelect: (i) {
        if (i <= 2) {
          setState(() => _tab = i);
        } else {
          _openMoreSheet(isDependent);
        }
      },
      onSearch: _openSearch,
      onAvatarTap: () => _openSwitcher(fromTop: true),
      searchHint: 'Search appointments, medications, or anything...',
      avatarLabel: _initials(displayName),
      avatarColor: isDependent ? PT.avatarDepBg : PT.avatarBg,
      trailingActions: [
        IconButton(
          onPressed: () => context.go('/patient/scan'),
          tooltip: 'Scan a QR code',
          icon: const Icon(Icons.qr_code_scanner_rounded),
          style: IconButton.styleFrom(
            backgroundColor: PT.searchFill,
            foregroundColor: PT.navy,
          ),
        ),
        const SizedBox(width: 10),
      ],
      onLogout: () async {
        await context.read<AuthProvider>().signOut();
        if (context.mounted) context.go('/login');
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDependent)
            PViewingBanner(
              message: 'You are viewing ${activeDependent?.fullName ?? 'a dependent'}\'s record as their guardian.',
              action: PButton(
                'Switch back',
                kind: PButtonKind.alt,
                dense: true,
                onPressed: () {
                  final own = dep.ownId;
                  if (own != null) _switchTo(own);
                },
              ),
            ),
          Expanded(child: IndexedStack(index: _tab, children: _screens)),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SearchSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Rail header + footer
// ═══════════════════════════════════════════════════════════════════════

class _PatientBrandMark extends StatelessWidget {
  const _PatientBrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PT.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.favorite, size: 19, color: PT.teal),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AfiCare',
                  style: PT.body().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('Your health, your way.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PT.rowSub().copyWith(fontSize: 10, color: Colors.white.withOpacity(.65))),
            ],
          ),
        ),
      ],
    );
  }
}

/// The rail's sticky account button (`.mini`) — opens the profile
/// switcher, and shows which profile is currently active.
class _MiniProfileButton extends StatelessWidget {
  const _MiniProfileButton({
    required this.name,
    required this.sub,
    required this.initials,
    required this.isDependent,
    required this.onTap,
  });

  final String name;
  final String sub;
  final String initials;
  final bool isDependent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        color: PT.railFooter,
        border: Border(top: BorderSide(color: PT.railBorder)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDependent ? PT.teal : const Color(0x26FFFFFF),
                  ),
                  child: Text(initials,
                      style: PT.body().copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PT.body().copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PT.rowSub().copyWith(fontSize: 11, color: Colors.white.withOpacity(.65))),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more, size: 15, color: Colors.white.withOpacity(.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Search sheet
// ═══════════════════════════════════════════════════════════════════════

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, full_name, role, medilink_id')
          .ilike('full_name', '%$query%')
          .limit(15);
      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response as List);
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('patient_shell: searching patients failed: $e');
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not search patients');
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PT.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryCtrl,
                autofocus: true,
                onSubmitted: (_) => _search(),
                decoration: pInput(hint: 'Search appointments, medications, or anything...').copyWith(
                  prefixIcon: const Icon(Icons.search, size: 18, color: PT.muted),
                  suffixIcon: IconButton(
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward, size: 18),
                    onPressed: _search,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _results.isEmpty && !_searching
                    ? Center(
                        child: Text(
                          _queryCtrl.text.trim().isEmpty ? 'Type a name to search' : 'No results found',
                          style: PT.sub(),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final name = r['full_name'] as String? ?? '';
                          final role = r['role'] as String? ?? '';
                          return PRow(
                            leading: PAvatar(
                              initials: name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                            title: name,
                            subtitle: role.isNotEmpty ? role : 'Patient',
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
