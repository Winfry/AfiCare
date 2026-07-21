import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_preferences_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../utils/theme.dart';

/// B20 — Settings (Patient)
class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pp = Provider.of<PreferencesProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null) await pp.loadPreferences(id);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save(UserPreferencesModel prefs) async {
    final pp = Provider.of<PreferencesProvider>(context, listen: false);
    await pp.save(prefs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<PreferencesProvider>(
              builder: (context, pp, _) {
                final prefs = pp.prefs ??
                    UserPreferencesModel(userId: '');
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionLabel('APPEARANCE'),
                    _card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Theme',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                SegmentedButton<AppThemePreference>(
                                  segments: const [
                                    ButtonSegment(
                                        value: AppThemePreference.light,
                                        label: Text('Light')),
                                    ButtonSegment(
                                        value: AppThemePreference.dark,
                                        label: Text('Dark')),
                                    ButtonSegment(
                                        value:
                                            AppThemePreference.highContrast,
                                        label: Text('Contrast')),
                                  ],
                                  selected: {prefs.theme},
                                  onSelectionChanged: (s) =>
                                      _save(prefs.copyWith(theme: s.first)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('Language'),
                            subtitle: Text(_languageLabel(prefs.language)),
                            trailing: const Icon(Icons.expand_more),
                            onTap: () => _pickLanguage(prefs),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('NOTIFICATIONS'),
                    _card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: Icon(Icons.notifications,
                                color: AfiCareTheme.primaryGreen),
                            title: const Text('Push Notifications'),
                            value: prefs.notificationsEnabled,
                            onChanged: (v) => _save(prefs.copyWith(
                                notificationsEnabled: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(Icons.email,
                                color: AfiCareTheme.primaryGreen),
                            title: const Text('Email Updates'),
                            value: prefs.emailNotifications,
                            onChanged: (v) => _save(
                                prefs.copyWith(emailNotifications: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(Icons.sms,
                                color: AfiCareTheme.primaryGreen),
                            title: const Text('SMS Alerts'),
                            value: prefs.smsNotifications,
                            onChanged: (v) =>
                                _save(prefs.copyWith(smsNotifications: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('ACCOUNT'),
                    _card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: const Text('Change Password'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _changePassword,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            title: const Text('Delete Account',
                                style: TextStyle(color: Colors.red)),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.red),
                            onTap: _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('ABOUT'),
                    _card(
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('App Version'),
                            trailing: Text('v1.0.0'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('Licenses & Terms'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => showLicensePage(
                                context: context,
                                applicationName: 'AfiCare'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text('AfiCare MediLink',
                          style: TextStyle(
                              color: AfiCareTheme.primaryGreen
                                  .withOpacity(0.6),
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text('© 2026 AfiCare Health Systems',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'sw':
        return 'Kiswahili';
      case 'fr':
        return 'Français';
      default:
        return 'English (US)';
    }
  }

  void _pickLanguage(UserPreferencesModel prefs) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in {
            'en': 'English (US)',
            'sw': 'Kiswahili',
            'fr': 'Français',
          }.entries)
            ListTile(
              title: Text(entry.value),
              trailing: prefs.language == entry.key
                  ? Icon(Icons.check, color: AfiCareTheme.primaryGreen)
                  : null,
              onTap: () {
                _save(prefs.copyWith(language: entry.key));
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.currentUser?.email;
    if (email == null) return;
    final ok = await auth.resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Password reset link sent to $email'
            : 'Could not send reset link'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently remove your account and records. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account deletion requested. Contact support.')));
    }
  }
}
