import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/appointment_model.dart';
import '../../models/facility_model.dart';
import '../../models/user_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import 'appointment_detail_screen.dart';
import 'widgets/care_team_section.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
  bool _showAll = false;
  Map<String, String> _providerNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final depProvider = Provider.of<DependentProvider>(context, listen: false);
    final apt = Provider.of<AppointmentProvider>(context, listen: false);
    final activeId = depProvider.activePatientId ?? auth.currentUser?.id;
    if (activeId != null) await apt.loadAppointments(activeId);
    try {
      final provResp = await Supabase.instance.client
          .from('users')
          .select('id, full_name')
          .inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        _providerNames = {
          for (final p in provResp as List)
            p['id'] as String: p['full_name'] as String,
        };
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final depProvider = Provider.of<DependentProvider>(context, listen: false);
    final activeId = depProvider.activePatientId ?? auth.currentUser?.id ?? '';

    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Consumer2<AppointmentProvider, DependentProvider>(
      builder: (context, aptProvider, depProv, _) {
        final now = DateTime.now();
        final upcoming = aptProvider.appointments
            .where((a) =>
                a.scheduledAt.isAfter(now) &&
                a.status != AppointmentStatus.cancelled &&
                a.status != AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final past = aptProvider.appointments
            .where((a) =>
                a.scheduledAt.isBefore(now) ||
                a.status == AppointmentStatus.cancelled ||
                a.status == AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

        final screenW = MediaQuery.sizeOf(context).width;
        final isDesktop = screenW > 700;

        final displayList = _showAll
            ? (aptProvider.appointments
                    .where((a) => a.status != AppointmentStatus.cancelled)
                    .toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt)))
            : upcoming;

        Widget buildCard(AppointmentModel a) => _AppointmentCard(
              appointment: a,
              providerName: _providerNames[a.providerId] ?? 'Provider',
            );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Care team row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: CareTeamSection(
                            patientId: activeId,
                            onBookFromCareTeam: (provider) =>
                                _openBooking(activeId,
                                    prefilledProvider: provider),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Section header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                _showAll
                                    ? 'All appointments'
                                    : 'Upcoming appointments',
                                style: TextStyle(
                                    fontSize: isDesktop ? 18 : 16.5,
                                    fontWeight: FontWeight.w700)),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showAll = !_showAll),
                              child: Text(
                                  _showAll ? 'Show upcoming' : 'View all',
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D3557))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (displayList.isEmpty)
                          _buildEmptyState()
                        else if (isDesktop && displayList.length > 1)
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: displayList
                                .map((a) => SizedBox(
                                      width: (780 - 14) / 2,
                                      child: buildCard(a),
                                    ))
                                .toList(),
                          )
                        else
                          ...displayList.map(buildCard),

                        const SizedBox(height: 6),

                        // Past toggle
                        if (past.isNotEmpty)
                          _PastToggle(
                              pastCount: past.length,
                              past: past,
                              providerNames: _providerNames,
                              onCancel: _cancelAppointment,
                              onReschedule: _reschedule),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
              // Sticky book button
              _BookButton(
                onPressed: () => _openBooking(activeId),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(_showAll ? 'No appointments yet' : 'No upcoming appointments',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text('Tap the button below to book your first one.',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  void _openBooking(String patientId, {UserModel? prefilledProvider}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookAppointmentScreen(
          patientId: patientId,
          prefilledProvider: prefilledProvider,
        ),
      ),
    ).then((_) {
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final depProvider =
            Provider.of<DependentProvider>(context, listen: false);
        final activeId =
            depProvider.activePatientId ?? auth.currentUser?.id;
        if (activeId != null) {
          Provider.of<AppointmentProvider>(context, listen: false)
              .loadAppointments(activeId);
        }
        setState(() {});
      }
    });
  }

  void _reschedule(AppointmentModel a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookAppointmentScreen(
          patientId: a.patientId,
          rescheduleAppointment: a,
        ),
      ),
    ).then((_) {
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final depProvider =
            Provider.of<DependentProvider>(context, listen: false);
        final activeId =
            depProvider.activePatientId ?? auth.currentUser?.id;
        if (activeId != null) {
          Provider.of<AppointmentProvider>(context, listen: false)
              .loadAppointments(activeId);
        }
        setState(() {});
      }
    });
  }

  Future<void> _cancelAppointment(AppointmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
            'Cancel your ${a.type == AppointmentType.telehealth ? "telehealth" : "in-person"} appointment on ${DateFormat('d MMM yyyy').format(a.scheduledAt)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final aptProvider = Provider.of<AppointmentProvider>(context,
          listen: false);
      await aptProvider.updateStatus(
          a.id, AppointmentStatus.cancelled);
    }
  }
}

// ── Appointment card ────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.providerName,
    this.greyed = false,
  });
  final AppointmentModel appointment;
  final String providerName;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    final isTelehealth =
        appointment.type == AppointmentType.telehealth;
    final textColor = greyed ? Colors.grey[600]! : const Color(0xFF152A45);

    String statusLabel() {
      switch (appointment.status) {
        case AppointmentStatus.confirmed:
          return 'Confirmed';
        case AppointmentStatus.pending:
          return 'Pending';
        case AppointmentStatus.completed:
          return 'Completed';
        case AppointmentStatus.cancelled:
          return 'Cancelled';
      }
    }

    Color statusBg() {
      switch (appointment.status) {
        case AppointmentStatus.confirmed:
          return const Color(0xFFEAF6EE);
        case AppointmentStatus.pending:
          return const Color(0xFFFDEEE3);
        default:
          return const Color(0xFFEEF2F7);
      }
    }

    Color statusColor() {
      switch (appointment.status) {
        case AppointmentStatus.confirmed:
          return const Color(0xFF2E7D32);
        case AppointmentStatus.pending:
          return const Color(0xFFE65100);
        default:
          return const Color(0xFF3D5470);
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      )),
      child: Opacity(
        opacity: greyed ? 0.85 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE3EA)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isTelehealth
                      ? const Color(0xFFE9F1F5)
                      : const Color(0xFFE8EDF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTelehealth ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                  color: isTelehealth
                      ? const Color(0xFF457B9D)
                      : const Color(0xFF1D3557),
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTelehealth ? 'TELEHEALTH' : 'IN-PERSON',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3D5470),
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      providerName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor),
                    ),
                    Text(
                      isTelehealth ? 'Remote consultation' : 'In-person visit',
                      style: TextStyle(
                          fontSize: 12.5, color: const Color(0xFF3D5470)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 13,
                          color: const Color(0xFF3D5470).withOpacity(0.7)),
                      const SizedBox(width: 5),
                      Text(
                          DateFormat('d MMM yyyy')
                              .format(appointment.scheduledAt),
                          style: TextStyle(
                              fontSize: 12.5,
                              color: const Color(0xFF3D5470))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time,
                          size: 13,
                          color: const Color(0xFF3D5470).withOpacity(0.7)),
                      const SizedBox(width: 5),
                      Text(
                          DateFormat('h:mm a')
                              .format(appointment.scheduledAt),
                          style: TextStyle(
                              fontSize: 12.5,
                              color: const Color(0xFF3D5470),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg(),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(statusLabel(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Past toggle ─────────────────────────────────────────────────────

class _PastToggle extends StatefulWidget {
  const _PastToggle({
    required this.pastCount,
    required this.past,
    required this.providerNames,
    required this.onCancel,
    required this.onReschedule,
  });
  final int pastCount;
  final List<AppointmentModel> past;
  final Map<String, String> providerNames;
  final void Function(AppointmentModel) onCancel;
  final void Function(AppointmentModel) onReschedule;

  @override
  State<_PastToggle> createState() => _PastToggleState();
}

class _PastToggleState extends State<_PastToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE3EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Past appointments (${widget.pastCount})',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF3D5470)),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: widget.past
                  .map((a) => _AppointmentCard(
                      appointment: a,
                      greyed: true,
                      providerName:
                          widget.providerNames[a.providerId] ?? 'Provider'))
                  .toList(),
            ),
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}

// ── Book button ─────────────────────────────────────────────────────

class _BookButton extends StatelessWidget {
  const _BookButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC).withOpacity(0),
            const Color(0xFFF8FAFC),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D3557),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
            textStyle: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 8),
              Text('Book Appointment'),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FULL-SCREEN BOOK APPOINTMENT FLOW
// ═══════════════════════════════════════════════════════════════════════

class _BookAppointmentScreen extends StatefulWidget {
  final String patientId;
  final UserModel? prefilledProvider;
  final AppointmentModel? rescheduleAppointment;
  const _BookAppointmentScreen({
    required this.patientId,
    this.prefilledProvider,
    this.rescheduleAppointment,
  });

  @override
  State<_BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<_BookAppointmentScreen> {
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

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.rescheduleAppointment != null) {
      final a = widget.rescheduleAppointment!;
      _selectedDate = a.scheduledAt;
      _selectedTime = TimeOfDay(
          hour: a.scheduledAt.hour, minute: a.scheduledAt.minute);
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
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        final providers = (response as List)
            .map((j) =>
                UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        UserModel? selected;
        if (widget.prefilledProvider != null) {
          try {
            selected = providers.firstWhere(
                (p) => p.id == widget.prefilledProvider!.id);
          } catch (_) {
            selected = widget.prefilledProvider;
            providers.insert(0, widget.prefilledProvider!);
          }
        }
        setState(() {
          _providers = providers;
          _selectedProvider = selected;
          _loadingProviders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final provider = Provider.of<AdminFacilityProvider>(context,
          listen: false);
      await provider.loadFacilities();
      if (mounted) {
        setState(() {
          _facilities = provider.facilities;
          _loadingFacilities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time.')),
      );
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

    final providerId = _selectedProvider?.id ?? widget.patientId;

    final appointment = AppointmentModel(
      id: '',
      patientId: widget.patientId,
      providerId: providerId,
      facilityId: _selectedFacility?.id,
      scheduledAt: scheduledAt,
      type: _isTelehealth
          ? AppointmentType.telehealth
          : AppointmentType.inPerson,
      status: AppointmentStatus.pending,
      chiefComplaint: _complaintCtrl.text.trim().isEmpty
          ? null
          : _complaintCtrl.text.trim(),
      isFollowUp: false,
    );

    final aptProvider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final ok = await aptProvider.bookAppointment(appointment);

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        if (widget.rescheduleAppointment != null) {
          await aptProvider.updateStatus(widget.rescheduleAppointment!.id,
              AppointmentStatus.cancelled);
        }
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ConfirmationScreen(
              providerName:
                  _selectedProvider?.fullName ?? 'Unassigned',
              facilityName: _selectedFacility?.name ?? '',
              scheduledAt: scheduledAt,
              isTelehealth: _isTelehealth,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not book — try again'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _BookingHeader(
                title: widget.rescheduleAppointment != null
                    ? 'Reschedule appointment'
                    : 'Book appointment'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Facility
                      _FieldLabel('Facility'),
                      _FieldRow(
                        icon: Icons.local_hospital_outlined,
                        child: _loadingFacilities
                            ? const SizedBox(
                                height: 20,
                                child: Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2))))
                            : DropdownButton<FacilityModel>(
                                value: _selectedFacility,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                hint: const Text('Choose facility',
                                    style: TextStyle(
                                        color:
                                            Color(0xFF3D5470))),
                                items: _facilities
                                    .map((f) =>
                                        DropdownMenuItem(
                                            value: f,
                                            child: Text(f.name)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _selectedFacility = v),
                              ),
                      ),
                      const SizedBox(height: 18),

                      // Provider
                      _FieldLabel('Provider'),
                      _FieldRow(
                        icon: Icons.person_outline,
                        child: _loadingProviders
                            ? const SizedBox(
                                height: 20,
                                child: Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2))))
                            : _providers.isEmpty
                                ? const Text(
                                    'No providers registered — booking unassigned',
                                    style: TextStyle(
                                        color:
                                            Color(0xFF3D5470)))
                                : DropdownButton<UserModel>(
                                    value: _selectedProvider,
                                    isExpanded: true,
                                    underline:
                                        const SizedBox.shrink(),
                                    hint: const Text(
                                        'Choose provider',
                                        style: TextStyle(
                                            color: Color(
                                                0xFF3D5470))),
                                    items: _providers
                                        .map((p) =>
                                            DropdownMenuItem(
                                                value: p,
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFE8EDF3),
                                                      child: Text(
                                                        p.fullName[0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFF1D3557),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            fontSize:
                                                                12),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            p.fullName,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        Text(
                                                            p.role.name,
                                                            style: TextStyle(
                                                                fontSize:
                                                                    12.5,
                                                                color: const Color(
                                                                        0xFF3D5470)
                                                                    .withOpacity(
                                                                        0.8))),
                                                      ],
                                                    ),
                                                  ],
                                                )))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _selectedProvider = v),
                                  ),
                      ),
                      const SizedBox(height: 18),

                      // Date
                      _FieldLabel('Date'),
                      _FieldRow(
                        icon: Icons.calendar_today_outlined,
                        child: GestureDetector(
                          onTap: () => _pickDate(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDate != null
                                      ? DateFormat('d MMMM yyyy')
                                          .format(_selectedDate!)
                                      : 'Choose date',
                                  style: TextStyle(
                                    color: _selectedDate != null
                                        ? const Color(0xFF152A45)
                                        : const Color(0xFF3D5470),
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16,
                                  color: Color(0xFF3D5470)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Time
                      _FieldLabel('Time'),
                      _FieldRow(
                        icon: Icons.access_time,
                        child: GestureDetector(
                          onTap: () => _pickTime(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Choose time',
                                  style: TextStyle(
                                    color: _selectedTime != null
                                        ? const Color(0xFF152A45)
                                        : const Color(0xFF3D5470),
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16,
                                  color: Color(0xFF3D5470)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Type
                      _FieldLabel('Type'),
                      Row(
                        children: [
                          Expanded(
                            child: _TypeCard(
                              icon: Icons.local_hospital_outlined,
                              label: 'In-Person',
                              selected: !_isTelehealth,
                              onTap: () =>
                                  setState(() => _isTelehealth = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypeCard(
                              icon: Icons.videocam_outlined,
                              label: 'Telehealth',
                              selected: _isTelehealth,
                              onTap: () =>
                                  setState(() => _isTelehealth = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Chief complaint
                      _FieldLabel('Chief complaint (optional)'),
                      TextField(
                        controller: _complaintCtrl,
                        maxLength: 250,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe your symptoms…',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFDCE3EA),
                                width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1D3557),
                                width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Submit
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1D3557),
                          minimumSize:
                              const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(999)),
                          textStyle: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                            : Text(widget.rescheduleAppointment != null
                                ? 'Reschedule appointment'
                                : 'Book appointment'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ??
          const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Color(0xFFDCE3EA), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.fraunces(
                  fontSize: 21, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.close,
                  size: 16, color: Color(0xFF3D5470)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3D5470))),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3EA), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 17, color: const Color(0xFF3D5470).withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE8EDF3)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF1D3557)
                : const Color(0xFFDCE3EA),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: selected
                    ? const Color(0xFF1D3557)
                    : const Color(0xFF3D5470)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF1D3557)
                      : const Color(0xFF3D5470),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Confirmation screen ─────────────────────────────────────────────

class _ConfirmationScreen extends StatelessWidget {
  const _ConfirmationScreen({
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const SizedBox(height: 50),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 30, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text('Appointment booked!',
                    style: GoogleFonts.fraunces(
                        fontSize: 23, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                    'Your appointment has been successfully scheduled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF3D5470))),
                const SizedBox(height: 26),

                // Detail card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFDCE3EA)),
                  ),
                  child: Column(
                    children: [
                      _ConfirmRow(
                        icon: Icons.person_outline,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(providerName,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                            Text(
                                isTelehealth
                                    ? 'Remote consultation'
                                    : 'In-person visit',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF3D5470))),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFFDCE3EA)),
                      _ConfirmRow(
                        icon: Icons.location_on_outlined,
                        label: facilityName,
                      ),
                      const Divider(color: Color(0xFFDCE3EA)),
                      _ConfirmRow(
                        icon: Icons.calendar_today_outlined,
                        label:
                            '${DateFormat('d MMMM yyyy').format(scheduledAt)} · ${DateFormat('h:mm a').format(scheduledAt)}',
                      ),
                      const Divider(color: Color(0xFFDCE3EA)),
                      _ConfirmRow(
                        icon: isTelehealth
                            ? Icons.videocam_outlined
                            : Icons.local_hospital_outlined,
                        label: isTelehealth
                            ? 'Telehealth'
                            : 'In-Person',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                FilledButton(
                  onPressed: () {
                    Navigator.popUntil(context, (r) => r.isFirst);
                    context.go('/patient');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D3557),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(999)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('View my appointments'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.popUntil(context, (r) => r.isFirst);
                    context.go('/patient');
                  },
                  child: const Text('Back to home',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D3557))),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({this.icon, this.label, this.child});
  final IconData? icon;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon!, size: 16, color: const Color(0xFF3D5470)),
          if (icon != null) const SizedBox(width: 12),
          if (child != null)
            Expanded(child: child!)
          else if (label != null)
            Expanded(
                child: Text(label!,
                    style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
