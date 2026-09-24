import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/kmpdc_practitioner_model.dart';
import '../../providers/kmpdc_verification_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

/// Verification — the last item from the original facility-admin
/// mockup. Looks a doctor/dentist up against a local mirror of KMPDC's
/// PUBLIC register (kmpdc_practitioners, refreshed by
/// sync-kmpdc-register). Unofficial: KMPDC publishes no documented API,
/// so this is informational only -- it does NOT touch
/// provider_credentials.verification_status, which remains the sole,
/// platform-admin-only source of truth for platform trust. This screen
/// only ever answers "what does KMPDC's public data currently say."
class VerificationTab extends StatefulWidget {
  const VerificationTab({super.key});

  @override
  State<VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends State<VerificationTab> {
  final _nameCtl = TextEditingController();
  final _licenseCtl = TextEditingController();
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    // Lazy, on-open sync -- matches this codebase's established
    // convention (e.g. loadPatientAppointments) of only loading a
    // screen's own data when it's actually opened, not from the shell's
    // initState. Safe to call every time this tab is opened: the Edge
    // Function itself no-ops if the mirror is still fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KmpdcVerificationProvider>().triggerSync();
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _licenseCtl.dispose();
    super.dispose();
  }

  void _search() {
    if (_nameCtl.text.trim().isEmpty) return;
    setState(() => _searched = true);
    context.read<KmpdcVerificationProvider>().search(
          name: _nameCtl.text.trim(),
          licenseNumber: _licenseCtl.text.trim().isEmpty ? null : _licenseCtl.text.trim(),
        );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KmpdcVerificationProvider>();
    final licenseText = _licenseCtl.text.trim();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Verification', style: Theme.of(context).textTheme.headlineSmall)),
              if (provider.isSyncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              Text(
                provider.lastSyncedAt == null ? 'Not yet synced' : 'Last synced: ${_relativeTime(provider.lastSyncedAt!)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh KMPDC data',
                onPressed: provider.isSyncing ? null : () => context.read<KmpdcVerificationProvider>().triggerSync(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.mistBackground, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Checked against KMPDC\'s public register (unofficial, not a live government API). Verify independently for anything high-stakes.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: _cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        decoration: const InputDecoration(labelText: 'Doctor / Dentist Full Name', isDense: true),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _licenseCtl,
                        decoration: const InputDecoration(labelText: 'License / Registration No. (optional)', isDense: true),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _search,
                  icon: Icon(Icons.search, size: 18, color: AppColors.deepNavy),
                  label: Text(
                    'Check KMPDC',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.deepNavy, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.marigold,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !_searched
                ? Center(child: Text('Enter a name to check against KMPDC\'s register', style: Theme.of(context).textTheme.bodySmall))
                : provider.isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : provider.results.isEmpty
                        ? Center(child: Text('No match found in KMPDC\'s public register', style: Theme.of(context).textTheme.bodySmall))
                        : ListView.separated(
                            itemCount: provider.results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _resultRow(context, provider, provider.results[i], licenseText),
                          ),
          ),
        ],
      ),
    );
  }

  static const _cadreLabels = {
    'medical_doctor': 'Medical Doctor',
    'dentist': 'Dentist',
    'medical_intern': 'Medical Intern (Provisional)',
    'dental_intern': 'Dental Intern (Provisional)',
  };

  Widget _resultRow(BuildContext context, KmpdcVerificationProvider provider, KmpdcPractitionerModel r, String licenseText) {
    final isIntern = r.cadre == 'medical_intern' || r.cadre == 'dental_intern';
    final active = (r.status ?? '').toUpperCase() == 'ACTIVE';
    final hasLicenseInput = licenseText.isNotEmpty;
    final patternMatches = hasLicenseInput && provider.matchesLicensePattern(r, licenseText);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.fullName, style: Theme.of(context).textTheme.titleSmall)),
              if (isIntern)
                _chip(context, 'Interning', AppColors.steel)
              else
                _chip(context, r.status ?? 'Unknown', active ? AppColors.sage : AppColors.emergency),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isIntern
                ? (_cadreLabels[r.cadre] ?? r.cadre)
                : '${_cadreLabels[r.cadre] ?? r.cadre} · Reg. No. ${r.maskedRegistrationNo ?? 'Unknown'} · ${r.licenseType ?? 'Unknown license type'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (r.qualifications != null && r.qualifications!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.qualifications!, style: Theme.of(context).textTheme.labelSmall),
          ],
          if (isIntern) ...[
            const SizedBox(height: 8),
            Text(
              "KMPDC does not publish a registration number for interns — matched by name only.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ] else if (hasLicenseInput) ...[
            const SizedBox(height: 8),
            _chip(
              context,
              patternMatches ? 'Pattern matches ID on file' : 'Pattern does NOT match ID on file',
              patternMatches ? AppColors.sage : AppColors.clay,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
