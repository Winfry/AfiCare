import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../widgets/avatar_picker.dart';
import '../../widgets/provider_avatar.dart';
import 'appointment_detail_screen.dart';
import 'share_records.dart';
import 'expenses_screen.dart';

// ── Palette ──────────────────────────────────────────────────────────

const Color _ink = Color(0xFF152A45);
const Color _navy = Color(0xFF1D3557);
const Color _navy2 = Color(0xFF24456B);
const Color _slate = Color(0xFF55708A);
const Color _line = Color(0xFFDCE3EA);
const Color _pageBg = Color(0xFFEEF2F7);
const Color _navyBg = Color(0xFFE8EDF3);
const Color _softBlue = Color(0xFFEAF3FC);
const Color _medBlue = Color(0xFF457B9D);
const Color _success = Color(0xFF2E7D32);
const Color _successLight = Color(0xFFEAF6EE);
const Color _warning = Color(0xFFE65100);
const Color _warningLight = Color(0xFFFDEEE3);
const Color _grey = Color(0xFF9AA5B1);
const Color _greyLight = Color(0xFFF1F3F5);
const Color _heroDeep = Color(0xFF102B4E);
const Color _white = Color(0xFFFFFFFF);

// ── Screen ───────────────────────────────────────────────────────────

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
  Map<String, String> _providerNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final depProvider =
        Provider.of<DependentProvider>(context, listen: false);
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

    if (mounted) {
      final ct =
          Provider.of<CareTeamProvider>(context, listen: false);
      if (activeId != null) await ct.loadCareTeam(activeId);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final depProvider =
        Provider.of<DependentProvider>(context, listen: false);
    final activeId =
        depProvider.activePatientId ?? auth.currentUser?.id ?? '';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _pageBg,
        body: Center(
          child: CircularProgressIndicator(color: _navy, strokeWidth: 2.5),
        ),
      );
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
        final next = upcoming.isNotEmpty ? upcoming.first : null;

        final screenW = MediaQuery.sizeOf(context).width;
        final isDesktop = screenW > 800;

        return Scaffold(
          backgroundColor: _pageBg,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero banner ──
                _HeroBanner(),

                // ── Content ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 16,
                    24,
                    isDesktop ? 28 : 16,
                    40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 1200),
                      child: isDesktop
                          ? _desktopLayout(next, upcoming, past, activeId)
                          : _mobileLayout(
                              next, upcoming, past, activeId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Desktop 2-column layout ──────────────────────────────────────

  Widget _desktopLayout(
    AppointmentModel? next,
    List<AppointmentModel> upcoming,
    List<AppointmentModel> past,
    String activeId,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main column
        Expanded(
          flex: 145,
          child: _mainColumn(next, upcoming, past, activeId),
        ),
        const SizedBox(width: 24),
        // Sidebar
        SizedBox(
          width: 320,
          child: _sidebarColumn(activeId),
        ),
      ],
    );
  }

  // ── Mobile single-column layout ─────────────────────────────────

  Widget _mobileLayout(
    AppointmentModel? next,
    List<AppointmentModel> upcoming,
    List<AppointmentModel> past,
    String activeId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mainColumn(next, upcoming, past, activeId),
        const SizedBox(height: 24),
        _sidebarColumn(activeId),
      ],
    );
  }

  // ── Main column ─────────────────────────────────────────────────

  Widget _mainColumn(
    AppointmentModel? next,
    List<AppointmentModel> upcoming,
    List<AppointmentModel> past,
    String activeId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured next appointment
        if (next != null)
          _FeaturedAppointment(
            appointment: next,
            providerName:
                _providerNames[next.providerId] ?? 'Provider',
            onBook: () => _openBookingSheet(activeId),
            onReschedule: () => _reschedule(next),
            onCancel: () => _cancelAppointment(next),
          )
        else
          _EmptyNextAppointment(
            onBook: () => _openBookingSheet(activeId),
          ),

        const SizedBox(height: 28),

        // Upcoming list
        _SectionHeader(
          title: 'Upcoming',
          count: upcoming.length,
        ),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          _buildEmptyState()
        else
          for (int i = 0; i < upcoming.length; i++) ...[
            _AppointmentListRow(
              appointment: upcoming[i],
              providerName:
                  _providerNames[upcoming[i].providerId] ?? 'Provider',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(
                      appointment: upcoming[i]),
                ),
              ),
            ),
            if (i < upcoming.length - 1)
              const SizedBox(height: 10),
          ],

        // Past
        if (past.isNotEmpty) ...[
          const SizedBox(height: 24),
          _PastSection(
            past: past,
            providerNames: _providerNames,
            onCancel: _cancelAppointment,
            onReschedule: _reschedule,
          ),
        ],
      ],
    );
  }

  // ── Sidebar column ──────────────────────────────────────────────

  Widget _sidebarColumn(String activeId) {
    return Column(
      children: [
        _CareTeamSidebarCard(patientId: activeId),
        const SizedBox(height: 16),
        _QuickActionsCard(onBook: () => _openBookingSheet(activeId)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: _navyBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 28,
              color: _slate,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No upcoming appointments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _slate,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Book your first appointment to get started.',
            style: TextStyle(fontSize: 13.5, color: _slate),
          ),
        ],
      ),
    );
  }

  // ── Booking (bottom sheet) ─────────────────────────────────────

  void _openBookingSheet(String patientId, {UserModel? prefilledProvider}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookAppointmentSheet(
        patientId: a.patientId,
        rescheduleAppointment: a,
      ),
    ).then((_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
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

  Future<void> _cancelAppointment(AppointmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final aptProvider =
          Provider.of<AppointmentProvider>(context, listen: false);
      await aptProvider.updateStatus(
          a.id, AppointmentStatus.cancelled);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HERO BANNER
// ═══════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = screenW > 800;

    return Container(
      width: double.infinity,
      height: isWide ? 180 : 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_heroDeep, _navy, _navy2],
          stops: [0, 0.5, 1],
        ),
        image: DecorationImage(
          image: AssetImage('assets/images/heeero.jpg'),
          fit: BoxFit.cover,
          opacity: 0.2,
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _heroDeep,
                      _navy.withOpacity(0.9),
                      _navy2.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 40 : 20,
                  isWide ? 36 : 28,
                  isWide ? 40 : 20,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Appointments',
                      style: GoogleFonts.fraunces(
                        fontSize: isWide ? 28 : 22,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plan your upcoming appointments',
                      style: TextStyle(
                        fontSize: isWide ? 15 : 13.5,
                        color: _white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FEATURED NEXT APPOINTMENT
// ═══════════════════════════════════════════════════════════════════════

class _FeaturedAppointment extends StatefulWidget {
  const _FeaturedAppointment({
    required this.appointment,
    required this.providerName,
    required this.onBook,
    required this.onReschedule,
    required this.onCancel,
  });

  final AppointmentModel appointment;
  final String providerName;
  final VoidCallback onBook;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  @override
  State<_FeaturedAppointment> createState() =>
      _FeaturedAppointmentState();
}

class _FeaturedAppointmentState extends State<_FeaturedAppointment> {
  bool _hovered = false;

  String _statusLabel() {
    switch (widget.appointment.status) {
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

  Color _statusBg() {
    switch (widget.appointment.status) {
      case AppointmentStatus.confirmed:
        return _successLight;
      case AppointmentStatus.pending:
        return _warningLight;
      case AppointmentStatus.completed:
        return _greyLight;
      case AppointmentStatus.cancelled:
        return _greyLight;
    }
  }

  Color _statusColor() {
    switch (widget.appointment.status) {
      case AppointmentStatus.confirmed:
        return _success;
      case AppointmentStatus.pending:
        return _warning;
      case AppointmentStatus.completed:
        return _slate;
      case AppointmentStatus.cancelled:
        return _grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = screenW > 800;
    final isTelehealth = a.type == AppointmentType.telehealth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(appointment: a),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(isWide ? 24 : 18),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? _navy : _line,
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isWide ? 56 : 48,
                    height: isWide ? 56 : 48,
                    decoration: BoxDecoration(
                      color: _navyBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isTelehealth
                          ? Icons.videocam_rounded
                          : Icons.local_hospital_rounded,
                      color: isTelehealth ? _medBlue : _navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next appointment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _slate,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isWide ? 18 : 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBg(),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _greyLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 15, color: _slate),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy')
                          .format(a.scheduledAt),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time,
                        size: 15, color: _slate),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('h:mm a').format(a.scheduledAt),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetaChip(
                    icon: isTelehealth
                        ? Icons.videocam_outlined
                        : Icons.local_hospital_outlined,
                    label: isTelehealth ? 'Telehealth' : 'In-Person',
                  ),
                  if (a.chiefComplaint != null &&
                      a.chiefComplaint!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.notes_outlined,
                      label: a.chiefComplaint!,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
              if (a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.confirmed) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onReschedule,
                        icon: const Icon(Icons.schedule_outlined,
                            size: 16),
                        label: const Text('Reschedule'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: const BorderSide(color: _line),
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close_outlined,
                            size: 16),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(
                              color: Color(0x3FB71C1C)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNextAppointment extends StatelessWidget {
  const _EmptyNextAppointment({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = screenW > 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _navyBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle_outline,
                size: 24, color: _navy),
          ),
          const SizedBox(height: 14),
          Text(
            'No upcoming appointments',
            style: TextStyle(
              fontSize: isWide ? 17 : 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Book an appointment to get started.',
            style: TextStyle(fontSize: 13.5, color: _slate),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onBook,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Book appointment'),
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: _white,
              minimumSize: const Size(180, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.maxLines,
  });
  final IconData icon;
  final String label;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _medBlue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _medBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _navyBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// APPOINTMENT LIST ROW
// ═══════════════════════════════════════════════════════════════════════

class _AppointmentListRow extends StatefulWidget {
  const _AppointmentListRow({
    required this.appointment,
    required this.providerName,
    required this.onTap,
  });

  final AppointmentModel appointment;
  final String providerName;
  final VoidCallback onTap;

  @override
  State<_AppointmentListRow> createState() =>
      _AppointmentListRowState();
}

class _AppointmentListRowState extends State<_AppointmentListRow> {
  bool _hovered = false;

  String _statusLabel() {
    switch (widget.appointment.status) {
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

  Color _statusBg() {
    switch (widget.appointment.status) {
      case AppointmentStatus.confirmed:
        return _successLight;
      case AppointmentStatus.pending:
        return _warningLight;
      case AppointmentStatus.completed:
        return _greyLight;
      case AppointmentStatus.cancelled:
        return _greyLight;
    }
  }

  Color _statusColor() {
    switch (widget.appointment.status) {
      case AppointmentStatus.confirmed:
        return _success;
      case AppointmentStatus.pending:
        return _warning;
      case AppointmentStatus.completed:
        return _slate;
      case AppointmentStatus.cancelled:
        return _grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = screenW > 800;
    final isTelehealth = a.type == AppointmentType.telehealth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 14 : 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? _navy : _line),
          ),
          child: Row(
            children: [
              // Date box
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _navyBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM')
                          .format(a.scheduledAt)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.scheduledAt.day}',
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
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
                      widget.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isWide ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isTelehealth
                              ? Icons.videocam_outlined
                              : Icons.local_hospital_outlined,
                          size: 12,
                          color: _slate,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isTelehealth ? 'Telehealth' : 'In-person',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _slate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time,
                            size: 12, color: _slate),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(a.scheduledAt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _slate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: _hovered ? _navy : _slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAST SECTION
// ═══════════════════════════════════════════════════════════════════════

class _PastSection extends StatefulWidget {
  const _PastSection({
    required this.past,
    required this.providerNames,
    required this.onCancel,
    required this.onReschedule,
  });
  final List<AppointmentModel> past;
  final Map<String, String> providerNames;
  final void Function(AppointmentModel) onCancel;
  final void Function(AppointmentModel) onReschedule;

  @override
  State<_PastSection> createState() => _PastSectionState();
}

class _PastSectionState extends State<_PastSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Past appointments (${widget.past.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: _slate,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                for (int i = 0; i < widget.past.length; i++) ...[
                  _AppointmentListRow(
                    appointment: widget.past[i],
                    providerName: widget
                            .providerNames[widget.past[i].providerId] ??
                        'Provider',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppointmentDetailScreen(
                            appointment: widget.past[i]),
                      ),
                    ),
                  ),
                  if (i < widget.past.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
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

// ═══════════════════════════════════════════════════════════════════════
// CARE TEAM SIDEBAR CARD
// ═══════════════════════════════════════════════════════════════════════

class _CareTeamSidebarCard extends StatefulWidget {
  const _CareTeamSidebarCard({required this.patientId});
  final String patientId;

  @override
  State<_CareTeamSidebarCard> createState() => _CareTeamSidebarCardState();
}

class _CareTeamSidebarCardState extends State<_CareTeamSidebarCard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CareTeamProvider>(
      builder: (context, ct, _) {
        final members = ct.members;
        final hasMembers = members.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Care team',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  if (hasMembers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _navyBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${members.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (ct.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _navy),
                    ),
                  ),
                )
              else if (!hasMembers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No care team yet',
                      style: TextStyle(fontSize: 13.5, color: _slate),
                    ),
                  ),
                )
              else
                _buildMemberGrid(members),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _greyLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 16, color: _navy),
                      SizedBox(width: 6),
                      Text(
                        'Add member',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberGrid(List<CareTeamMemberModel> members) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: members.take(4).map((m) {
        final specialty = m.specialtyLabel ??
            m.providerDepartment ??
            m.providerRole;
        return SizedBox(
          width: 110,
          child: Column(
            children: [
              ProviderAvatar(
                name: m.providerName,
                role: m.providerRole == 'nurse'
                    ? UserRole.nurse
                    : UserRole.doctor,
                gender: m.providerGender,
                photoUrl: m.providerPhotoUrl,
                patientId: widget.patientId,
                providerId: m.providerId,
                radius: 24,
                onChooseAvatar: () => showAvatarPicker(
                  context: context,
                  patientId: widget.patientId,
                  providerId: m.providerId,
                ).then((_) {
                  if (mounted) setState(() {});
                }),
              ),
              const SizedBox(height: 8),
              Text(
                m.providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _capitalize(specialty),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: _slate,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ═══════════════════════════════════════════════════════════════════════
// QUICK ACTIONS SIDEBAR CARD
// ═══════════════════════════════════════════════════════════════════════

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.person_search_outlined,
                  label: 'Find provider',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Book visit',
                  onTap: onBook,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.share_outlined,
                  label: 'Share records',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ShareRecords()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'View history',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExpensesScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? _softBlue : _greyLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(widget.icon,
                  size: 20, color: _hovered ? _navy : _slate),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? _navy : _slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOOK APPOINTMENT BOTTOM SHEET
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
  State<_BookAppointmentSheet> createState() =>
      _BookAppointmentSheetState();
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

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.rescheduleAppointment != null) {
      final a = widget.rescheduleAppointment!;
      _selectedDate = a.scheduledAt;
      _selectedTime =
          TimeOfDay(hour: a.scheduledAt.hour, minute: a.scheduledAt.minute);
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
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        UserModel? selected;
        if (widget.prefilledProvider != null) {
          try {
            selected = providers
                .firstWhere((p) => p.id == widget.prefilledProvider!.id);
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
      final provider =
          Provider.of<AdminFacilityProvider>(context, listen: false);
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
      type:
          _isTelehealth ? AppointmentType.telehealth : AppointmentType.inPerson,
      status: AppointmentStatus.pending,
      chiefComplaint:
          _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
      isFollowUp: false,
    );

    final aptProvider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final ok = await aptProvider.bookAppointment(appointment);

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        if (widget.rescheduleAppointment != null) {
          await aptProvider.updateStatus(
              widget.rescheduleAppointment!.id, AppointmentStatus.cancelled);
        }
        if (!mounted) return;
        Navigator.pop(context);
        _showConfirmation(
          providerName: _selectedProvider?.fullName ?? 'Unassigned',
          providerRole: _selectedProvider?.role.name,
          facilityName: _selectedFacility?.name ?? '',
          scheduledAt: scheduledAt,
          isTelehealth: _isTelehealth,
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

  void _showConfirmation({
    required String providerName,
    String? providerRole,
    required String facilityName,
    required DateTime scheduledAt,
    required bool isTelehealth,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfirmationSheet(
        providerName: providerName,
        providerRole: providerRole,
        facilityName: facilityName,
        scheduledAt: scheduledAt,
        isTelehealth: isTelehealth,
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
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
    final screenW = MediaQuery.sizeOf(context).width;
    final isDesktop = screenW > 700;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.rescheduleAppointment != null
                        ? 'Reschedule appointment'
                        : 'Book appointment',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: _greyLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: _slate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Facility + Provider
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _facilityField()),
                          const SizedBox(width: 14),
                          Expanded(child: _providerField()),
                        ],
                      )
                    else ...[
                      _facilityField(),
                      const SizedBox(height: 18),
                      _providerField(),
                    ],
                    const SizedBox(height: 18),

                    // Date + Time
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _dateField()),
                          const SizedBox(width: 14),
                          Expanded(child: _timeField()),
                        ],
                      )
                    else ...[
                      _dateField(),
                      const SizedBox(height: 18),
                      _timeField(),
                    ],
                    const SizedBox(height: 18),

                    // Type
                    const _FieldLabel('Type'),
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
                    const _FieldLabel('Chief complaint (optional)'),
                    TextField(
                      controller: _complaintCtrl,
                      maxLength: 250,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(fontSize: 14.5, color: _ink),
                      cursorColor: _navy,
                      decoration: InputDecoration(
                        hintText: 'Describe your symptoms\u2026',
                        hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: _slate.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        constraints:
                            const BoxConstraints(minHeight: 80),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _line, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _line, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _navy, width: 1.5),
                        ),
                        counterStyle: const TextStyle(
                            fontSize: 11.5, color: _slate),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _navy,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Text(
                              widget.rescheduleAppointment != null
                                  ? 'Reschedule appointment'
                                  : 'Book appointment'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Facility'),
        _FieldRow(
          icon: Icons.local_hospital_outlined,
          suffix: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: _slate),
          child: _loadingFacilities
              ? _loadingSpinner()
              : DropdownButton<FacilityModel>(
                  value: _selectedFacility,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  icon: const SizedBox.shrink(),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style:
                      const TextStyle(fontSize: 14.5, color: _ink),
                  hint: const Text('Choose facility',
                      style:
                          TextStyle(fontSize: 14.5, color: _slate)),
                  items: _facilities
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedFacility = v),
                ),
        ),
      ],
    );
  }

  Widget _providerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Provider'),
        _FieldRow(
          icon: Icons.person_outline,
          suffix: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: _slate),
          child: _loadingProviders
              ? _loadingSpinner()
              : _providers.isEmpty
                  ? const Text(
                      'No providers registered',
                      style:
                          TextStyle(fontSize: 14.5, color: _slate))
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: _navyBg,
                          child: _selectedProvider == null
                              ? const Icon(Icons.person_outline,
                                  size: 16, color: _slate)
                              : Text(
                                  _initials(
                                      _selectedProvider!.fullName),
                                  style: const TextStyle(
                                    color: _navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<UserModel>(
                            value: _selectedProvider,
                            isExpanded: true,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            icon: const SizedBox.shrink(),
                            dropdownColor: Colors.white,
                            borderRadius:
                                BorderRadius.circular(12),
                            style: const TextStyle(
                                fontSize: 14.5, color: _ink),
                            hint: const Text('Choose provider',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    color: _slate)),
                            items: _providers
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor:
                                                _navyBg,
                                            child: Text(
                                              _initials(p.fullName),
                                              style:
                                                  const TextStyle(
                                                color: _navy,
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Text(
                                                  p.fullName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
                                                  style:
                                                      const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight:
                                                        FontWeight
                                                            .w600,
                                                    color: _ink,
                                                  ),
                                                ),
                                                Text(
                                                  p.role.name,
                                                  style:
                                                      const TextStyle(
                                                    fontSize: 12,
                                                    color: _slate,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _selectedProvider = v),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Date'),
        _FieldRow(
          icon: Icons.calendar_today_outlined,
          suffix: const Icon(Icons.chevron_right,
              size: 18, color: _slate),
          onTap: _pickDate,
          child: Text(
            _selectedDate != null
                ? DateFormat('d MMMM yyyy').format(_selectedDate!)
                : 'Choose date',
            style: TextStyle(
              fontSize: 14.5,
              color: _selectedDate != null ? _ink : _slate,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Time'),
        _FieldRow(
          icon: Icons.access_time,
          suffix: const Icon(Icons.chevron_right,
              size: 18, color: _slate),
          onTap: _pickTime,
          child: Text(
            _selectedTime != null
                ? _selectedTime!.format(context)
                : 'Choose time',
            style: TextStyle(
              fontSize: 14.5,
              color: _selectedTime != null ? _ink : _slate,
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingSpinner() => const SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _navy),
          ),
        ),
      );
}

// ── Booking form widgets ────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _slate,
        ),
      ),
    );
  }
}

class _FieldRow extends StatefulWidget {
  const _FieldRow({
    required this.icon,
    required this.child,
    this.suffix,
    this.onTap,
  });
  final IconData icon;
  final Widget child;
  final Widget? suffix;
  final VoidCallback? onTap;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? _navy : _line,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: _slate),
          const SizedBox(width: 12),
          Expanded(child: widget.child),
          if (widget.suffix != null) ...[
            const SizedBox(width: 8),
            widget.suffix!,
          ],
        ],
      ),
    );

    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onFocusChange: (f) {
        if (_focused != f) setState(() => _focused = f);
      },
      child: widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: row)
          : row,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _navyBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _navy : _line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? _navy : _slate,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? _navy : _slate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CONFIRMATION BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════

class _ConfirmationSheet extends StatefulWidget {
  const _ConfirmationSheet({
    required this.providerName,
    required this.facilityName,
    required this.scheduledAt,
    required this.isTelehealth,
    this.providerRole,
  });
  final String providerName;
  final String? providerRole;
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

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
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
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 30, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Appointment booked!',
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your appointment has been successfully scheduled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _slate),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    _ConfirmRow(
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: _navyBg,
                        child: Text(
                          _initials(widget.providerName),
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.providerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.providerRole ?? '',
                            style: const TextStyle(
                                fontSize: 12.5, color: _slate),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: _line),
                    _ConfirmRow(
                      icon: Icons.location_on_outlined,
                      label: widget.facilityName.isEmpty
                          ? '\u2014'
                          : widget.facilityName,
                    ),
                    Container(height: 1, color: _line),
                    _ConfirmRow(
                      icon: Icons.calendar_today_outlined,
                      label:
                          '${DateFormat('d MMMM yyyy').format(widget.scheduledAt)} \u00B7 ${DateFormat('h:mm a').format(widget.scheduledAt)}',
                    ),
                    Container(height: 1, color: _line),
                    _ConfirmRow(
                      icon: widget.isTelehealth
                          ? Icons.videocam_outlined
                          : Icons.local_hospital_outlined,
                      label: widget.isTelehealth
                          ? 'Telehealth'
                          : 'In-Person',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      child: const Text('View appointments'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _finish,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _navy,
                        side: const BorderSide(
                            color: _line, width: 1.5),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Back to home'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Returning in $_secondsLeft s\u2026',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: _slate),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({this.icon, this.label, this.child, this.leading});
  final IconData? icon;
  final String? label;
  final Widget? child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            SizedBox(
              width: 20,
              child: Icon(icon!, size: 16, color: _slate),
            ),
          const SizedBox(width: 12),
          if (child != null)
            Expanded(child: child!)
          else if (label != null)
            Expanded(
              child: Text(label!,
                  style: const TextStyle(fontSize: 14, color: _ink)),
            ),
        ],
      ),
    );
  }
}
