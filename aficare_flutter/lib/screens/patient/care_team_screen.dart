import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/care_team_member_model.dart';
import '../../providers/care_team_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// Care Team — the people involved in this patient's care. Reads the
/// existing [CareTeamProvider]; no new backend. Until now the care team
/// only ever appeared as a single-member card on Home and Appointments,
/// so there was nowhere to see the full list.
class CareTeamScreen extends StatefulWidget {
  const CareTeamScreen({super.key});

  @override
  State<CareTeamScreen> createState() => _CareTeamScreenState();
}

class _CareTeamScreenState extends State<CareTeamScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<DependentProvider>().activePatientId;
      if (id != null && mounted) context.read<CareTeamProvider>().loadCareTeam(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ct = context.watch<CareTeamProvider>();
    final members = ct.members;

    return Scaffold(
      backgroundColor: PT.page,
      appBar: AppBar(
        backgroundColor: PT.page,
        surfaceTintColor: PT.page,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: PT.ink),
          onPressed: () => context.go('/patient'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PT.maxContentWidth),
            child: PScreen(
              eyebrow: 'Your care',
              title: 'Care Team',
              subtitle: 'People involved in your care.',
              children: [
                if (ct.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: PT.teal)),
                  )
                else if (members.isEmpty)
                  PCard(
                    child: PEmpty(
                      emoji: '👩🏾‍⚕️',
                      title: 'No care team yet',
                      body: 'Providers you see will appear here so you can message or book with them quickly.',
                      action: PButton(
                        'Book an appointment',
                        onPressed: () => context.go('/patient/appointments'),
                      ),
                    ),
                  )
                else
                  PGrid(
                    columns: 2,
                    children: [for (final m in members) _memberCard(m)],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberCard(CareTeamMemberModel m) {
    final specialty = m.specialtyLabel ?? m.providerDepartment ?? m.providerRole;
    final name = m.providerName.trim().isEmpty ? (m.specialtyLabel ?? 'Care team member') : m.providerName;

    return PCard(
      child: PRow(
        leading: PAvatar(
          initials: _initials(name),
          size: 40,
          photoUrl: m.providerPhotoUrl,
        ),
        title: name,
        subtitle: _capitalize(specialty) + (m.isPrimary ? ' · Primary' : ''),
        trailing: [
          PButton(
            'Message',
            kind: PButtonKind.alt,
            dense: true,
            onPressed: () => context.go('/patient/messages'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
