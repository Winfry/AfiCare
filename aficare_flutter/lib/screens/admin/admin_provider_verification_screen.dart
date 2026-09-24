import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/provider_verification_provider.dart';
import '../../providers/kmpdc_verification_provider.dart';
import '../../models/provider_credential_model.dart';
import '../../models/kmpdc_practitioner_model.dart';
import '../../utils/theme.dart';

class AdminProviderVerificationScreen extends StatefulWidget {
  const AdminProviderVerificationScreen({super.key});

  @override
  State<AdminProviderVerificationScreen> createState() => _AdminProviderVerificationScreenState();
}

class _AdminProviderVerificationScreenState extends State<AdminProviderVerificationScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderVerificationProvider>().loadRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProviderVerificationProvider>();
    final filtered = provider.filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Verification'),
        backgroundColor: AfiCareTheme.adminColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadRequests(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by name, email or license number...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) => provider.setSearchQuery(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusFilter(provider),
                    ],
                  );
                }
                return Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => provider.setSearchQuery(v),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusFilter(provider),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
                    : filtered.isEmpty
                        ? const Center(child: Text('No requests found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _buildRequestCard(ctx, filtered[i], provider),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(ProviderVerificationProvider provider) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: provider.statusFilter,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Status', isDense: true),
        items: const [
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
          DropdownMenuItem(value: 'verified', child: Text('Verified')),
          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          DropdownMenuItem(value: 'all', child: Text('All')),
        ],
        onChanged: (v) => provider.setStatusFilter(v ?? 'pending'),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ProviderCredentialModel request,
    ProviderVerificationProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.providerName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(request.providerEmail ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusChip(request.verificationStatus),
                    if (request.isProvisional) ...[
                      const SizedBox(height: 4),
                      _provisionalChip(),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _detailRow('Requested role', _capitalize(request.requestedRole)),
            _detailRow('License #', request.licenseNumber ?? 'Not applicable (provisional)'),
            if (request.specialty != null && request.specialty!.isNotEmpty)
              _detailRow('Specialty', request.specialty!),
            _detailRow('Submitted', _formatDate(request.createdAt)),
            if (request.verificationStatus == VerificationStatus.rejected && request.rejectionReason != null)
              _detailRow('Rejection reason', request.rejectionReason!),
            if (request.isProvisional) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _checkKmpdcInternRegister(context, request),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Check KMPDC Intern Register'),
              ),
            ],
            if (request.verificationStatus == VerificationStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmReject(context, provider, request),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmApprove(context, provider, request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _provisionalChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Provisional', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
    );
  }

  /// Cross-references a provisional applicant's self-reported name
  /// against KMPDC's real intern register (kmpdc_practitioners,
  /// sync-kmpdc-register) -- the actual "verified against KMPDC's
  /// intern register" this feature is about. Purely informational: the
  /// Approve/Reject buttons below still call the same unchanged
  /// admin_verify_provider_license RPC regardless of what's found here.
  void _checkKmpdcInternRegister(BuildContext context, ProviderCredentialModel request) {
    final kmpdc = context.read<KmpdcVerificationProvider>();
    kmpdc.search(name: request.providerName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('KMPDC check: ${request.providerName ?? 'Unknown'}'),
        content: SizedBox(
          width: 420,
          child: Consumer<KmpdcVerificationProvider>(
            builder: (ctx, p, _) {
              if (p.isSearching) {
                return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              }
              if (p.results.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No match found on KMPDC\'s public register (checked doctors, dentists and interns).'),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: p.results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _kmpdcResultTile(p.results[i]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _kmpdcResultTile(KmpdcPractitionerModel r) {
    const cadreLabels = {
      'medical_doctor': 'Medical Doctor',
      'dentist': 'Dentist',
      'medical_intern': 'Medical Intern (Provisional)',
      'dental_intern': 'Dental Intern (Provisional)',
    };
    return ListTile(
      dense: true,
      title: Text(r.fullName),
      subtitle: Text([
        cadreLabels[r.cadre] ?? r.cadre,
        if (r.qualifications != null && r.qualifications!.isNotEmpty) r.qualifications!,
        if (r.status != null) r.status!,
      ].join(' · ')),
    );
  }

  Widget _statusChip(VerificationStatus status) {
    final color = switch (status) {
      VerificationStatus.verified => const Color(0xFF43A047),
      VerificationStatus.pending => const Color(0xFFFB8C00),
      VerificationStatus.rejected => const Color(0xFFE53935),
    };
    final label = status.name[0].toUpperCase() + status.name.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _confirmApprove(BuildContext context, ProviderVerificationProvider provider, ProviderCredentialModel request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve provider'),
        content: Text(
          'Approve ${request.providerName ?? 'this applicant'} as a ${_capitalize(request.requestedRole)}? '
          'Their account will be promoted immediately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await provider.approve(request.providerId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Provider approved' : 'Approval failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context, ProviderVerificationProvider provider, ProviderCredentialModel request) {
    final reasonCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${request.providerName ?? 'this applicant'}\'s request?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtl,
              decoration: const InputDecoration(labelText: 'Reason (shown to the applicant)', isDense: true),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await provider.reject(request.providerId, reasonCtl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Request rejected' : 'Rejection failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
