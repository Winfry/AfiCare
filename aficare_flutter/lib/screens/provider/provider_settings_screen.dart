import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../common/notifications_screen.dart';
import 'patient_access.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  String _selectedLanguage = 'English (default)';
  String _selectedTheme = 'System default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('provider_language') ?? 'English (default)';
      _selectedTheme = prefs.getString('provider_theme') ?? 'System default';
    });
  }

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
                _settingTile(
                  Icons.notifications,
                  'Notifications',
                  'Manage alerts and reminders',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(userRole: 'provider'),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _settingTile(
                  Icons.security,
                  'Privacy & Security',
                  'Access codes and permissions',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientAccess()),
                  ),
                ),
                const Divider(height: 1),
                _settingTile(Icons.language, 'Language', _selectedLanguage, () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Language'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharedPreferences.getInstance()
                                .then((p) => p.setString('provider_language', 'English (default)'));
                            setState(() => _selectedLanguage = 'English (default)');
                          },
                          child: Row(
                            children: [
                              if (_selectedLanguage == 'English (default)')
                                const Icon(Icons.check, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text('English (default)'),
                            ],
                          ),
                        ),
                        SimpleDialogOption(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharedPreferences.getInstance()
                                .then((p) => p.setString('provider_language', 'Swahili'));
                            setState(() => _selectedLanguage = 'Swahili');
                          },
                          child: Row(
                            children: [
                              if (_selectedLanguage == 'Swahili')
                                const Icon(Icons.check, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text('Swahili'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 1),
                _settingTile(Icons.dark_mode, 'Theme', _selectedTheme, () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Theme'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharedPreferences.getInstance()
                                .then((p) => p.setString('provider_theme', 'System default'));
                            setState(() => _selectedTheme = 'System default');
                          },
                          child: Row(
                            children: [
                              if (_selectedTheme == 'System default')
                                const Icon(Icons.check, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text('System default'),
                            ],
                          ),
                        ),
                        SimpleDialogOption(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharedPreferences.getInstance()
                                .then((p) => p.setString('provider_theme', 'Light'));
                            setState(() => _selectedTheme = 'Light');
                          },
                          child: Row(
                            children: [
                              if (_selectedTheme == 'Light')
                                const Icon(Icons.check, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text('Light'),
                            ],
                          ),
                        ),
                        SimpleDialogOption(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SharedPreferences.getInstance()
                                .then((p) => p.setString('provider_theme', 'Dark'));
                            setState(() => _selectedTheme = 'Dark');
                          },
                          child: Row(
                            children: [
                              if (_selectedTheme == 'Dark')
                                const Icon(Icons.check, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text('Dark'),
                            ],
                          ),
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
                _settingTile(Icons.info_outline, 'About AfiCare MediLink', 'Version 1.0.0', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'AfiCare MediLink',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Secure digital health records for Africa.',
                  );
                }),
                const Divider(height: 1),
                _settingTile(Icons.description_outlined, 'Terms of Service', '', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Terms of Service',
                    applicationLegalese: 'Your health data belongs to you. '
                        'Access is always consent-based and fully audited.',
                  );
                }),
                const Divider(height: 1),
                _settingTile(Icons.privacy_tip_outlined, 'Privacy Policy', '', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Privacy Policy',
                    applicationLegalese: 'AfiCare stores encrypted medical records and '
                        'never shares them without your explicit consent.',
                  );
                }),
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
