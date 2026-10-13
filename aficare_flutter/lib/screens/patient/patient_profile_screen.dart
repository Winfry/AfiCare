import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import 'patient_profile_edit_screen.dart';
import 'patient_settings_screen.dart';
import 'widgets/patient_ui.dart';

/// Profile & MediLink ID page, reached from the More page (/patient/profile).
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
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.1),
              child: Icon(Icons.person,
                  size: 48, color: AfiCareTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(user?.fullName ?? 'Patient',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Center(
            child: Text(user?.medilinkId ?? user?.email ?? '',
                style: TextStyle(color: Colors.grey[600])),
          ),
          const SizedBox(height: 24),
          _tile(context, Icons.edit, 'Edit Profile',
              () => _push(context, const PatientProfileEditScreen())),
          _tile(context, Icons.settings, 'Settings',
              () => _push(context, const PatientSettingsScreen())),
          _tile(context, Icons.badge_outlined, 'Become a Verified Provider',
              () => context.push('/verify-provider')),
          const Divider(),
          _tile(
            context,
            Icons.logout,
            'Log Out',
            () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label,
      VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AfiCareTheme.primaryGreen),
      title: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
