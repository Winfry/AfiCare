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
import '../../widgets/app_shell.dart';
import 'patient_home_screen.dart';
import 'appointments_screen.dart';
import 'messages_screen.dart';
import 'patient_profile_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  final _screens = const [
    PatientHomeScreen(),
    AppointmentsScreen(),
    MessagesScreen(),
    PatientProfileScreen(),
  ];

  static const _sidebarEntries = [
    SidebarGroupLabel('Clinical'),
    SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
    SidebarNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    SidebarNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    SidebarGroupLabel('Records'),
    SidebarNavItem(icon: Icons.medical_information_outlined, label: 'Records'),
    SidebarNavItem(icon: Icons.receipt_long_outlined, label: 'Expenses'),
  ];

  static const _bottomNavItems = [
    BottomNavItem(icon: Icons.dashboard_outlined, label: 'Home'),
    BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Appointments'),
    BottomNavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    BottomNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

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
        Provider.of<AppointmentProvider>(context, listen: false).loadAppointments(id),
        Provider.of<TriageProvider>(context, listen: false).loadAssessments(id),
        Provider.of<AdherenceProvider>(context, listen: false).loadToday(id),
        Provider.of<AdherenceProvider>(context, listen: false).loadHistory(id, days: 7),
        Provider.of<PatientProfileProvider>(context, listen: false).loadProfile(id),
        Provider.of<PatientProvider>(context, listen: false).loadConsultations(id),
        Provider.of<LabProvider>(context, listen: false).loadOrders(id),
        Provider.of<PrescriptionProvider>(context, listen: false).loadPrescriptions(id),
        Provider.of<PreferencesProvider>(context, listen: false).loadPreferences(id),
      ]);
    } catch (_) {
      // Data loading errors are non-fatal; UI shows empty states
    }

    _maybeRouteToOnboarding(id);
  }

  Future<void> _maybeRouteToOnboarding(String userId) async {
    final profileProvider =
        Provider.of<PatientProfileProvider>(context, listen: false);
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

  void _onSidebarSelect(int navIndex) {
    // Tab items switch the IndexedStack; nav items push a full-page route.
    if (navIndex <= 2) {
      setState(() => _index = navIndex);
    } else if (navIndex == 3) {
      context.go('/patient/records');
    } else if (navIndex == 4) {
      context.go('/patient/expenses');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      sidebarEntries: _sidebarEntries,
      bottomNavItems: _bottomNavItems,
      selectedIndex: _index,
      onSelect: _onSidebarSelect,
      onBottomNavSelect: (i) => setState(() => _index = i),
      onSearch: _openSearch,
      searchHint: 'Search patients, records...',
      avatarLabel: 'P',
      body: IndexedStack(index: _index, children: _screens),
    );
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
    } catch (_) {
      if (mounted) setState(() => _searching = false);
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryCtrl,
                autofocus: true,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search patients, providers, records...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFEEF2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _results.isEmpty && !_searching
                    ? Center(
                        child: Text(
                          _queryCtrl.text.trim().isEmpty
                              ? 'Type a name to search'
                              : 'No results found',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final name = r['full_name'] as String? ?? '';
                          final role = r['role'] as String? ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1D3557),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(role.isNotEmpty ? role : 'Patient'),
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
