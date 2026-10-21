import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dependent_profile_model.dart';
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
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// The patient app's frame: sidebar, top bar, phone bottom bar and the
/// guardian banner, around whichever patient page is open.
///
/// Built by the `/patient` ShellRoute, so [child] is the routed page and
/// [location] its path. The shell's State lives as long as the patient is
/// in the app, so its data load runs once, not once per page.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  bool _loadFailed = false;

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

    var failed = false;
    try {
      await Future.wait([
        dep.loadDependents(id),
        // Account-level, never per-dependent.
        Provider.of<PreferencesProvider>(context, listen: false).loadPreferences(id),
        Provider.of<PatientProfileProvider>(context, listen: false).loadProfile(id),
        _loadForPatient(dep.activePatientId ?? id),
      ]);
    } catch (e) {
      debugPrint('patient_shell: initial load threw: $e');
      failed = true;
    }

    // The providers catch their own exceptions and return empty lists, so
    // the catch above almost never fires — their `error` fields are the
    // real signal. Without this check a dropped connection reaches Home
    // as a tidy, healthy-looking summary of nothing.
    if (!failed && mounted) failed = _anyLoadFailed();
    if (mounted) setState(() => _loadFailed = failed);

    _maybeRouteToOnboarding(id);
  }

  /// True when any provider behind Home's summary failed to load.
  bool _anyLoadFailed() =>
      Provider.of<AppointmentProvider>(context, listen: false).error != null ||
      Provider.of<AdherenceProvider>(context, listen: false).error != null ||
      Provider.of<PrescriptionProvider>(context, listen: false).error != null ||
      Provider.of<LabProvider>(context, listen: false).error != null;

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
  List<PatientDest> _visibleDests(bool isDependent) => [
        for (final group in patientSidebar.values)
          for (final d in group)
            if (!(isDependent && d.adultOnly)) d,
      ];

  List<SidebarEntry> _sidebarEntries(bool isDependent) {
    final entries = <SidebarEntry>[];
    patientSidebar.forEach((group, dests) {
      final visible = dests.where((d) => !(isDependent && d.adultOnly)).toList();
      if (visible.isEmpty) return;
      entries.add(SidebarGroupLabel(group));
      for (final d in visible) {
        entries.add(SidebarNavItem(icon: d.icon, label: d.label));
      }
    });
    return entries;
  }

  void _openDest(PatientDest d) => context.go(d.route);

  // ── Profile switching ─────────────────────────────────────────────────

  Future<void> _switchTo(String patientId) async {
    final dep = context.read<DependentProvider>();
    dep.switchTo(patientId);
    // Back to Today: most pages load their data once when opened, so
    // staying put would show the previous profile's figures under the
    // new profile's name.
    context.go(PatientRoutes.today);
    await _loadForPatient(patientId);
    // Re-check: switching profile reloads everything Home summarises, so
    // a failure here has to update the flag too — otherwise switching
    // while offline lands on an empty dashboard that looks healthy.
    if (mounted) setState(() => _loadFailed = _anyLoadFailed());
  }

  void _openSwitcher({required bool fromTop}) {
    final isMobile = PT.isMobile(context);

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
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
            sub: _dependentSub(d),
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
                onTap: () => context.go(PatientRoutes.dependents),
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dep = context.watch<DependentProvider>();
    final auth = context.watch<AuthProvider>();
    final isDependent = dep.isViewingDependent;
    final activeDependent = dep.activeDependent;

    final location = widget.location;
    final visible = _visibleDests(isDependent);
    // A page reached from More keeps "More of AfiCare" lit, so the
    // patient can always see where they are in the app.
    final litRoute = patientSidebarRouteFor(location);
    final selectedIndex = visible.indexWhere((d) => d.route == litRoute);
    final bottomIndex = patientBottomIndexFor(location);

    // A child's profile must never sit under an adult-only page (their
    // "finances", maternal care, etc.). Switching profile already goes
    // to Today; this also covers a deep link or the browser's Back.
    if (isDependent && isPatientAdultOnly(location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(PatientRoutes.today);
      });
    }

    final pageTitle = patientTitleFor(location);
    final crumbs = [
      if (!isPatientSidebarRoute(location) && litRoute == PatientRoutes.more && pageTitle != 'More of AfiCare')
        'More of AfiCare',
      pageTitle == 'AfiCare' ? 'Today' : pageTitle,
    ];

    final ownName = auth.currentUser?.fullName ?? 'My profile';
    final displayName = isDependent ? (activeDependent?.fullName ?? 'Dependent') : ownName;
    final displaySub = isDependent
        ? _dependentSub(activeDependent)
        : 'Your personal health space';

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
        bottomNavActiveColor: PT.teal,
        railActiveIndicator: PT.gold,
        topBarColor: PT.page,
        topBarIconStyle: _topIconStyle,
        avatarOnlyWhenCollapsed: true,
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
        BottomNavItem(icon: Icons.home_outlined, label: 'Today'),
        BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Visits'),
        BottomNavItem(icon: Icons.medication_outlined, label: 'Medicines'),
        BottomNavItem(icon: Icons.grid_view_rounded, label: 'More'),
      ],
      selectedIndex: PT.isMobile(context) ? bottomIndex : selectedIndex,
      onSelect: (i) {
        if (i >= 0 && i < visible.length) _openDest(visible[i]);
      },
      onBottomNavSelect: (i) => context.go(patientBottomRoutes[i]),
      onSearch: _openSearch,
      onAvatarTap: () => _openSwitcher(fromTop: true),
      searchHint: 'Search appointments, medications, or anything...',
      avatarLabel: _initials(displayName),
      avatarColor: isDependent ? PT.avatarDepBg : PT.avatarBg,
      topBarLeading: _Breadcrumb(trail: crumbs),
      trailingActions: [
        IconButton(
          onPressed: _openSearch,
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          style: _topIconStyle,
        ),
        const SizedBox(width: 9),
        IconButton(
          // Pushed, full screen: the camera needs the whole screen, and
          // closing it should return to the page it was opened from.
          onPressed: () => context.push(PatientRoutes.scan),
          tooltip: 'Scan a QR code',
          icon: const Icon(Icons.qr_code_scanner_rounded),
          style: _topIconStyle,
        ),
        const SizedBox(width: 9),
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
              message: "You're in ${activeDependent?.fullName.split(' ').first ?? 'a dependant'}'s records. "
                  "You're viewing and managing this profile as their guardian.",
              action: PButton(
                'Back to mine',
                kind: PButtonKind.alt,
                dense: true,
                onPressed: () {
                  final own = dep.ownId;
                  if (own != null) _switchTo(own);
                },
              ),
            ),
          Expanded(
            child: PatientShellScope(
              loadFailed: _loadFailed,
              onRetry: _loadAll,
              child: widget.child,
            ),
          ),
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

  /// Sub-line under a dependant's name in the switcher, e.g. "Child · 4
  /// years". Falls back to the MediLink ID for dependants added before
  /// the wizard started asking for a date of birth.
  String _dependentSub(DependentProfileModel? d) {
    if (d == null) return 'Dependent';
    final raw = d.relationship.trim();
    final rel = raw.isEmpty
        ? 'Dependent'
        : '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}';
    final dob = d.dateOfBirth;
    final mlId = d.medilinkId ?? '';
    if (dob == null) return mlId.isEmpty ? rel : '$rel · $mlId';
    return '$rel · ${_ageLabel(dob)}';
  }

  String _ageLabel(DateTime dob) {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    if (years < 1) {
      final months = (now.difference(dob).inDays / 30.44).floor();
      return '$months month${months == 1 ? '' : 's'}';
    }
    return '$years year${years == 1 ? '' : 's'}';
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.favorite_border_rounded, size: 21, color: PT.teal),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AfiCare',
                    style: PT.body().copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -.5, height: 1.1)),
                Text('YOUR CARE, TOGETHER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.rowSub().copyWith(fontSize: 10, letterSpacing: 1.4, color: const Color(0xFFB6C7D1))),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(top: 15),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PT.railBorder)),
      ),
      child: Material(
        color: const Color(0x0CFFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: PT.avatarDepBg),
                  child: Text(initials,
                      style: PT.body().copyWith(color: PT.avatarDepFg, fontWeight: FontWeight.w800, fontSize: 13)),
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
                const Icon(Icons.unfold_more, size: 15, color: Color(0xFFB6C7D1)),
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

// ═══════════════════════════════════════════════════════════════════════
// Top bar + "More of AfiCare"
// ═══════════════════════════════════════════════════════════════════════

/// The design's `.iconbtn`: white, hairline border, blue glyph.
final ButtonStyle _topIconStyle = IconButton.styleFrom(
  fixedSize: const Size(42, 42),
  backgroundColor: PT.white,
  foregroundColor: PT.teal,
  side: const BorderSide(color: PT.line),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// "AfiCare / Today". Hidden on phones, as in the design, where the
/// bottom bar already says where you are.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.trail});

  /// Page names after "AfiCare", outermost first; the last is current.
  final List<String> trail;

  @override
  Widget build(BuildContext context) {
    if (PT.isMobile(context)) return const SizedBox.shrink();
    const slash = TextSpan(text: '  /  ', style: TextStyle(color: Color(0xFFB3BDC1)));
    return Text.rich(
      TextSpan(
        style: PT.label().copyWith(fontSize: 13),
        children: [
          const TextSpan(text: 'AfiCare'),
          for (int i = 0; i < trail.length; i++) ...[
            slash,
            TextSpan(
              text: trail[i],
              style: i == trail.length - 1
                  ? const TextStyle(fontWeight: FontWeight.w700, color: PT.ink)
                  : null,
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
