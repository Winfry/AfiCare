import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.15),
                    child: Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AfiCareTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Provider',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (user?.department != null)
                          Text(
                            user!.department!,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings items
          Card(
            child: Column(
              children: [
                _settingTile(Icons.notifications, 'Notifications', 'Manage alerts and reminders',
                    () {}),
                const Divider(height: 1),
                _settingTile(Icons.security, 'Privacy & Security', 'Access codes and permissions',
                    () {}),
                const Divider(height: 1),
                _settingTile(Icons.language, 'Language', 'English (default)', () {}),
                const Divider(height: 1),
                _settingTile(Icons.dark_mode, 'Theme', 'System default', () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Theme'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(ctx); },
                          child: const Text('System default'),
                        ),
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(ctx); },
                          child: const Text('Light'),
                        ),
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(ctx); },
                          child: const Text('Dark'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About
          Card(
            child: Column(
              children: [
                _settingTile(Icons.info_outline, 'About AfiCare MediLink', 'Version 1.0.0', () {}),
                const Divider(height: 1),
                _settingTile(Icons.description_outlined, 'Terms of Service', '', () {}),
                const Divider(height: 1),
                _settingTile(Icons.privacy_tip_outlined, 'Privacy Policy', '', () {}),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _settingTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AfiCareTheme.primaryBlue),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
