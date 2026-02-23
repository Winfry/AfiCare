import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math';

import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../models/user_model.dart';
import '../../models/consultation_model.dart';
import '../../models/appointment_model.dart';
import '../../utils/theme.dart';
import '../common/notifications_screen.dart';
import 'manage_dependents_screen.dart';
import 'pwd_tab.dart';
import 'prescriptions_tab.dart';
import 'widgets/profile_switcher_chip.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _generatedAccessCode;
  DateTime? _accessCodeExpiry;

  // Active profile gender — drives tab count & female-specific tab visibility
  // (null = default 6 tabs; initialised from logged-in user on first load)
  String? _activeGender;

  // Settings — personal info controllers
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  bool _settingsInitialized = false;
  bool _isSavingSettings = false;

  // Settings — metadata-backed profile fields
  String? _bloodType;
  DateTime? _dateOfBirth;
  String? _emergencyContactName;
  String? _emergencyContactPhone;

  // Settings — privacy & notifications (persisted to user.metadata)
  bool _allowEmergencyAccess = true;
  bool _allowResearchData = false;
  bool _enableAiRecommendations = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  bool _healthAlerts = true;

  @override
  void initState() {
    super.initState();
    // Start with 6 tabs (no gender-specific tabs). Corrected in build when user loads.
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatientData());
  }

  /// One-time initialisation of settings fields from UserModel metadata.
  void _initSettings(UserModel user) {
    if (_settingsInitialized) return;
    _settingsInitialized = true;
    _nameController.text  = user.fullName;
    _phoneController.text = user.phone ?? '';
    final meta   = user.metadata ?? {};
    _bloodType             = meta['blood_type'] as String?;
    _emergencyContactName  = meta['emergency_contact_name'] as String?;
    _emergencyContactPhone = meta['emergency_contact_phone'] as String?;
    if (meta['date_of_birth'] != null) {
      _dateOfBirth = DateTime.tryParse(meta['date_of_birth'] as String);
    }
    final privacy = (meta['privacy'] as Map<String, dynamic>?) ?? {};
    _allowEmergencyAccess  = privacy['allow_emergency_access']  as bool? ?? true;
    _allowResearchData     = privacy['allow_research_data']     as bool? ?? false;
    _enableAiRecommendations = privacy['enable_ai_recommendations'] as bool? ?? true;
    final notifs = (meta['notifications'] as Map<String, dynamic>?) ?? {};
    _medicationReminders   = notifs['medication_reminders']  as bool? ?? true;
    _appointmentReminders  = notifs['appointment_reminders'] as bool? ?? true;
    _healthAlerts          = notifs['health_alerts']         as bool? ?? true;
  }

  Future<void> _saveSettings(AuthProvider authProvider, UserModel user) async {
    setState(() => _isSavingSettings = true);
    final meta = Map<String, dynamic>.from(user.metadata ?? {});
    meta['blood_type']              = _bloodType;
    meta['emergency_contact_name']  = _emergencyContactName;
    meta['emergency_contact_phone'] = _emergencyContactPhone;
    meta['date_of_birth']           = _dateOfBirth?.toIso8601String();
    meta['privacy'] = {
      'allow_emergency_access':   _allowEmergencyAccess,
      'allow_research_data':      _allowResearchData,
      'enable_ai_recommendations': _enableAiRecommendations,
    };
    meta['notifications'] = {
      'medication_reminders':  _medicationReminders,
      'appointment_reminders': _appointmentReminders,
      'health_alerts':         _healthAlerts,
    };
    final ok = await authProvider.updateProfile(
      fullName: _nameController.text.trim(),
      phone:    _phoneController.text.trim(),
      metadata: meta,
    );
    if (mounted) {
      setState(() => _isSavingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Settings saved' : 'Could not save — try again'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  // ── Profile switching ─────────────────────────────────────

  void _showProfileSwitcherSheet(
      DependentProvider depProvider, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Switch Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Own profile tile
            _profileOptionTile(
              ctx: ctx,
              name: user.fullName,
              subtitle: 'Your profile',
              medilinkId: user.medilinkId,
              isActive: !depProvider.isViewingDependent,
              onTap: () {
                Navigator.pop(ctx);
                _switchProfile(depProvider, user.id, user.gender);
              },
            ),

            // Dependent tiles
            if (depProvider.dependents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No dependents added yet.\nGo to Settings → Manage Dependents to add one.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...depProvider.dependents.map((d) => _profileOptionTile(
                    ctx: ctx,
                    name: d.fullName,
                    subtitle: _capitalize(d.relationship),
                    medilinkId: d.medilinkId,
                    isActive: depProvider.activePatientId == d.id,
                    onTap: () {
                      Navigator.pop(ctx);
                      _switchProfile(depProvider, d.id, d.gender);
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _profileOptionTile({
    required BuildContext ctx,
    required String name,
    required String subtitle,
    String? medilinkId,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? AfiCareTheme.primaryGreen.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AfiCareTheme.primaryGreen.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? AfiCareTheme.primaryGreen
                  : Colors.grey[300],
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  if (medilinkId != null)
                    Text(medilinkId,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle,
                  color: AfiCareTheme.primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }

  /// Switch the active profile, reset the tab controller for the profile's
  /// gender, then reload all data.
  void _switchProfile(
    DependentProvider depProvider,
    String patientId,
    String? gender,
  ) {
    depProvider.switchTo(patientId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isWoman = gender?.toLowerCase() == 'female';
      final needed = isWoman ? 8 : 6;
      setState(() {
        _activeGender = gender;
        _tabController.dispose();
        _tabController = TabController(length: needed, vsync: this);
      });
      _loadPatientData();
    });
  }

  // ── Data loading ───────────────────────────────────────────

  void _loadPatientData() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    final aptProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final prescProvider = Provider.of<PrescriptionProvider>(context, listen: false);
    final depProvider = Provider.of<DependentProvider>(context, listen: false);

    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    // Register own UUID so DependentProvider knows the logged-in user.
    // Resets to own profile only when a different user is detected.
    depProvider.setOwnId(userId);
    depProvider.loadDependents(userId);

    final activeId = depProvider.activePatientId ?? userId;

    // Consultations are always queried for the logged-in user's own profile
    // (dependents have no consultation records in the system).
    patientProvider.loadConsultations(userId);

    // Appointments and prescriptions reload for the currently active profile.
    aptProvider.loadAppointments(activeId);
    prescProvider.loadPrescriptions(activeId);

    // Initialise _activeGender from the active profile on first load.
    if (_activeGender == null) {
      final gender = depProvider.isViewingDependent
          ? depProvider.activeDependent?.gender
          : authProvider.currentUser?.gender;
      if (gender != _activeGender) {
        setState(() => _activeGender = gender);
      }
    }
  }

  /// Ensures the TabController length matches the active profile's gender.
  /// Uses [_activeGender] rather than the auth user's gender so that
  /// profile switching (e.g. to a male dependent of a female parent) works.
  void _ensureTabController() {
    final needed = _activeGender?.toLowerCase() == 'female' ? 8 : 6;
    if (_tabController.length != needed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _tabController.dispose();
          _tabController = TabController(length: needed, vsync: this);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, PatientProvider, DependentProvider>(
      builder: (context, authProvider, patientProvider, depProvider, child) {
        final user = authProvider.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Keep tab count in sync with the active profile's gender.
        _ensureTabController();

        final activeId = depProvider.activePatientId ?? user.id;
        final isActiveWoman = _activeGender?.toLowerCase() == 'female';

        return Scaffold(
          appBar: _buildAppBar(user),
          body: Column(
            children: [
              _buildMedilinkHeader(user, depProvider),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHealthSummaryTab(patientProvider),
                    _buildVisitHistoryTab(patientProvider),
                    if (isActiveWoman) ...[
                      _buildMaternalHealthTab(patientProvider),
                      _buildWomensHealthTab(patientProvider),
                    ],
                    PrescriptionsTab(patientId: activeId),
                    PwdTab(patientId: activeId),
                    _buildSharingTab(user),
                    _buildSettingsTab(user),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel user) {
    return AppBar(
      title: const Text(
        'AfiCare MediLink',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: AfiCareTheme.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, semanticLabel: 'Notifications'),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(userRole: 'patient'),
                ),
              );
            },
          ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) context.go('/login');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMedilinkHeader(UserModel user, DependentProvider depProvider) {
    // Display name and MediLink ID for the active profile
    final isViewingDependent = depProvider.isViewingDependent;
    final activeDependent = depProvider.activeDependent;
    final displayName = isViewingDependent
        ? (activeDependent?.fullName ?? user.fullName)
        : user.fullName;
    final displayMedilinkId = isViewingDependent
        ? (activeDependent?.medilinkId ?? 'ML-DEP-????')
        : (user.medilinkId ?? 'ML-XXX-XXXX');
    final avatarInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryGreen, AfiCareTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              avatarInitial,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AfiCareTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile switcher chip — replaces the static name+ID display
                ProfileSwitcherChip(
                  currentName: displayName,
                  currentMedilinkId: displayMedilinkId,
                  isViewingDependent: isViewingDependent,
                  onSwitchRequested: () =>
                      _showProfileSwitcherSheet(depProvider, user),
                ),
                if (isViewingDependent) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Viewing ${_capitalize(activeDependent?.relationship ?? 'dependent')}\'s profile',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _buildTabBar() {
    final isWoman = _activeGender?.toLowerCase() == 'female';

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AfiCareTheme.primaryGreen,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AfiCareTheme.primaryGreen,
        tabs: [
          const Tab(icon: Icon(Icons.dashboard), text: 'Health'),
          const Tab(icon: Icon(Icons.local_hospital), text: 'Visits'),
          if (isWoman) ...[
            const Tab(icon: Icon(Icons.pregnant_woman), text: 'Maternal'),
            const Tab(icon: Icon(Icons.female), text: 'Women\'s Health'),
          ],
          const Tab(icon: Icon(Icons.medication), text: 'Prescriptions'),
          const Tab(icon: Icon(Icons.accessibility_new), text: 'PWD Profile'),
          const Tab(icon: Icon(Icons.share), text: 'Share'),
          const Tab(icon: Icon(Icons.settings), text: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildAppointmentsCard(BuildContext context) {
    return Consumer<AppointmentProvider>(
      builder: (ctx, aptProvider, _) {
        final now = DateTime.now();
        final upcoming = aptProvider.appointments
            .where((a) =>
                a.scheduledAt.isAfter(now) &&
                a.status != AppointmentStatus.cancelled &&
                a.status != AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final next = upcoming.isNotEmpty ? upcoming.first : null;

        return Card(
          child: InkWell(
            onTap: () => context.go('/patient/appointments'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AfiCareTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_month,
                        color: AfiCareTheme.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appointments',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          next != null
                              ? 'Next: ${_dashFormatDate(next.scheduledAt)}'
                              : 'No upcoming appointments',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.go('/patient/appointments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AfiCareTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Book'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthSummaryTab(PatientProvider patientProvider) {
    final consultations = patientProvider.consultations;
    final latestVitals =
        consultations.isNotEmpty ? consultations.first.vitalSigns : null;
    final score = _calcDashHealthScore(latestVitals);
    // Last 7 in chronological order for the trend chart
    final trend = (List<ConsultationModel>.from(consultations)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
        .toList();
    final trendData = trend.length > 7 ? trend.sublist(trend.length - 7) : trend;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppointmentsCard(context),
          const SizedBox(height: 16),
          _buildHealthMetrics(consultations, latestVitals, score),
          const SizedBox(height: 20),
          _buildHealthAlerts(consultations),
          const SizedBox(height: 20),
          _buildVitalSignsTrends(trendData),
          const SizedBox(height: 20),
          _buildMedicationManagement(consultations),
          const SizedBox(height: 20),
          _buildFollowUpSummary(consultations),
        ],
      ),
    );
  }

  int? _calcDashHealthScore(VitalSigns? v) {
    if (v == null) return null;
    int checks = 0, passed = 0;
    if (v.temperature != null) {
      checks++;
      if (v.temperature! >= 36.1 && v.temperature! <= 37.2) passed++;
    }
    if (v.systolicBP != null) {
      checks++;
      if (v.systolicBP! >= 90 && v.systolicBP! <= 120) passed++;
    }
    if (v.diastolicBP != null) {
      checks++;
      if (v.diastolicBP! >= 60 && v.diastolicBP! <= 80) passed++;
    }
    if (v.pulseRate != null) {
      checks++;
      if (v.pulseRate! >= 60 && v.pulseRate! <= 100) passed++;
    }
    if (v.oxygenSaturation != null) {
      checks++;
      if (v.oxygenSaturation! >= 95) passed++;
    }
    if (checks == 0) return null;
    return ((passed / checks) * 100).round();
  }

  String _dashScoreLabel(int? score) {
    if (score == null) return '--';
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  Color _dashScoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 80) return Colors.green;
    if (score >= 60) return AfiCareTheme.primaryGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _dashTriageRisk(List<ConsultationModel> consultations) {
    if (consultations.isEmpty) return '--';
    final level = consultations.first.triageLevel.toLowerCase();
    if (level.contains('critical')) return 'High';
    if (level.contains('urgent')) return 'Medium';
    return 'Low';
  }

  Color _dashTriageColor(List<ConsultationModel> consultations) {
    if (consultations.isEmpty) return Colors.grey;
    final level = consultations.first.triageLevel.toLowerCase();
    if (level.contains('critical')) return Colors.red;
    if (level.contains('urgent')) return Colors.orange;
    return Colors.green;
  }

  Widget _buildHealthMetrics(
    List<ConsultationModel> consultations,
    VitalSigns? latestVitals,
    int? score,
  ) {
    final totalVisits = consultations.length;
    final followUps = consultations
        .where((c) =>
            c.followUpRequired &&
            c.followUpDate != null &&
            c.followUpDate!.isAfter(DateTime.now()))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Health Score',
                    score?.toString() ?? '--',
                    score != null
                        ? _dashScoreLabel(score)
                        : 'Visit a provider',
                    Icons.favorite,
                    _dashScoreColor(score),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Total Visits',
                    totalVisits.toString(),
                    totalVisits == 0 ? 'No visits yet' : 'Consultations',
                    Icons.local_hospital,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Follow-ups Due',
                    followUps.toString(),
                    followUps == 0 ? 'None pending' : 'Scheduled',
                    Icons.event,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Risk Level',
                    _dashTriageRisk(consultations),
                    consultations.isEmpty
                        ? 'Pending assessment'
                        : 'From last visit',
                    Icons.security,
                    _dashTriageColor(consultations),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Semantics(
      label: '$title, Value: $value, $subtitle',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthAlerts(List<ConsultationModel> consultations) {
    final alerts = <({String text, IconData icon, Color color})>[];

    if (consultations.isEmpty) {
      alerts.add((
        text: 'Visit a healthcare provider to record your first consultation.',
        icon: Icons.local_hospital,
        color: Colors.blue,
      ));
      alerts.add((
        text:
            'Your health score, vitals, and visit history will appear once you have a consultation.',
        icon: Icons.info_outline,
        color: Colors.blue,
      ));
    } else {
      // Check for overdue follow-ups
      final overdue = consultations.where((c) =>
          c.followUpRequired &&
          c.followUpDate != null &&
          c.followUpDate!.isBefore(DateTime.now()));
      for (final c in overdue) {
        alerts.add((
          text:
              'Overdue follow-up for "${c.chiefComplaint}" — scheduled ${_dashFormatDate(c.followUpDate!)}.',
          icon: Icons.warning_amber,
          color: Colors.red,
        ));
      }

      // Upcoming follow-ups
      final upcoming = consultations
          .where((c) =>
              c.followUpRequired &&
              c.followUpDate != null &&
              c.followUpDate!.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
      if (upcoming.isNotEmpty) {
        final next = upcoming.first;
        alerts.add((
          text:
              'Upcoming follow-up on ${_dashFormatDate(next.followUpDate!)} for "${next.chiefComplaint}".',
          icon: Icons.event,
          color: Colors.orange,
        ));
      }

      // Critical triage from last visit
      final last = consultations.first;
      if (last.triageLevel.toLowerCase().contains('critical')) {
        alerts.add((
          text:
              'Your last visit was classified as critical. Seek urgent care if symptoms persist.',
          icon: Icons.emergency,
          color: Colors.red,
        ));
      }

      if (alerts.isEmpty) {
        alerts.add((
          text: 'All clear! No urgent alerts. Keep up with scheduled follow-ups.',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Alerts & Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...alerts.map((a) => _buildAlertItem(a.text, a.icon, a.color)),
          ],
        ),
      ),
    );
  }

  String _dashFormatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  Widget _buildAlertItem(String text, IconData icon, Color color) {
    return Semantics(
      label: 'Alert: $text',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: color == Colors.red ? Colors.red : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsTrends(List<ConsultationModel> trendData) {
    // Build BP spots from real consultations
    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];
    for (int i = 0; i < trendData.length; i++) {
      final v = trendData[i].vitalSigns;
      if (v.systolicBP != null) {
        systolicSpots.add(FlSpot(i.toDouble(), v.systolicBP!.toDouble()));
      }
      if (v.diastolicBP != null) {
        diastolicSpots.add(FlSpot(i.toDouble(), v.diastolicBP!.toDouble()));
      }
    }
    final hasData = systolicSpots.length >= 2 || diastolicSpots.length >= 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blood Pressure Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              hasData
                  ? 'Last ${trendData.length} visits'
                  : 'Needs 2+ visits to show trend',
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Chart will appear after 2+ consultations',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < 0 || i >= trendData.length) {
                              return const Text('');
                            }
                            final d = trendData[i].timestamp;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${d.day}/${d.month}',
                                  style: const TextStyle(fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      if (systolicSpots.length >= 2)
                        LineChartBarData(
                          spots: systolicSpots,
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                      if (diastolicSpots.length >= 2)
                        LineChartBarData(
                          spots: diastolicSpots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                    ],
                    minY: 40,
                    maxY: 180,
                  ),
                ),
              ),
            if (hasData) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bpLegend('Systolic', Colors.red),
                  const SizedBox(width: 20),
                  _bpLegend('Diastolic', Colors.blue),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bpLegend(String label, Color color) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _buildMedicationManagement(List<ConsultationModel> consultations) {
    final recs = consultations.isNotEmpty
        ? consultations.first.recommendations
        : <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Latest Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (consultations.isNotEmpty)
                  Text(
                    _dashFormatDate(consultations.first.timestamp),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF616161)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (recs.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.medical_information_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No recommendations yet',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clinical recommendations will appear after a consultation',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...recs.map(
                (rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: AfiCareTheme.primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(rec,
                              style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpSummary(List<ConsultationModel> consultations) {
    final now = DateTime.now();
    final overdue = consultations
        .where((c) =>
            c.followUpRequired &&
            c.followUpDate != null &&
            c.followUpDate!.isBefore(now))
        .toList()
      ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
    final upcoming = consultations
        .where((c) =>
            c.followUpRequired &&
            c.followUpDate != null &&
            c.followUpDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    final items = [...overdue, ...upcoming];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-up Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No follow-ups scheduled',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ...items.map((c) {
                final isOverdue = c.followUpDate!.isBefore(now);
                final color = isOverdue ? Colors.red : Colors.green;
                return Semantics(
                  label:
                      '${isOverdue ? 'Overdue' : 'Upcoming'} follow-up for ${c.chiefComplaint} on ${_dashFormatDate(c.followUpDate!)}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isOverdue ? Icons.warning_amber : Icons.event,
                          color: color,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.chiefComplaint,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _dashFormatDate(c.followUpDate!),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOverdue ? 'OVERDUE' : 'DUE',
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitHistoryTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisitSummary(patientProvider),
          const SizedBox(height: 20),
          _buildVisitHistory(patientProvider),
        ],
      ),
    );
  }

  Widget _buildVisitSummary(PatientProvider patientProvider) {
    final consultations = patientProvider.consultations;
    final emergencyCount = consultations
        .where((c) => c.triageLevel.toLowerCase() == 'emergency')
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visit Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Visits',
                    '${consultations.length}',
                    consultations.isEmpty ? 'No visits yet' : 'All time',
                    Icons.local_hospital,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Emergency Visits',
                    '$emergencyCount',
                    emergencyCount == 0 ? 'None recorded' : 'Recorded',
                    Icons.emergency,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitHistory(PatientProvider patientProvider) {
    final consultations = patientProvider.consultations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Visits',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (patientProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (consultations.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.local_hospital_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No visits recorded yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your visit history will appear here after your first consultation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ...consultations.map((c) => _buildVisitCard({
                'date': c.timestamp.toString().substring(0, 10),
                'hospital': 'AfiCare',
                'doctor': c.providerId,
                'diagnosis': c.diagnoses.isNotEmpty
                    ? c.diagnoses.first.condition
                    : c.chiefComplaint,
                'triage': c.triageLevel.toUpperCase(),
              })),
      ],
    );
  }

  Widget _buildVisitCard(Map<String, String> visit) {
    Color triageColor = visit['triage'] == 'URGENT' ? Colors.orange : Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visit['date']} - ${visit['hospital']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: triageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    visit['triage']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: triageColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Doctor: ${visit['doctor']}'),
            Text('Diagnosis: ${visit['diagnosis']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMaternalHealthTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maternal Health Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildPregnancyStatusCard(),
          const SizedBox(height: 20),
          _buildPreconceptionCare(),
        ],
      ),
    );
  }

  Widget _buildPregnancyStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Pregnancy Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'not_pregnant', child: Text('Not Pregnant')),
                DropdownMenuItem(value: 'trying', child: Text('Trying to Conceive')),
                DropdownMenuItem(value: 'pregnant', child: Text('Pregnant')),
                DropdownMenuItem(value: 'postpartum', child: Text('Postpartum')),
                DropdownMenuItem(value: 'breastfeeding', child: Text('Breastfeeding')),
              ],
              onChanged: (value) {
                // Handle status change
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreconceptionCare() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preconception Care Checklist',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildChecklistItem('Taking folic acid 400mcg daily', false),
            _buildChecklistItem('Maintaining healthy weight (BMI 18.5-24.9)', true),
            _buildChecklistItem('Regular exercise routine', true),
            _buildChecklistItem('Balanced nutrition', false),
            _buildChecklistItem('No smoking or alcohol', true),
            _buildChecklistItem('Up-to-date vaccinations', false),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AfiCareTheme.primaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Progress: 3/6 items completed (60%)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: (value) {
              // Handle checkbox change
            },
            activeColor: AfiCareTheme.primaryGreen,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWomensHealthTab(PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Women\'s Health Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildScreeningOverview(),
          const SizedBox(height: 20),
          _buildReproductiveHealthConditions(),
          const SizedBox(height: 20),
          _buildMenstrualHealthTracking(),
        ],
      ),
    );
  }

  Widget _buildScreeningOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Screening Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Last Pap Smear',
                    '8 months ago',
                    'Due in 4 months',
                    Icons.medical_services,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Last Mammogram',
                    '14 months ago',
                    'Overdue',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReproductiveHealthConditions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reproductive Health Conditions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('PCOS Management'),
              leading: const Icon(Icons.medical_information),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Symptoms:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('Irregular periods')),
                          Chip(label: Text('Weight gain')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Endometriosis Management'),
              leading: const Icon(Icons.medical_information),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pain Assessment:'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Menstrual pain: '),
                          Expanded(
                            child: Slider(
                              value: 6,
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '6',
                              semanticFormatterCallback: (v) => '${v.toInt()} out of 10',
                              onChanged: (value) {},
                            ),
                          ),
                          // Text alternative for motor-impaired users
                          SizedBox(
                            width: 48,
                            child: Text(
                              '6/10',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AfiCareTheme.primaryGreen,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenstrualHealthTracking() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menstrual Health Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Cycle Length (days)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: '28',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Period Duration (days)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: '5',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Next expected period: February 15, 2024'),
          ],
        ),
      ),
    );
  }

  Widget _buildSharingTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Medical Records',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildAccessCodeGeneration(user),
          const SizedBox(height: 20),
          _buildQRCodeSharing(user),
          const SizedBox(height: 20),
          _buildActiveSessions(),
        ],
      ),
    );
  }

  Widget _buildAccessCodeGeneration(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Access Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Access Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full Medical History')),
                DropdownMenuItem(value: 'current', child: Text('Current Visit Only')),
                DropdownMenuItem(value: 'emergency', child: Text('Emergency Info Only')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Duration',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '1h', child: Text('1 hour')),
                DropdownMenuItem(value: '4h', child: Text('4 hours')),
                DropdownMenuItem(value: '24h', child: Text('24 hours')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateAccessCode,
                icon: const Icon(Icons.key),
                label: const Text('Generate Access Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AfiCareTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_generatedAccessCode != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Access Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatedAccessCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valid until: ${_accessCodeExpiry?.toString().substring(0, 16)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _generateAccessCode() {
    setState(() {
      _generatedAccessCode = (100000 + Random().nextInt(900000)).toString();
      _accessCodeExpiry = DateTime.now().add(const Duration(hours: 1));
    });
  }

  Widget _buildQRCodeSharing(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QR Code Sharing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Semantics(
                      label: 'QR code containing your MediLink ID and access code for sharing medical records',
                      child: QrImageView(
                        data: jsonEncode({
                          'medilink_id': user.medilinkId,
                          'access_code': _generatedAccessCode ?? '123456',
                          'expires_at': DateTime.now()
                              .add(const Duration(hours: 1))
                              .toIso8601String(),
                        }),
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'My AfiCare MediLink ID: ${user.medilinkId}\n'
                        'Access Code: ${_generatedAccessCode ?? '123456'}\n'
                        'Valid for 1 hour',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Access Code'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Sharing Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active sessions',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(UserModel user) {
    // One-time init of controllers from user data
    _initSettings(user);

    return Consumer<AuthProvider>(
      builder: (ctx, authProvider, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ---- Personal Information ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Full name field',
                      child: TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Phone number field',
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '+254...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Email — read-only (changing email requires re-auth)
                    Semantics(
                      label: 'Email address, read only',
                      child: TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                          suffixIcon: Tooltip(
                            message: 'Contact support to change email',
                            child: Icon(Icons.lock_outline, size: 18),
                          ),
                        ),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Blood type
                    Semantics(
                      label: 'Blood type selector',
                      child: DropdownButtonFormField<String>(
                        value: _bloodType,
                        decoration: const InputDecoration(
                          labelText: 'Blood Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.bloodtype),
                        ),
                        hint: const Text('Select blood type'),
                        items: const [
                          'A+', 'A-', 'B+', 'B-',
                          'AB+', 'AB-', 'O+', 'O-', 'Unknown',
                        ].map((t) => DropdownMenuItem(
                          value: t, child: Text(t))).toList(),
                        onChanged: (v) =>
                            setState(() => _bloodType = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date of birth
                    Semantics(
                      label: 'Date of birth',
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateOfBirth ??
                                DateTime(1990),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateOfBirth = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.cake),
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : 'Tap to select',
                            style: TextStyle(
                              color: _dateOfBirth != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Emergency Contact ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emergency,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Emergency Contact',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Emergency contact name',
                      child: TextField(
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Contact Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        controller: TextEditingController(
                            text: _emergencyContactName),
                        onChanged: (v) =>
                            _emergencyContactName = v.trim().isEmpty
                                ? null
                                : v.trim(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Emergency contact phone',
                      child: TextField(
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '+254...',
                        ),
                        controller: TextEditingController(
                            text: _emergencyContactPhone),
                        onChanged: (v) =>
                            _emergencyContactPhone = v.trim().isEmpty
                                ? null
                                : v.trim(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Privacy ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privacy & Security',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text(
                          'Allow emergency access when unconscious'),
                      subtitle: const Text(
                          'Providers can view basic vitals in an emergency',
                          style: TextStyle(fontSize: 12)),
                      value: _allowEmergencyAccess,
                      onChanged: (v) =>
                          setState(() => _allowEmergencyAccess = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                    SwitchListTile.adaptive(
                      title: const Text(
                          'Share anonymized data for research'),
                      subtitle: const Text(
                          'Helps improve healthcare in Kenya',
                          style: TextStyle(fontSize: 12)),
                      value: _allowResearchData,
                      onChanged: (v) =>
                          setState(() => _allowResearchData = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                    SwitchListTile.adaptive(
                      title:
                          const Text('Enable AI health recommendations'),
                      value: _enableAiRecommendations,
                      onChanged: (v) =>
                          setState(() => _enableAiRecommendations = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Notifications ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text('Medication reminders'),
                      value: _medicationReminders,
                      onChanged: (v) =>
                          setState(() => _medicationReminders = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Appointment reminders'),
                      value: _appointmentReminders,
                      onChanged: (v) =>
                          setState(() => _appointmentReminders = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Health alerts'),
                      value: _healthAlerts,
                      onChanged: (v) =>
                          setState(() => _healthAlerts = v),
                      activeColor: AfiCareTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Save button ----
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                label: 'Save settings button',
                child: ElevatedButton.icon(
                  onPressed: _isSavingSettings
                      ? null
                      : () => _saveSettings(authProvider, user),
                  icon: _isSavingSettings
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(
                      _isSavingSettings ? 'Saving…' : 'Save Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Family / Dependents ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Text(
                        'Family',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.child_care,
                          color: AfiCareTheme.primaryGreen),
                      title: const Text('Manage Dependents'),
                      subtitle: const Text(
                          'Add children or family members to manage their health records'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ManageDependentsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Account ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle:
                          const Text('Send a reset link to your email'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final ok = await authProvider
                            .resetPassword(user.email);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Password reset email sent to ${user.email}'
                                  : 'Could not send reset email'),
                              backgroundColor:
                                  ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sign Out',
                          style: TextStyle(color: Colors.red)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text(
                                'You will need to sign in again to access your health records.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('Sign Out',
                                    style:
                                        TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await authProvider.signOut();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}