import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_preferences_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/theme.dart';
import 'widgets/patient_ui.dart';
import 'widgets/pin_account_dialogs.dart';

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
    final ok = await pp.save(prefs);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(pp.error ?? "We couldn't save that setting."),
          backgroundColor: Colors.red,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesPin = context.watch<AuthProvider>().usesPinLogin;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const PSubPageBar(title: 'Settings'),
      body: _isLoading
          ? const PLoadingPage()
          : Consumer<PreferencesProvider>(
              builder: (context, pp, _) {
                final prefs = pp.prefs ??
                    UserPreferencesModel(userId: '');
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    if (pp.loadFailed) ...[
                      PLoadError(what: 'your settings', onRetry: _retryLoad),
                      const SizedBox(height: 20),
                    ],
                    _sectionLabel('LANGUAGE'),
                    _card(
                      child: ListTile(
                        title: const Text('Language'),
                        subtitle: Text(_languageLabel(prefs.language)),
                        trailing: const Icon(Icons.expand_more),
                        onTap: () => _pickLanguage(prefs),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('ACCESSIBILITY'),
                    _card(
                      child: ListTile(
                        leading: Icon(Icons.accessibility_new,
                            color: AfiCareTheme.primaryGreen),
                        title: const Text('Accessibility'),
                        subtitle: Text(_accessibilitySummary(prefs)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/patient/accessibility'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('NOTIFICATIONS'),
                    // AfiCare's only alerts today are the medicine alarms
                    // set on the phone. There were Push / Email / SMS
                    // switches here that nothing read; they come back
                    // only when something actually sends those messages.
                    _card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.alarm,
                                color: AfiCareTheme.primaryGreen),
                            title: const Text('Medicine alarms'),
                            subtitle: const Text(
                                'Set them on the Medicine reminders page. '
                                'They ring on your phone, at the times you choose.'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.go('/patient/medication-reminders'),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "AfiCare doesn't send text messages (SMS) or "
                              'emails yet.',
                              style: TextStyle(fontSize: 13, color: PT.muted),
                            ),
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
                            title: Text(usesPin ? 'Change PIN' : 'Change Password'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: usesPin ? _changePin : _changePassword,
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
                              color: PT.muted, fontSize: 12)),
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
              color: PT.muted,
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

  // Only English is complete. Kiswahili covers the home page so far, and
  // says so. Français was offered but nothing was translated; anyone who
  // chose it sees English, which is what they were getting.
  static const _languages = {
    'en': 'English',
    'sw': 'Kiswahili',
  };

  String _languageLabel(String code) => code == 'sw'
      ? 'Kiswahili: only the home page so far, the rest is in English'
      : 'English';

  String _accessibilitySummary(UserPreferencesModel prefs) {
    final on = [
      if ((prefs.textScale - 1.0).abs() > 0.01)
        'text ${(prefs.textScale * 100).round()}%',
      if (prefs.boldText) 'bold text',
      if (prefs.effectiveTheme == AppThemePreference.highContrast)
        'high contrast',
      if (prefs.reduceMotion) 'reduce motion',
      if (prefs.textToSpeech) 'read aloud',
    ];
    return on.isEmpty
        ? 'Text size, bold text, high contrast, motion, read aloud'
        : 'On: ${on.join(', ')}';
  }

  Future<void> _retryLoad() async {
    final id = context.read<AuthProvider>().currentUser?.id;
    if (id != null) await context.read<PreferencesProvider>().loadPreferences(id);
  }

  void _pickLanguage(UserPreferencesModel prefs) {
    final current = prefs.language == 'sw' ? 'sw' : 'en';
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _languages.entries)
              ListTile(
                title: Text(entry.value),
                subtitle: entry.key == 'sw'
                    ? const Text(
                        'Only the home page is in Kiswahili so far.')
                    : null,
                trailing: current == entry.key
                    ? Icon(Icons.check, color: AfiCareTheme.primaryGreen)
                    : null,
                onTap: () {
                  Navigator.pop(sheet);
                  if (entry.key != prefs.language) {
                    _save(prefs.copyWith(language: entry.key));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    final changed = await showChangePinDialog(context);
    if (changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PIN changed. Use your new PIN next time you log in.'),
        backgroundColor: Colors.green,
      ));
    }
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
            : 'Could not send the reset link. Please try again.'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  // Deleting an account isn't built yet: health records can't simply be
  // wiped, and what happens to them needs deciding first. Until then this
  // says so plainly instead of claiming a request was sent.
  Future<void> _confirmDelete() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            "You can't delete your account from the app yet. "
            'Nothing has been deleted, and no request has been sent.\n\n'
            'If you want your account removed, ask the AfiCare team.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
