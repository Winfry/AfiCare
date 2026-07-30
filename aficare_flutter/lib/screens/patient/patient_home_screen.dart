import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/triage_provider.dart';
import '../../providers/adherence_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../models/appointment_model.dart';
import '../../models/adherence_model.dart';
import '../../models/triage_model.dart';
import '../../widgets/section_head.dart';
import '../../widgets/action_card.dart';
import '../../widgets/activity_row.dart';
import '../../utils/theme.dart';
import '../../utils/app_strings.dart';
import 'health_summary.dart';
import 'share_records.dart';
import 'expenses_screen.dart';
import 'lab_results_screen.dart';
import 'medication_tracker_screen.dart';
import 'prescriptions_list_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appointments = Provider.of<AppointmentProvider>(context);
    final triage = Provider.of<TriageProvider>(context);
    final adherence = Provider.of<AdherenceProvider>(context);
    final prefs = Provider.of<PreferencesProvider>(context);

    final user = auth.currentUser;
    final lang = prefs.prefs?.language ?? 'en';
    final firstName = (user?.fullName ?? 'there').split(' ').first;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', lang == 'sw' ? 'sw' : 'en').format(now);

    final nextAppt = _nextAppointment(appointments.appointments);
    final vitals = triage.getLatestAssessment(user?.id ?? '');
    final todayMeds = adherence.todayDoses;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingRow(
            name: firstName,
            date: dateStr,
            lang: lang,
            onToggleLanguage: () => _toggleLanguage(context, prefs),
          ),
          const SizedBox(height: 20),
          _AppointmentCard(appointment: nextAppt, lang: lang, userId: user?.id ?? ''),
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
          _RecentActivityCard(),
          const SizedBox(height: 24),
        ],
      ),
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
    final upcoming = all.where((a) =>
        a.scheduledAt.isAfter(DateTime.now()) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.completed).toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isNotEmpty ? upcoming.first : null;
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
            _buildVitals(assessment!)
          else
            Text(AppStrings.noVitals(lang), style: const TextStyle(fontSize: 14, color: Color(0xFF55708A))),
        ],
      ),
    );
  }

  Widget _buildVitals(TriageAssessment v) {
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
  const _MedicationCard({required this.mediations, required this.lang});

  final List<AdherenceLogModel> mediations;
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
              Text(AppStrings.mediationsTitle(lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF152A45))),
            ],
          ),
          const SizedBox(height: 16),
          if (mediations.isNotEmpty)
            ...mediations.map((m) => _MedRow(med: m, lang: lang))
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
        _ActivityItem(icon: Icons.info_outline, iconColor: const Color(0xFF55708A), title: 'No recent activity', subtitle: ''),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
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
      ),
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

Icon _iconBg(IconData icon, Color iconColor, Color bgColor) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 18, color: iconColor),
  );
}
