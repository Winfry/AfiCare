import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/medi_card.dart';
import '../../widgets/section_head.dart';
import '../../widgets/action_card.dart';
import '../../widgets/activity_row.dart';
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
    final user = auth.currentUser;
    final firstName = (user?.fullName ?? 'there').split(' ').first;

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          GreetingHeader(
            name: firstName,
            subtitle: '$dateStr · 1 appointment today',
          ),

          const SizedBox(height: 20),

          // MediLink Card
          MediCard(
            patientName: user?.fullName ?? 'Patient',
            mediLinkId: user?.medilinkId ?? 'ML-XXX-XXXX',
            dateOfBirth: user?.metadata?['date_of_birth']?.toString().substring(0, 10),
            bloodType: user?.metadata?['blood_type'] as String?,
          ),

          const SizedBox(height: 28),

          // Quick actions
          SectionHead(title: 'Quick actions'),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 3 : (constraints.maxWidth > 380 ? 2 : 2);
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
                    iconBgColor: AfiCareTheme.canopy.withValues(alpha: 0.08),
                    onTap: () => _push(context, const PrescriptionsListScreen()),
                  ),
                  ActionCard(
                    title: 'Medications',
                    icon: Icons.check_circle_outline,
                    iconColor: AfiCareTheme.sage,
                    iconBgColor: AfiCareTheme.sage.withValues(alpha: 0.1),
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
                    iconBgColor: AfiCareTheme.clay.withValues(alpha: 0.08),
                    onTap: () => _push(context, const ShareRecords()),
                  ),
                  ActionCard(
                    title: 'Expenses',
                    icon: Icons.receipt_long_outlined,
                    iconColor: AfiCareTheme.marigold,
                    iconBgColor: AfiCareTheme.marigold.withValues(alpha: 0.1),
                    onTap: () => _push(context, const ExpensesScreen()),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Recent activity
          SectionHead(
            title: 'Recent activity',
            actionText: 'See all',
            onAction: () {},
          ),

          const SizedBox(height: 8),

          // Activity list card
          Container(
            decoration: BoxDecoration(
              color: AfiCareTheme.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AfiCareTheme.line),
            ),
            child: Column(
              children: [
                ActivityRow(
                  icon: Icons.science_outlined,
                  iconColor: const Color(0xFF3E7CA6),
                  title: 'Lab results received',
                  subtitle: 'Complete blood count — Nairobi Hospital',
                  time: '2h ago',
                ),
                const Divider(height: 1, indent: 66),
                ActivityRow(
                  icon: Icons.medication_outlined,
                  iconColor: AfiCareTheme.canopy,
                  title: 'Prescription updated',
                  subtitle: 'Metformin 500mg — Dr. Otieno',
                  time: '1d ago',
                ),
                const Divider(height: 1, indent: 66),
                ActivityRow(
                  icon: Icons.reorder_outlined,
                  iconColor: AfiCareTheme.marigold,
                  title: 'Referral sent',
                  subtitle: 'To Kenyatta National Hospital',
                  time: '3d ago',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
