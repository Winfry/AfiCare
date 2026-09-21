import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/facility_model.dart';
import '../../models/user_preferences_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

/// Settings — the last item from the original facility-admin mockup.
///
/// "My Account" reuses PreferencesProvider/user_preferences exactly as
/// patient_settings_screen.dart does -- already loaded globally in
/// main.dart for any authenticated user, no new plumbing. Deliberately
/// excludes the color-theme toggle: facility-admin screens are built on
/// hardcoded AppColors constants (the warm palette + permanently-dark
/// sidebar decided earlier this project), not Theme.of(context), so
/// flipping themeMode would only shift text styles while every card/
/// border/background stayed fixed -- a visibly broken half-dark UI.
/// Also excludes language and notification toggles: confirmed by grep
/// that nothing in this codebase reads those fields to do anything --
/// a toggle that saves a value nothing acts on is exactly the kind of
/// fabricated feature this project has consistently avoided.
///
/// "Team" is view-only: who else administers this facility
/// (AdminFacilityProvider.loadFacilityAdmins, already existed, just
/// never had RLS visibility beyond the caller's own row until
/// 028_facility_admins_visibility.sql). Granting/revoking facility-admin
/// access stays platform-admin-only, a deliberate boundary from
/// 013_facility_admins.sql that this screen does not attempt to reverse.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.facility});
  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    final prefsProvider = context.watch<PreferencesProvider>();
    final adminProvider = context.watch<AdminFacilityProvider>();
    final authProvider = context.watch<AuthProvider>();
    final prefs = prefsProvider.prefs ?? UserPreferencesModel(userId: authProvider.currentUser?.id ?? '');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _accountCard(context, prefs, prefsProvider, authProvider),
                  const SizedBox(height: 16),
                  _teamCard(context, adminProvider, authProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          child,
        ],
      ),
    );
  }

  Widget _accountCard(
    BuildContext context,
    UserPreferencesModel prefs,
    PreferencesProvider prefsProvider,
    AuthProvider authProvider,
  ) {
    return _sectionCard(
      context,
      title: 'My Account',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Text Size', style: Theme.of(context).textTheme.titleSmall),
                    Text('${(prefs.textScale * 100).round()}%', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                Slider(
                  value: prefs.textScale.clamp(0.85, 1.6),
                  min: 0.85,
                  max: 1.6,
                  divisions: 15,
                  activeColor: AppColors.adminColor,
                  onChanged: (v) => prefsProvider.save(prefs.copyWith(textScale: v)),
                ),
                Text(
                  'Live preview — Facility Overview',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 13 * prefs.textScale, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.borderSubtle),
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off_outlined),
            title: const Text('Reduce motion'),
            subtitle: const Text('Minimise animations and transitions'),
            value: prefs.reduceMotion,
            onChanged: (v) => prefsProvider.save(prefs.copyWith(reduceMotion: v)),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            subtitle: const Text('Send a password reset link to your email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context, authProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, AuthProvider authProvider) async {
    final email = authProvider.currentUser?.email;
    if (email == null) return;
    final ok = await authProvider.resetPassword(email);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Password reset link sent to $email' : 'Could not send reset link')),
      );
    }
  }

  Widget _teamCard(BuildContext context, AdminFacilityProvider adminProvider, AuthProvider authProvider) {
    final admins = adminProvider.facilityAdmins;
    final myUserId = authProvider.currentUser?.id;

    return _sectionCard(
      context,
      title: 'Team',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          admins.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No facility admins found', style: Theme.of(context).textTheme.bodySmall),
                )
              : Column(
                  children: admins.map((a) => _teamRow(context, a, isSelf: a['user_id'] == myUserId)).toList(),
                ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text(
              'Contact your platform admin to add or remove facility administrators.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamRow(BuildContext context, Map<String, dynamic> admin, {required bool isSelf}) {
    final name = admin['full_name'] as String? ?? 'Unknown';
    final email = admin['email'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.tintNavyBg,
            child: Icon(Icons.person_outline, size: 16, color: AppColors.tintNavyFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(email, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.sage.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Text('You', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.sage, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
