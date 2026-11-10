import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/patient_tokens.dart';
import 'patient_profile_edit_screen.dart';
import 'patient_settings_screen.dart';
import 'widgets/patient_photo_avatar.dart';
import 'widgets/patient_ui.dart';

/// Profile & MediLink ID page, reached from the More page (/patient/profile).
///
/// This is the account holder's own page (her name, ID, settings, log
/// out), so it is adult-only in the nav: on a child's profile it used to
/// show the parent's name and ID under the child's banner. A child's
/// MediLink ID is on People I care for.
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return PDetailScaffold(
      eyebrow: 'Who you are here',
      title: 'Profile & MediLink ID',
      subtitle: 'Your details, and the ID that links your care together across facilities.',
      children: [
        PCard(
          child: Column(
            children: [
              PatientPhotoAvatar(name: user?.fullName ?? '', storedPhoto: user?.photoUrl),
              const SizedBox(height: 12),
              Text(
                user?.fullName ?? 'Patient',
                textAlign: TextAlign.center,
                style: PT.section(),
              ),
              const SizedBox(height: 4),
              SelectableText(
                user?.medilinkId ?? user?.email ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: PT.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            children: [
              PRow(
                leadingEmoji: '✏️',
                title: 'Edit profile',
                subtitle: 'Name, date of birth, allergies, emergency contact',
                trailing: [Icon(Icons.chevron_right, color: PT.muted)],
                onTap: () => _push(context, const PatientProfileEditScreen()),
              ),
              PRow(
                leadingEmoji: '⚙️',
                title: 'Settings',
                subtitle: 'Your account, notifications and display',
                trailing: [Icon(Icons.chevron_right, color: PT.muted)],
                onTap: () => _push(context, const PatientSettingsScreen()),
              ),
              PRow(
                leadingEmoji: '🩺',
                title: 'Become a verified provider',
                subtitle: 'For doctors, nurses and other health workers',
                trailing: [Icon(Icons.chevron_right, color: PT.muted)],
                onTap: () => context.push('/verify-provider'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PButton(
          'Log out',
          kind: PButtonKind.alt,
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
