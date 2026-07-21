import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  int _selectedTab = 0;

  static const _tabs = ['General', 'Security', 'Notifications', 'Integrations', 'Subscription'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<SystemSettingsProvider>();
      final auth = context.read<AuthProvider>();
      await provider.loadSettings();
      if (provider.settings.isEmpty && auth.currentUser != null) {
        await provider.initDefaults(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemSettingsProvider>();
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: AfiCareTheme.adminColor,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : isWide ? _buildWideLayout(context, provider) : _buildNarrowLayout(context, provider),
    );
  }

  Widget _buildWideLayout(BuildContext context, SystemSettingsProvider provider) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedTab,
          onDestinationSelected: (i) => setState(() => _selectedTab = i),
          labelType: NavigationRailLabelType.all,
          destinations: _tabs.map((t) => NavigationRailDestination(
            icon: Icon(_tabIcon(t)),
            label: Text(t),
          )).toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildTabContent(context, provider)),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, SystemSettingsProvider provider) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(_tabs.length, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(_tabs[i]),
                selected: _selectedTab == i,
                onSelected: (_) => setState(() => _selectedTab = i),
              ),
            )),
          ),
        ),
        Expanded(child: _buildTabContent(context, provider)),
      ],
    );
  }

  IconData _tabIcon(String tab) {
    switch (tab) {
      case 'General': return Icons.settings;
      case 'Security': return Icons.lock;
      case 'Notifications': return Icons.notifications;
      case 'Integrations': return Icons.api;
      case 'Subscription': return Icons.card_membership;
      default: return Icons.settings;
    }
  }

  Widget _buildTabContent(BuildContext context, SystemSettingsProvider provider) {
    switch (_tabs[_selectedTab]) {
      case 'General': return _buildGeneralTab(context, provider);
      case 'Security': return _buildSecurityTab(context, provider);
      case 'Notifications': return _buildNotificationsTab(context, provider);
      case 'Integrations': return _buildIntegrationsTab(context, provider);
      case 'Subscription': return _buildSubscriptionTab(context, provider);
      default: return const SizedBox();
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchRow(SystemSettingsProvider provider, String category, String key, String label, {bool defaultValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Switch(
            value: provider.getBool(category, key, defaultValue: defaultValue),
            onChanged: (v) => _save(provider, category, key, v),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(SystemSettingsProvider provider, String category, String key, String label, {bool obscure = false}) {
    final ctl = TextEditingController(text: provider.getString(category, key));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(labelText: label, isDense: true, suffixIcon: IconButton(
          icon: const Icon(Icons.save, size: 18),
          onPressed: () => _save(provider, category, key, ctl.text),
        )),
        obscureText: obscure,
      ),
    );
  }

  Widget _buildNumberField(SystemSettingsProvider provider, String category, String key, String label) {
    final ctl = TextEditingController(text: provider.getString(category, key));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(labelText: label, isDense: true, suffixIcon: IconButton(
          icon: const Icon(Icons.save, size: 18),
          onPressed: () => _save(provider, category, key, int.tryParse(ctl.text) ?? 0),
        )),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context, SystemSettingsProvider provider) {
    return _buildSection('General Settings', [
      _buildTextFieldRow(provider, 'general', 'app_name', 'Application Name'),
      _buildTextFieldRow(provider, 'general', 'app_version', 'Version'),
      _buildSwitchRow(provider, 'general', 'maintenance_mode', 'Maintenance Mode'),
    ]);
  }

  Widget _buildSecurityTab(BuildContext context, SystemSettingsProvider provider) {
    return _buildSection('Security Settings', [
      _buildNumberField(provider, 'security', 'min_password_length', 'Minimum Password Length'),
      _buildSwitchRow(provider, 'security', 'mfa_enabled', 'Multi-Factor Authentication'),
      _buildNumberField(provider, 'security', 'session_timeout_minutes', 'Session Timeout (minutes)'),
    ]);
  }

  Widget _buildNotificationsTab(BuildContext context, SystemSettingsProvider provider) {
    return _buildSection('Notification Settings', [
      _buildTextFieldRow(provider, 'notifications', 'smtp_host', 'SMTP Host'),
      _buildNumberField(provider, 'notifications', 'smtp_port', 'SMTP Port'),
      _buildSwitchRow(provider, 'notifications', 'push_enabled', 'Push Notifications'),
    ]);
  }

  Widget _buildIntegrationsTab(BuildContext context, SystemSettingsProvider provider) {
    return _buildSection('Integration Settings', [
      _buildTextFieldRow(provider, 'integrations', 'api_base_url', 'API Base URL'),
      _buildTextFieldRow(provider, 'integrations', 'webhook_url', 'Webhook URL'),
    ]);
  }

  Widget _buildSubscriptionTab(BuildContext context, SystemSettingsProvider provider) {
    return _buildSection('Subscription', [
      _buildTextFieldRow(provider, 'subscription', 'plan', 'Plan'),
      _buildTextFieldRow(provider, 'subscription', 'billing_email', 'Billing Email'),
    ]);
  }

  void _save(SystemSettingsProvider provider, String category, String key, dynamic value) async {
    final auth = context.read<AuthProvider>();
    await provider.saveSetting(
      category, key, value,
      userId: auth.currentUser?.id,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
      );
    }
  }
}