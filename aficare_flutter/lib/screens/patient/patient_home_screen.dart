import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/triage_provider.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../models/appointment_model.dart';
import '../../models/adherence_model.dart';
import '../../models/triage_model.dart';
import '../../widgets/section_head.dart';
import '../../widgets/action_card.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/stat_card.dart';
import '../../utils/theme.dart';
import '../../utils/app_strings.dart';
import 'health_summary.dart';
import 'share_records.dart';
import 'expenses_screen.dart';
import 'lab_results_screen.dart';
import 'medication_tracker_screen.dart';
import 'prescriptions_list_screen.dart';
import 'appointments_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  static const double _desktopBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appointments = Provider.of<AppointmentProvider>(context);
    final triage = Provider.of<TriageProvider>(context);
    final adherence = Provider.of<AdherenceProvider>(context);
    final prefs = Provider.of<PreferencesProvider>(context);
    final prescriptions = Provider.of<PrescriptionProvider>(context);
    final labs = Provider.of<LabProvider>(context);
    final profile = Provider.of<PatientProfileProvider>(context).profile;

    final user = auth.currentUser;
    final lang = prefs.prefs?.language ?? 'en';
    final firstName = (user?.fullName ?? 'there').split(' ').first;
    final fullName = user?.fullName ?? 'Patient';
    final medilinkId = (user?.medilinkId?.isNotEmpty ?? false)
        ? user!.medilinkId!
        : 'ML-XXX-XXXX';
    final allergies = profile?.allergies ?? const <String>[];
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', lang == 'sw' ? 'sw' : 'en').format(now);

    final needsOnboarding = profile == null ||
        (profile.dateOfBirth == null &&
            profile.emergencyContactName == null &&
            profile.bloodType == null &&
            allergies.isEmpty);

    final nextAppt = _nextAppointment(appointments.appointments);
    final upcoming = _upcomingAppointments(appointments.appointments);
    final vitals = triage.getLatestAssessment(user?.id ?? '');
    final todayMeds = adherence.todayDoses;
    final activeRx = prescriptions.getActivePrescriptions().length;
    final pendingLabs = labs.orders.where((o) => o.isPending).length;
    final takenToday = todayMeds.where((m) => m.status == AdherenceStatus.taken).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 4),
          child: needsOnboarding
              ? _buildFirstRun(
                  firstName: firstName,
                  dateStr: dateStr,
                  lang: lang,
                  allergies: allergies,
                  fullName: fullName,
                  medilinkId: medilinkId,
                  hasAppointments: appointments.appointments.isNotEmpty,
                  hasMedications: todayMeds.isNotEmpty || activeRx > 0,
                  onToggleLanguage: () => _toggleLanguage(context, prefs),
                )
              : isDesktop
                  ? _buildDesktop(
                      firstName: firstName,
                      dateStr: dateStr,
                      lang: lang,
                      allergies: allergies,
                      fullName: fullName,
                      medilinkId: medilinkId,
                      nextAppt: nextAppt,
                      upcoming: upcoming,
                      vitals: vitals,
                      todayMeds: todayMeds,
                      activeRx: activeRx,
                      pendingLabs: pendingLabs,
                      takenToday: takenToday,
                      onToggleLanguage: () => _toggleLanguage(context, prefs),
                    )
                  : _buildMobile(
                      firstName: firstName,
                      dateStr: dateStr,
                      lang: lang,
                      allergies: allergies,
                      fullName: fullName,
                      medilinkId: medilinkId,
                      userId: user?.id ?? '',
                      nextAppt: nextAppt,
                      vitals: vitals,
                      todayMeds: todayMeds,
                      onToggleLanguage: () => _toggleLanguage(context, prefs),
                    ),
        );
      },
    );
  }

  /// First-run dashboard — shown until the patient completes onboarding.
  Widget _buildFirstRun({
    required String firstName,
    required String dateStr,
    required String lang,
    required List<String> allergies,
    required String fullName,
    required String medilinkId,
    required bool hasAppointments,
    required bool hasMedications,
    required VoidCallback onToggleLanguage,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GreetingRow(name: firstName, date: dateStr, lang: lang, onToggleLanguage: onToggleLanguage),
            const SizedBox(height: 18),
            if (allergies.isNotEmpty) ...[
              _AllergyBanner(allergies: allergies),
              const SizedBox(height: 18),
            ],
            _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
            const SizedBox(height: 28),
            SectionHead(title: AppStrings.quickActions(lang)),
            const SizedBox(height: 12),
            _QuickActionsGrid(),
            const SizedBox(height: 28),
            _OnboardingChecklist(
              hasAppointments: hasAppointments,
              hasMedications: hasMedications,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile({
    required String firstName,
    required String dateStr,
    required String lang,
    required List<String> allergies,
    required String fullName,
    required String medilinkId,
    required String userId,
    required AppointmentModel? nextAppt,
    required TriageAssessment? vitals,
    required List<AdherenceLogModel> todayMeds,
    required VoidCallback onToggleLanguage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingRow(name: firstName, date: dateStr, lang: lang, onToggleLanguage: onToggleLanguage),
        const SizedBox(height: 18),
        if (allergies.isNotEmpty) ...[
          _AllergyBanner(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        const SizedBox(height: 20),
        _AppointmentCard(appointment: nextAppt, lang: lang, userId: userId),
        const SizedBox(height: 20),
        _VitalsCard(assessment: vitals, lang: lang),
        const SizedBox(height: 20),
        _MedicationCard(medications: todayMeds, lang: lang),
        const SizedBox(height: 24),
        SectionHead(title: AppStrings.quickActions(lang)),
        const SizedBox(height: 12),
        _QuickActionsGrid(),
        const SizedBox(height: 24),
        SectionHead(
          title: AppStrings.recentActivity(lang),
          actionText: AppStrings.seeAll(lang),
          onAction: () {},
        ),
        const SizedBox(height: 8),
        const _RecentActivityCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDesktop({
    required String firstName,
    required String dateStr,
    required String lang,
    required List<String> allergies,
    required String fullName,
    required String medilinkId,
    required AppointmentModel? nextAppt,
    required List<AppointmentModel> upcoming,
    required TriageAssessment? vitals,
    required List<AdherenceLogModel> todayMeds,
    required int activeRx,
    required int pendingLabs,
    required int takenToday,
    required VoidCallback onToggleLanguage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingRow(name: firstName, date: dateStr, lang: lang, onToggleLanguage: onToggleLanguage),
        const SizedBox(height: 18),
        if (allergies.isNotEmpty) ...[
          _AllergyBanner(allergies: allergies),
          const SizedBox(height: 18),
        ],
        _MediLinkCard(fullName: fullName, medilinkId: medilinkId),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.calendar_today_rounded,
                value: '${upcoming.length}',
                label: 'Upcoming Appointments',
                iconBackground: const Color(0xFFC7EDE4),
                iconColor: const Color(0xFF206B5D),
                deltaLabel: nextAppt != null ? DateFormat('MMM d').format(nextAppt.scheduledAt) : null,
                deltaBackground: const Color(0xFFC7EDE4),
                deltaColor: const Color(0xFF206B5D),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.medication_outlined,
                value: '$activeRx',
                label: 'Active Prescriptions',
                iconBackground: const Color(0xFFC7EDE4),
                iconColor: const Color(0xFF206B5D),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.science_outlined,
                value: '$pendingLabs',
                label: 'Pending Lab Results',
                iconBackground: const Color(0xFFEFF6FA),
                iconColor: const Color(0xFF3E7CA6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline,
                value: todayMeds.isEmpty ? '—' : '$takenToday/${todayMeds.length}',
                label: 'Medications Today',
                iconBackground: const Color(0xFFE4F3EA),
                iconColor: const Color(0xFF2E7D32),
                deltaLabel: todayMeds.isEmpty ? null : '${(takenToday / todayMeds.length * 100).round()}%',
                deltaBackground: const Color(0xFFE4F3EA),
                deltaColor: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _UpcomingAppointmentsCard(upcoming: upcoming, lang: lang),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _Panel(title: AppStrings.recentActivity(lang), child: const _ActivityList()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _VitalsCard(assessment: vitals, lang: lang)),
            const SizedBox(width: 16),
            Expanded(child: _MedicationCard(medications: todayMeds, lang: lang)),
          ],
        ),
        const SizedBox(height: 24),
        SectionHead(title: AppStrings.quickActions(lang)),
        const SizedBox(height: 12),
        _QuickActionsGrid(),
        const SizedBox(height: 24),
      ],
    );
  }

  void _toggleLanguage(BuildContext context, PreferencesProvider prefs) {
    final current = prefs.prefs?.language ?? 'en';
    final next = current == 'en' ? 'sw' : 'en';
    final existing = prefs.prefs;
    if (existing != null) {
      prefs.save(existing.copyWith(language: next));
    }
  }

  AppointmentModel? _nextAppointment(List<AppointmentModel> all) {
    final upcoming = _upcomingAppointments(all);
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  List<AppointmentModel> _upcomingAppointments(List<AppointmentModel> all) {
    final upcoming = all.where((a) =>
        a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed).toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _UpcomingAppointmentsCard extends StatelessWidget {
  const _UpcomingAppointmentsCard({required this.upcoming, required this.lang});

  final List<AppointmentModel> upcoming;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Upcoming Appointments',
      child: upcoming.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                AppStrings.noAppointments(lang),
                style: const TextStyle(fontSize: 14, color: Color(0xFF55708A)),
              ),
            )
          : Column(
              children: [for (final a in upcoming.take(5)) _apptRow(a)],
            ),
    );
  }

  Widget _apptRow(AppointmentModel a) {
    final typeLabel = a.type == AppointmentType.telehealth ? 'Telehealth' : 'In-person';
    final confirmed = a.status == AppointmentStatus.confirmed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFC7EDE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(a.scheduledAt).toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF206B5D)),
                ),
                Text('${a.scheduledAt.day}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF152A45))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('h:mm a').format(a.scheduledAt), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
                const SizedBox(height: 2),
                Text(
                  typeLabel + (a.chiefComplaint != null ? ' · ${a.chiefComplaint}' : ''),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF55708A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (confirmed ? const Color(0xFF2E7D32) : const Color(0xFFE65100)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              confirmed ? 'Confirmed' : 'Pending',
              style: TextStyle(
                color: confirmed ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.name,
    required this.date,
    required this.lang,
    required this.onToggleLanguage,
  });

  final String name;
  final String date;
  final String lang;
  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.greeting(name, lang),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF152A45)),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF55708A)),
                ),
              ],
            ),
          ),
          _LangToggle(lang: lang, onTap: onToggleLanguage),
        ],
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.lang, required this.onTap});
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDCE3EA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate, size: 16, color: Color(0xFF55708A)),
              const SizedBox(width: 6),
              Text(
                AppStrings.swahili(lang),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF55708A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.lang, required this.userId});

  final AppointmentModel? appointment;
  final String lang;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return AfiCareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBg(Icons.calendar_today_rounded, const Color(0xFF206B5D), const Color(0xFFC7EDE4)),
              const SizedBox(width: 12),
              Text(AppStrings.appointmentCardTitle(lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
            ],
          ),
          const SizedBox(height: 16),
          if (appointment != null)
            _buildAppointmentDetail(appointment!)
          else
            _buildNoAppointment(),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetail(AppointmentModel a) {
    final time = DateFormat('MMM d, yyyy · h:mm a').format(a.scheduledAt);
    final typeLabel = a.type == AppointmentType.telehealth ? 'Telehealth' : 'In-person';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1D3557))),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDF3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(typeLabel, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1D3557), fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            if (a.chiefComplaint != null)
              Expanded(
                child: Text(a.chiefComplaint!, style: const TextStyle(fontSize: 13, color: Color(0xFF55708A)), overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoAppointment() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppStrings.noAppointments(lang), style: const TextStyle(fontSize: 14, color: Color(0xFF55708A))),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(AppStrings.bookAppointment(lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.assessment, required this.lang});

  final TriageAssessment? assessment;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return AfiCareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBg(Icons.favorite_border, const Color(0xFF7C5CB4), const Color(0xFFF4EEFA)),
              const SizedBox(width: 12),
              Text(AppStrings.vitalsTitle(lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
            ],
          ),
          const SizedBox(height: 16),
          if (assessment != null)
            _buildVitals(context, assessment!)
          else
            Text(AppStrings.noVitals(lang), style: const TextStyle(fontSize: 14, color: Color(0xFF55708A))),
        ],
      ),
    );
  }

  Widget _buildVitals(BuildContext context, TriageAssessment v) {
    final tileWidth = (MediaQuery.of(context).size.width.clamp(0, 600) - 84) / 2;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (v.systolicBP != null && v.diastolicBP != null)
          _vitalTile(tileWidth, 'BP', '${v.systolicBP}/${v.diastolicBP}', 'mmHg', Icons.monitor_heart_outlined, _bpColor(v.systolicBP!, v.diastolicBP!)),
        if (v.heartRate != null)
          _vitalTile(tileWidth, 'HR', '${v.heartRate}', 'bpm', Icons.favorite_outline, _hrColor(v.heartRate!)),
        if (v.oxygenSaturation != null)
          _vitalTile(tileWidth, 'SpO₂', '${v.oxygenSaturation!.toInt()}', '%', Icons.air, _spo2Color(v.oxygenSaturation!)),
        if (v.temperature != null)
          _vitalTile(tileWidth, 'Temp', v.temperature!.toStringAsFixed(1), '°C', Icons.device_thermostat, _tempColor(v.temperature!)),
      ],
    );
  }

  Widget _vitalTile(double width, String label, String value, String unit, IconData icon, Color color) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF55708A), fontWeight: FontWeight.w500)),
              Text('$value $unit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Color _bpColor(int sys, int dia) {
    if (sys >= 140 || dia >= 90) return const Color(0xFFB71C1C);
    if (sys >= 130 || dia >= 80) return const Color(0xFFE65100);
    return const Color(0xFF2E7D32);
  }

  Color _hrColor(int hr) {
    if (hr > 100 || hr < 60) return const Color(0xFFE65100);
    return const Color(0xFF2E7D32);
  }

  Color _spo2Color(double spo2) {
    if (spo2 < 92) return const Color(0xFFB71C1C);
    if (spo2 < 95) return const Color(0xFFE65100);
    return const Color(0xFF2E7D32);
  }

  Color _tempColor(double temp) {
    if (temp > 38 || temp < 35.5) return const Color(0xFFE65100);
    return const Color(0xFF2E7D32);
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medications, required this.lang});

  final List<AdherenceLogModel> medications;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return AfiCareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBg(Icons.medication_outlined, const Color(0xFF206B5D), const Color(0xFFC7EDE4)),
              const SizedBox(width: 12),
              Text(AppStrings.medicationsTitle(lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
            ],
          ),
          const SizedBox(height: 16),
          if (medications.isNotEmpty)
            ...medications.map((m) => _MedRow(med: m, lang: lang))
          else
            Text(AppStrings.noMedications(lang), style: const TextStyle(fontSize: 14, color: Color(0xFF55708A))),
        ],
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({required this.med, required this.lang});

  final AdherenceLogModel med;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(med.scheduledTime);
    final name = med.medicationName ?? 'Medication';
    final dose = med.dosage ?? '';
    final taken = med.status == AdherenceStatus.taken;
    final skipped = med.status == AdherenceStatus.skipped;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: taken ? const Color(0xFFE4F3EA) : skipped ? const Color(0xFFFDECE8) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            taken ? Icons.check_circle : skipped ? Icons.cancel : Icons.schedule,
            size: 22,
            color: taken ? const Color(0xFF2E7D32) : skipped ? const Color(0xFFB71C1C) : const Color(0xFF55708A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name $dose', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
                Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF55708A))),
              ],
            ),
          ),
          if (med.status == AdherenceStatus.pending)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniBtn(AppStrings.taken(lang), const Color(0xFF2E7D32), () => _mark(context, AdherenceStatus.taken)),
                const SizedBox(width: 6),
                _miniBtn(AppStrings.skip(lang), const Color(0xFFB71C1C), () => _mark(context, AdherenceStatus.skipped)),
              ],
            )
          else
            Text(
              taken ? '✓ ${AppStrings.taken(lang)}' : '✗ ${AppStrings.skip(lang)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: taken ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C)),
            ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }

  void _mark(BuildContext context, AdherenceStatus status) {
    Provider.of<AdherenceProvider>(context, listen: false).markStatus(med.id, status);
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.6,
          children: [
            ActionCard(
              title: 'Prescriptions',
              icon: Icons.medication_outlined,
              iconColor: AfiCareTheme.canopy,
              iconBgColor: AfiCareTheme.canopy.withOpacity(0.08),
              onTap: () => _push(context, const PrescriptionsListScreen()),
            ),
            ActionCard(
              title: 'Medications',
              icon: Icons.check_circle_outline,
              iconColor: AfiCareTheme.sage,
              iconBgColor: AfiCareTheme.sage.withOpacity(0.1),
              onTap: () => _push(context, const MedicationTrackerScreen()),
            ),
            ActionCard(
              title: 'Lab results',
              subtitle: '1 new',
              icon: Icons.science_outlined,
              iconColor: const Color(0xFF3E7CA6),
              iconBgColor: const Color(0xFFEFF6FA),
              onTap: () => _push(context, const LabResultsScreen()),
            ),
            ActionCard(
              title: 'Health summary',
              icon: Icons.favorite_border,
              iconColor: const Color(0xFF7C5CB4),
              iconBgColor: const Color(0xFFF4EEFA),
              onTap: () => _push(context, const HealthSummary()),
            ),
            ActionCard(
              title: 'Share records',
              icon: Icons.qr_code,
              iconColor: AfiCareTheme.clay,
              iconBgColor: AfiCareTheme.clay.withOpacity(0.08),
              onTap: () => _push(context, const ShareRecords()),
            ),
            ActionCard(
              title: 'Expenses',
              icon: Icons.receipt_long_outlined,
              iconColor: AfiCareTheme.marigold,
              iconBgColor: AfiCareTheme.marigold.withOpacity(0.1),
              onTap: () => _push(context, const ExpensesScreen()),
            ),
          ],
        );
      },
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: const _ActivityList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList();

  @override
  Widget build(BuildContext context) {
    final consultations = Provider.of<PatientProvider>(context).consultations;
    final labs = Provider.of<LabProvider>(context).orders;

    final items = <_ActivityItem>[];

    for (final c in consultations.take(3)) {
      items.add(_ActivityItem(
        icon: Icons.medical_services_outlined,
        iconColor: const Color(0xFF206B5D),
        title: 'Visit - ${c.chiefComplaint.isNotEmpty ? c.chiefComplaint : 'Consultation'}',
        subtitle: DateFormat('MMM d, yyyy').format(c.timestamp),
      ));
    }

    for (final o in labs.take(2)) {
      if (items.length >= 5) break;
      items.add(_ActivityItem(
        icon: Icons.science_outlined,
        iconColor: const Color(0xFF3E7CA6),
        title: 'Lab: ${o.testName}',
        subtitle: o.isCompleted ? 'Completed' : o.isPending ? 'Pending' : '',
      ));
    }

    if (items.isEmpty) {
      items.addAll([
        const _ActivityItem(icon: Icons.info_outline, iconColor: Color(0xFF55708A), title: 'No recent activity', subtitle: ''),
      ]);
    }

    return Column(
      children: List.generate(items.length, (i) {
        return Column(
          children: [
            if (i > 0) const Divider(height: 1, indent: 66),
            ActivityRow(
              icon: items[i].icon,
              iconColor: items[i].iconColor,
              title: items[i].title,
              subtitle: items[i].subtitle,
              time: '',
            ),
          ],
        );
      }),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _ActivityItem({required this.icon, required this.iconColor, required this.title, required this.subtitle});
}

/// Allergy warning banner shown when the patient has recorded allergies.
class _AllergyBanner extends StatelessWidget {
  const _AllergyBanner({required this.allergies});
  final List<String> allergies;

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
              color: AfiCareTheme.emergencyRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AfiCareTheme.emergencyRed.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: AfiCareTheme.emergencyRed),
                const SizedBox(width: 6),
                Text(
                  'Allergy: $a',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AfiCareTheme.emergencyRed,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Patient's MediLink ID card — the digital identity shown at the top of
/// the dashboard.
class _MediLinkCard extends StatelessWidget {
  const _MediLinkCard({required this.fullName, required this.medilinkId});

  final String fullName;
  final String medilinkId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AfiCareTheme.canopy,
            AfiCareTheme.canopy2,
            Color(0xFF14335A),
          ],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x4864B5F6),
                    Colors.transparent,
                  ],
                  stops: [0, 0.65],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MEDILINK ID',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fullName,
                          style: GoogleFonts.fraunces(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          medilinkId,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AfiCareTheme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'P',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AfiCareTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _mediChip('Records owned by you'),
                  const SizedBox(width: 8),
                  _mediChip('Any facility'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

/// First-run checklist that nudges the patient toward a complete setup.
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({
    required this.hasAppointments,
    required this.hasMedications,
  });

  final bool hasAppointments;
  final bool hasMedications;

  @override
  Widget build(BuildContext context) {
    final done = [false, hasAppointments, hasMedications, false];
    final doneCount = done.where((d) => d).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Let's get you started",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                '$doneCount of 4',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AfiCareTheme.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: doneCount / 4,
              minHeight: 5,
              backgroundColor: AfiCareTheme.line,
              valueColor: const AlwaysStoppedAnimation<Color>(AfiCareTheme.sage),
            ),
          ),
          const SizedBox(height: 6),
          _ChecklistRow(
            label: 'Complete your health profile',
            done: done[0],
            onTap: () => context.go('/onboarding'),
          ),
          _ChecklistRow(
            label: 'Book your first appointment',
            done: done[1],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          _ChecklistRow(
            label: 'Add a medication',
            done: done[2],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()),
            ),
          ),
          _ChecklistRow(
            label: 'Set up sharing (QR code)',
            done: done[3],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareRecords()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AfiCareTheme.sage : Colors.transparent,
                border: Border.all(
                  color: done ? AfiCareTheme.sage : AfiCareTheme.line,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? AfiCareTheme.slate : AfiCareTheme.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AfiCareTheme.slate),
          ],
        ),
      ),
    );
  }
}

/// Reusable card container with consistent styling.
class AfiCareCard extends StatelessWidget {
  const AfiCareCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: child,
    );
  }
}

Container _iconBg(IconData icon, Color iconColor, Color bgColor) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 18, color: iconColor),
  );
}
