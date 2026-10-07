import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/appointment_model.dart';
import '../../models/care_team_member_model.dart';
import '../../models/facility_model.dart';
import '../../models/user_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/care_team_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/provider_avatar.dart';
import 'appointment_detail_screen.dart';
import 'widgets/patient_ui.dart';

/// Appointments — book, manage and understand visits. Rendered inside
/// the patient shell, so it carries no app bar of its own.
///
/// Everything here is scoped to [DependentProvider.activePatientId], so a
/// guardian viewing a child books and manages that child's visits rather
/// than their own.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
  bool _loadFailed = false;
  int _tab = 0; // 0 = Upcoming, 1 = Past, 2 = Cancelled
  Map<String, String> _providerNames = {};
  Map<String, String> _facilityNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _activeId {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    return dep.activePatientId ?? auth.currentUser?.id ?? '';
  }

  Future<void> _load() async {
    if (!mounted) return;
    final apt = Provider.of<AppointmentProvider>(context, listen: false);
    final activeId = _activeId;
    var failed = false;
    if (activeId.isNotEmpty) {
      await apt.loadAppointments(activeId);
      // Read immediately: the provider reuses `error` for booking,
      // cancelling and rescheduling failures too.
      failed = apt.error != null;
    }

    try {
      final provResp = await Supabase.instance.client
          .from('users')
          .select('id, full_name')
          .inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        _providerNames = {
          for (final p in provResp as List) p['id'] as String: p['full_name'] as String,
        };
      }
    } catch (e) {
      debugPrint('appointments_screen: loading providers failed: $e');
      if (mounted) showErrorSnackBar(context, 'Could not load appointments');
    }

    if (!mounted) return;
    try {
      final facilities = Provider.of<AdminFacilityProvider>(context, listen: false);
      await facilities.loadFacilities();
      if (mounted) {
        _facilityNames = {for (final f in facilities.facilities) f.id: f.name};
      }
    } catch (e) {
      debugPrint('appointments_screen: loading facilities failed: $e');
    }

    if (mounted) {
      final ct = Provider.of<CareTeamProvider>(context, listen: false);
      if (activeId.isNotEmpty) await ct.loadCareTeam(activeId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = failed;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  void _refresh() {
    if (!mounted) return;
    final activeId = _activeId;
    if (activeId.isNotEmpty) {
      Provider.of<AppointmentProvider>(context, listen: false).loadAppointments(activeId);
    }
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PScreenHead(
            eyebrow: 'Clinical',
            title: 'Appointments',
            subtitle: 'Book, manage and understand your visits.',
            action: PButton(
              '+ Book appointment',
              onPressed: () => _openBookingSheet(_activeId),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: PT.teal)),
            )
          else
            Consumer2<AppointmentProvider, DependentProvider>(
              builder: (context, apt, dep, _) {
                // Without this, a dropped connection renders as "no
                // upcoming appointments" — and the patient misses a visit
                // they had actually booked.
                if (_loadFailed && apt.appointments.isEmpty) {
                  return PLoadError(what: 'your appointments', onRetry: _retry);
                }
                final now = DateTime.now();
                final all = apt.appointments;

                final upcoming = all
                    .where((a) =>
                        a.scheduledAt.isAfter(now) &&
                        a.status != AppointmentStatus.cancelled &&
                        a.status != AppointmentStatus.completed)
                    .toList()
                  ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                final past = all
                    .where((a) =>
                        a.status != AppointmentStatus.cancelled &&
                        (a.scheduledAt.isBefore(now) ||
                            a.status == AppointmentStatus.completed))
                    .toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                final cancelled = all
                    .where((a) => a.status == AppointmentStatus.cancelled)
                    .toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PTabs(
                      tabs: const ['Upcoming', 'Past', 'Cancelled'],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                    if (_tab == 0) ..._upcomingTab(upcoming),
                    if (_tab == 1)
                      _listCard(
                        title: 'Past appointments',
                        items: past,
                        emptyEmoji: '🗓️',
                        emptyTitle: 'No past appointments',
                        emptyBody: 'Visits you have completed will be listed here.',
                      ),
                    if (_tab == 2)
                      _listCard(
                        title: 'Cancelled appointments',
                        items: cancelled,
                        emptyEmoji: '🗓️',
                        emptyTitle: 'Nothing cancelled',
                        emptyBody: 'Appointments you cancel will appear here.',
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _upcomingTab(List<AppointmentModel> upcoming) {
    final next = upcoming.isEmpty ? null : upcoming.first;
    return [
      PGrid(
        columns: 2,
        children: [
          _nextCard(next),
          _careTeamCard(),
        ],
      ),
      const SizedBox(height: 16),
      _listCard(
        title: 'Upcoming appointments',
        items: upcoming,
        emptyEmoji: '🗓️',
        emptyTitle: 'No upcoming appointments',
        emptyBody: 'Book your first appointment to get started.',
        emptyAction: PButton(
          '+ Book appointment',
          onPressed: () => _openBookingSheet(_activeId),
        ),
        showManage: true,
      ),
    ];
  }

  // ── Next appointment ──────────────────────────────────────────────────

  Widget _nextCard(AppointmentModel? next) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            'Next appointment',
            trailing: next == null ? null : _statusBadge(next.status),
          ),
          if (next == null)
            const PEmpty(
              emoji: '🗓️',
              title: 'Nothing scheduled',
              body: 'When you book, your next visit shows up here.',
            )
          else
            PRow(
              leading: _dateTile(next.scheduledAt),
              title: _providerNames[next.providerId] ?? 'Provider',
              subtitle: _facilityLine(next),
              extraSubtitle:
                  '${DateFormat('HH:mm').format(next.scheduledAt)} · ${_typeLabel(next.type)}',
              trailing: [
                PButton(
                  'Details',
                  kind: PButtonKind.alt,
                  dense: true,
                  onPressed: () => _openDetails(next),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dateTile(DateTime at) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: PT.calloutBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('${at.day}',
              style: PT.h3().copyWith(fontSize: 21, height: 1.1, color: PT.navy)),
          Text(DateFormat('MMM').format(at).toUpperCase(),
              style: PT.rowSub().copyWith(
                  fontSize: 10, fontWeight: FontWeight.w800, color: PT.teal, letterSpacing: .8)),
        ],
      ),
    );
  }

  // ── Care team ─────────────────────────────────────────────────────────

  Widget _careTeamCard() {
    return Consumer<CareTeamProvider>(
      builder: (context, ct, _) {
        final members = ct.members;
        return PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PCardTitle(
                'Your care team',
                trailing: PButton(
                  'View all',
                  kind: PButtonKind.alt,
                  dense: true,
                  onPressed: () => context.go('/patient/care-team'),
                ),
              ),
              if (ct.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: PT.teal)),
                )
              else if (members.isEmpty)
                const PEmpty(
                  emoji: '👩🏾‍⚕️',
                  title: 'No care team yet',
                  body: 'Providers you see will appear here.',
                )
              else
                for (final m in members.take(3)) _careTeamRow(m),
            ],
          ),
        );
      },
    );
  }

  Widget _careTeamRow(CareTeamMemberModel m) {
    final name = m.providerName.trim().isEmpty
        ? (m.specialtyLabel ?? 'Care team member')
        : m.providerName;
    final specialty = m.specialtyLabel ?? m.providerDepartment ?? m.providerRole;

    return PRow(
      leading: ProviderAvatarSmall(
        name: name,
        role: m.providerRole == 'nurse' ? UserRole.nurse : UserRole.doctor,
        gender: m.providerGender,
        photoUrl: m.providerPhotoUrl,
        radius: 19,
      ),
      title: name,
      subtitle: '${_capitalize(specialty)}${m.isPrimary ? ' · Primary' : ''}',
      trailing: [
        PButton(
          'Message',
          kind: PButtonKind.alt,
          dense: true,
          onPressed: () => context.go('/patient/messages'),
        ),
      ],
    );
  }

  // ── Lists ─────────────────────────────────────────────────────────────

  Widget _listCard({
    required String title,
    required List<AppointmentModel> items,
    required String emptyEmoji,
    required String emptyTitle,
    required String emptyBody,
    Widget? emptyAction,
    bool showManage = false,
  }) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(title),
          if (items.isEmpty)
            PEmpty(
              emoji: emptyEmoji,
              title: emptyTitle,
              body: emptyBody,
              action: emptyAction,
            )
          else
            for (final a in items)
              PRow(
                leadingEmoji: '📅',
                title:
                    '${DateFormat('d MMM').format(a.scheduledAt)} · ${a.chiefComplaint?.trim().isNotEmpty == true ? a.chiefComplaint!.trim() : (_providerNames[a.providerId] ?? 'Consultation')}',
                subtitle:
                    '${DateFormat('HH:mm').format(a.scheduledAt)} · ${_facilityLine(a)}',
                trailing: [
                  _statusBadge(a.status),
                  if (showManage)
                    PButton(
                      'Manage',
                      kind: PButtonKind.alt,
                      dense: true,
                      onPressed: () => _openManage(a),
                    )
                  else
                    PButton(
                      'Details',
                      kind: PButtonKind.alt,
                      dense: true,
                      onPressed: () => _openDetails(a),
                    ),
                ],
              ),
        ],
      ),
    );
  }

  String _facilityLine(AppointmentModel a) {
    final facility = a.facilityId == null ? null : _facilityNames[a.facilityId];
    final provider = _providerNames[a.providerId];
    final parts = <String>[
      if (provider != null) provider,
      if (facility != null && facility.isNotEmpty) facility,
    ];
    return parts.isEmpty ? _typeLabel(a.type) : parts.join(' · ');
  }

  String _typeLabel(AppointmentType t) =>
      t == AppointmentType.inPerson ? 'In person' : 'Telehealth';

  Widget _statusBadge(AppointmentStatus s) => switch (s) {
        AppointmentStatus.confirmed => const PBadge('Confirmed', tone: PTone.ok),
        AppointmentStatus.pending => const PBadge('Pending', tone: PTone.warn),
        AppointmentStatus.completed => const PBadge('Completed', tone: PTone.blue),
        AppointmentStatus.cancelled => const PBadge('Cancelled', tone: PTone.gray),
      };

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ── Actions ───────────────────────────────────────────────────────────

  void _openDetails(AppointmentModel a) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AppointmentDetailScreen(appointment: a)),
    ).then((_) => _refresh());
  }

  void _openManage(AppointmentModel a) {
    showPModal<void>(
      context: context,
      title: 'Manage appointment',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('EEEE, d MMM yyyy · HH:mm').format(a.scheduledAt)}\n'
            '${_facilityLine(a)} · ${_typeLabel(a.type)}',
            style: PT.sub(),
          ),
          const SizedBox(height: 18),
          PButton(
            'View details',
            kind: PButtonKind.alt,
            expand: true,
            onPressed: () {
              Navigator.pop(ctx);
              _openDetails(a);
            },
          ),
          const SizedBox(height: 10),
          PButton(
            'Reschedule',
            expand: true,
            onPressed: () {
              Navigator.pop(ctx);
              _reschedule(a);
            },
          ),
          const SizedBox(height: 10),
          PButton(
            'Cancel appointment',
            kind: PButtonKind.red,
            expand: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmCancel(a);
            },
          ),
        ],
      ),
    );
  }

  void _openBookingSheet(String patientId, {UserModel? prefilledProvider}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookAppointmentSheet(
        patientId: patientId,
        prefilledProvider: prefilledProvider,
      ),
    ).then((_) => _refresh());
  }

  void _reschedule(AppointmentModel a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookAppointmentSheet(
        patientId: a.patientId,
        rescheduleAppointment: a,
      ),
    ).then((_) => _refresh());
  }

  void _confirmCancel(AppointmentModel a) {
    showPModal<void>(
      context: context,
      title: 'Cancel appointment?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancel your ${_typeLabel(a.type).toLowerCase()} appointment on '
            '${DateFormat('d MMM yyyy').format(a.scheduledAt)}?',
            style: PT.sub(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PButton(
                  'Keep it',
                  kind: PButtonKind.alt,
                  expand: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  'Yes, cancel',
                  kind: PButtonKind.red,
                  expand: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final apt = Provider.of<AppointmentProvider>(context, listen: false);
                    await apt.cancelAppointment(a.id);
                    if (mounted) {
                      pToast(context, 'Appointment cancelled');
                      _refresh();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Booking / rescheduling sheet
// ═══════════════════════════════════════════════════════════════════════

class _BookAppointmentSheet extends StatefulWidget {
  final String patientId;
  final UserModel? prefilledProvider;
  final AppointmentModel? rescheduleAppointment;

  const _BookAppointmentSheet({
    required this.patientId,
    this.prefilledProvider,
    this.rescheduleAppointment,
  });

  @override
  State<_BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<_BookAppointmentSheet> {
  List<UserModel> _providers = [];
  UserModel? _selectedProvider;
  List<FacilityModel> _facilities = [];
  FacilityModel? _selectedFacility;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isTelehealth = false;
  final _complaintCtrl = TextEditingController();
  bool _loadingProviders = true;
  bool _loadingFacilities = true;
  bool _submitting = false;

  bool get _isRescheduling => widget.rescheduleAppointment != null;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.rescheduleAppointment != null) {
      final a = widget.rescheduleAppointment!;
      _selectedDate = a.scheduledAt;
      _selectedTime = TimeOfDay(hour: a.scheduledAt.hour, minute: a.scheduledAt.minute);
      _isTelehealth = a.type == AppointmentType.telehealth;
      _complaintCtrl.text = a.chiefComplaint ?? '';
    }
  }

  @override
  void dispose() {
    _complaintCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadProviders(), _loadFacilities()]);
  }

  Future<void> _loadProviders() async {
    try {
      final response =
          await Supabase.instance.client.from('users').select().inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        final providers =
            (response as List).map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
        UserModel? selected;
        if (widget.prefilledProvider != null) {
          try {
            selected = providers.firstWhere((p) => p.id == widget.prefilledProvider!.id);
          } catch (_) {
            selected = widget.prefilledProvider;
            providers.insert(0, widget.prefilledProvider!);
          }
        } else if (widget.rescheduleAppointment != null) {
          try {
            selected = providers
                .firstWhere((p) => p.id == widget.rescheduleAppointment!.providerId);
          } catch (_) {
            selected = null;
          }
        }
        setState(() {
          _providers = providers;
          _selectedProvider = selected;
          _loadingProviders = false;
        });
      }
    } catch (e) {
      debugPrint('appointments_screen: loading providers failed: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Could not load providers');
        setState(() => _loadingProviders = false);
      }
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final provider = Provider.of<AdminFacilityProvider>(context, listen: false);
      await provider.loadFacilities();
      if (mounted) {
        setState(() {
          _facilities = provider.facilities;
          if (widget.rescheduleAppointment?.facilityId != null) {
            try {
              _selectedFacility = _facilities
                  .firstWhere((f) => f.id == widget.rescheduleAppointment!.facilityId);
            } catch (_) {
              // Facility not in the loaded list -- leave unselected.
            }
          }
          _loadingFacilities = false;
        });
      }
    } catch (e) {
      debugPrint('appointments_screen: loading facilities failed: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Could not load facilities');
        setState(() => _loadingFacilities = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      pToast(context, 'Please select a date and time.');
      return;
    }
    setState(() => _submitting = true);

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final aptProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final bool ok;

    if (widget.rescheduleAppointment != null) {
      // In-place reschedule: only scheduled_at changes. The provider,
      // facility and type pickers are locked in reschedule mode because
      // reschedule_appointment() only moves the time -- letting them be
      // changed here would silently ignore the new values.
      ok = await aptProvider.rescheduleAppointment(
        widget.rescheduleAppointment!.id,
        scheduledAt,
      );
    } else {
      final providerId = _selectedProvider?.id ?? widget.patientId;
      final appointment = AppointmentModel(
        id: '',
        patientId: widget.patientId,
        providerId: providerId,
        facilityId: _selectedFacility?.id,
        scheduledAt: scheduledAt,
        type: _isTelehealth ? AppointmentType.telehealth : AppointmentType.inPerson,
        status: AppointmentStatus.pending,
        chiefComplaint:
            _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
        isFollowUp: false,
      );
      ok = await aptProvider.bookAppointment(appointment);
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
      _showConfirmation(
        providerName: _selectedProvider?.fullName ?? 'Unassigned',
        facilityName: _selectedFacility?.name ?? '',
        scheduledAt: scheduledAt,
        isTelehealth: _isTelehealth,
      );
    } else {
      pToast(context,
          'Could not ${_isRescheduling ? "reschedule" : "book"} — please try again.');
    }
  }

  void _showConfirmation({
    required String providerName,
    required String facilityName,
    required DateTime scheduledAt,
    required bool isTelehealth,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmationSheet(
        providerName: providerName,
        facilityName: facilityName,
        scheduledAt: scheduledAt,
        isTelehealth: isTelehealth,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: PT.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isRescheduling ? 'Reschedule appointment' : 'Book appointment',
                      style: PT.h3().copyWith(fontSize: 20),
                    ),
                  ),
                  Material(
                    color: PT.closeBtnBg,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(Icons.close, size: 18, color: PT.muted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isRescheduling)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: PCallout(
                    body: 'Rescheduling only moves the date and time. The facility, provider '
                        'and visit type stay as they were.',
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    PFormGrid([
                      PField(label: 'Facility', child: _facilityField()),
                      PField(label: 'Provider', child: _providerField()),
                      PField(label: 'Date', child: _pickerField(
                        _selectedDate == null
                            ? 'Choose a date'
                            : DateFormat('EEE, d MMM yyyy').format(_selectedDate!),
                        Icons.calendar_today_outlined,
                        _pickDate,
                        filled: _selectedDate != null,
                      )),
                      PField(label: 'Time', child: _pickerField(
                        _selectedTime == null ? 'Choose a time' : _selectedTime!.format(context),
                        Icons.schedule,
                        _pickTime,
                        filled: _selectedTime != null,
                      )),
                    ]),
                    const SizedBox(height: 18),
                    Text('Type', style: PT.label().copyWith(fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _typeCard(
                            icon: Icons.local_hospital_outlined,
                            label: 'In person',
                            selected: !_isTelehealth,
                            onTap: _isRescheduling ? null : () => setState(() => _isTelehealth = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _typeCard(
                            icon: Icons.videocam_outlined,
                            label: 'Telehealth',
                            selected: _isTelehealth,
                            onTap: _isRescheduling ? null : () => setState(() => _isTelehealth = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PField(
                      label: 'Reason for visit (optional)',
                      child: TextField(
                        controller: _complaintCtrl,
                        maxLength: 250,
                        maxLines: 4,
                        minLines: 3,
                        decoration: pInput(hint: 'Describe your symptoms…'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PButton(
                      _submitting
                          ? 'Saving…'
                          : (_isRescheduling ? 'Reschedule appointment' : 'Book appointment'),
                      expand: true,
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _facilityField() {
    if (_loadingFacilities) return _fieldSpinner();
    return DropdownButtonFormField<FacilityModel>(
      value: _selectedFacility,
      isExpanded: true,
      decoration: pInput(),
      hint: Text('Any facility', style: PT.sub()),
      items: [
        for (final f in _facilities)
          DropdownMenuItem(
            value: f,
            child: Text(f.name, overflow: TextOverflow.ellipsis, style: PT.body()),
          ),
      ],
      onChanged: _isRescheduling ? null : (v) => setState(() => _selectedFacility = v),
    );
  }

  Widget _providerField() {
    if (_loadingProviders) return _fieldSpinner();
    return DropdownButtonFormField<UserModel>(
      value: _selectedProvider,
      isExpanded: true,
      decoration: pInput(),
      hint: Text('Any available provider', style: PT.sub()),
      items: [
        for (final p in _providers)
          DropdownMenuItem(
            value: p,
            child: Text('${p.fullName} · ${_capitalize(p.role.name)}',
                overflow: TextOverflow.ellipsis, style: PT.body()),
          ),
      ],
      onChanged: _isRescheduling ? null : (v) => setState(() => _selectedProvider = v),
    );
  }

  Widget _pickerField(String text, IconData icon, VoidCallback onTap, {required bool filled}) {
    return Material(
      color: PT.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: PT.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: PT.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: filled ? PT.body() : PT.sub(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null && !selected ? .5 : 1,
      child: Material(
        color: selected ? PT.calloutBg : PT.white,
        borderRadius: BorderRadius.circular(PT.rRow),
        child: InkWell(
          borderRadius: BorderRadius.circular(PT.rRow),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? PT.teal : PT.line, width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(PT.rRow),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? PT.teal : PT.muted),
                const SizedBox(width: 8),
                Text(label,
                    style: PT.body().copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? PT.ink : PT.muted,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldSpinner() => Container(
        height: 46,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: PT.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: PT.teal),
        ),
      );

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ═══════════════════════════════════════════════════════════════════════
// Confirmation
// ═══════════════════════════════════════════════════════════════════════

class _ConfirmationSheet extends StatefulWidget {
  const _ConfirmationSheet({
    required this.providerName,
    required this.facilityName,
    required this.scheduledAt,
    required this.isTelehealth,
  });

  final String providerName;
  final String facilityName;
  final DateTime scheduledAt;
  final bool isTelehealth;

  @override
  State<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<_ConfirmationSheet> {
  static const _autoPopSeconds = 5;
  int _secondsLeft = _autoPopSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _finish();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    Navigator.popUntil(context, (r) => r.isFirst);
    context.go('/patient');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PT.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: PT.calloutBg),
              child: const Icon(Icons.check_rounded, size: 30, color: PT.teal),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text('Appointment requested', style: PT.h3().copyWith(fontSize: 20))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Your provider will confirm shortly. You can see it under Upcoming.',
              textAlign: TextAlign.center,
              style: PT.sub(),
            ),
          ),
          const SizedBox(height: 18),
          PCard(
            child: Column(
              children: [
                _row('When', DateFormat('EEEE, d MMM yyyy · HH:mm').format(widget.scheduledAt)),
                _row('Provider', widget.providerName),
                if (widget.facilityName.isNotEmpty) _row('Facility', widget.facilityName),
                _row('Type', widget.isTelehealth ? 'Telehealth' : 'In person'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PButton('Done ($_secondsLeft)', expand: true, onPressed: _finish),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: PT.label())),
          Expanded(child: Text(value, style: PT.rowTitle())),
        ],
      ),
    );
  }
}
