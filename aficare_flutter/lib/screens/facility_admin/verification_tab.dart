import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/kmpdc_practitioner_model.dart';
import '../../models/nck_nurse_model.dart';
import '../../providers/kmpdc_verification_provider.dart';
import '../../providers/nck_verification_provider.dart';
import '../../theme/app_colors.dart';

const _cardShadow = [
  BoxShadow(color: Color(0x0D1B1B18), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1B1B18), blurRadius: 18, offset: Offset(0, 6)),
];

/// Verification — the last item from the original facility-admin
/// mockup. Looks a doctor/dentist up against a local mirror of KMPDC's
/// PUBLIC register (kmpdc_practitioners, refreshed by
/// sync-kmpdc-register), and a nurse up against a LIVE, per-query
/// check against NCK's public register (verify-nck-register) -- NCK's
/// own site is already a search endpoint, unlike KMPDC's bulk pages, so
/// there is no local mirror/staleness for that half. One name box
/// searches both, since a facility admin usually doesn't know in
/// advance which register the person is on.
///
/// Unofficial: neither body publishes a documented API, so this is
/// informational only -- it does NOT touch
/// provider_credentials.verification_status, which remains the sole,
/// platform-admin-only source of truth for platform trust. This screen
/// only ever answers "what do KMPDC's and NCK's public data currently
/// say."
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
    // Function itself no-ops if the mirror is still fresh. NCK has no
    // equivalent -- every search is already live, nothing to pre-sync.
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
    final name = _nameCtl.text.trim();
    final license = _licenseCtl.text.trim().isEmpty ? null : _licenseCtl.text.trim();
    context.read<KmpdcVerificationProvider>().search(name: name, licenseNumber: license);
    context.read<NckVerificationProvider>().search(name: name);
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
    final kmpdc = context.watch<KmpdcVerificationProvider>();
    final nck = context.watch<NckVerificationProvider>();
    final licenseText = _licenseCtl.text.trim();
    final isLoading = kmpdc.isSearching || nck.isSearching;
    final hasAnyResults = kmpdc.results.isNotEmpty || nck.results.isNotEmpty;
    final bothErrored = kmpdc.error != null && nck.error != null && !hasAnyResults;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Verification', style: Theme.of(context).textTheme.headlineSmall)),
              if (kmpdc.isSyncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              Text(
                kmpdc.lastSyncedAt == null ? 'KMPDC not yet synced' : 'KMPDC synced: ${_relativeTime(kmpdc.lastSyncedAt!)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh KMPDC data',
                onPressed: kmpdc.isSyncing ? null : () => context.read<KmpdcVerificationProvider>().triggerSync(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.mistBackground, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Checked against KMPDC\'s public register (doctors/dentists, periodically refreshed) and NCK\'s public register '
              '(nurses, checked live). Unofficial -- neither is a documented government API. Verify independently for anything high-stakes.',
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
                        decoration: const InputDecoration(labelText: 'Full Name (doctor, dentist or nurse)', isDense: true),
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
                    'Check KMPDC & NCK',
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
                ? Center(child: Text('Enter a name to check against KMPDC\'s and NCK\'s registers', style: Theme.of(context).textTheme.bodySmall))
                : isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : bothErrored
                        ? Center(child: Text('Could not reach KMPDC or NCK right now. Please try again.', style: Theme.of(context).textTheme.bodySmall))
                        : !hasAnyResults
                            ? Center(child: Text('No match found in KMPDC\'s or NCK\'s public registers', style: Theme.of(context).textTheme.bodySmall))
                            : ListView(
                                children: [
                                  if (kmpdc.error != null)
                                    _sourceErrorBanner('Could not check KMPDC\'s register right now.'),
                                  if (nck.error != null) _sourceErrorBanner('Could not check NCK\'s register right now.'),
                                  ...kmpdc.results.map((r) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _kmpdcRow(context, kmpdc, r, licenseText),
                                      )),
                                  ...nck.results.map((r) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _nckRow(context, nck, r, licenseText),
                                      )),
                                ],
                              ),
          ),
        ],
      ),
    );
  }

  Widget _sourceErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.clay.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.clay)),
      ),
    );
  }

  static const _cadreLabels = {
    'medical_doctor': 'Medical Doctor',
    'dentist': 'Dentist',
    'medical_intern': 'Medical Intern (Provisional)',
    'dental_intern': 'Dental Intern (Provisional)',
  };

  Widget _sourceTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.steel.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.steel)),
    );
  }

  Widget _kmpdcRow(BuildContext context, KmpdcVerificationProvider provider, KmpdcPractitionerModel r, String licenseText) {
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
              _sourceTag('KMPDC'),
              const SizedBox(width: 8),
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

  Widget _nckRow(BuildContext context, NckVerificationProvider provider, NckNurseModel r, String licenseText) {
    final active = (r.status ?? '').toUpperCase() == 'ACTIVE';
    final hasLicenseInput = licenseText.isNotEmpty;
    final exactMatches = hasLicenseInput && provider.matchesLicense(r, licenseText);

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
              _sourceTag('NCK'),
              const SizedBox(width: 8),
              Expanded(child: Text(r.fullName, style: Theme.of(context).textTheme.titleSmall)),
              _chip(context, r.status ?? 'Unknown', active ? AppColors.sage : AppColors.emergency),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nurse · License No. ${r.licenseNumber}${r.validTill != null ? ' · Valid till ${r.validTill}' : ''}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (hasLicenseInput) ...[
            const SizedBox(height: 8),
            _chip(
              context,
              exactMatches ? 'License number matches ID on file' : 'License number does NOT match ID on file',
              exactMatches ? AppColors.sage : AppColors.clay,
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
