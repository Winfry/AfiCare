import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/facility_admin_request_provider.dart';
import '../../models/facility_admin_request_model.dart';
import '../../utils/theme.dart';

class AdminFacilityAdminRequestsScreen extends StatefulWidget {
  const AdminFacilityAdminRequestsScreen({super.key});

  @override
  State<AdminFacilityAdminRequestsScreen> createState() =>
      _AdminFacilityAdminRequestsScreenState();
}

class _AdminFacilityAdminRequestsScreenState
    extends State<AdminFacilityAdminRequestsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FacilityAdminRequestProvider>().loadRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FacilityAdminRequestProvider>();
    final filtered = provider.filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Admin Requests'),
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
                            hintText: 'Search by applicant name, email or facility...',
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

  Widget _buildStatusFilter(FacilityAdminRequestProvider provider) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: provider.statusFilter,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Status', isDense: true),
        items: const [
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
          DropdownMenuItem(value: 'approved', child: Text('Approved')),
          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          DropdownMenuItem(value: 'all', child: Text('All')),
        ],
        onChanged: (v) => provider.setStatusFilter(v ?? 'pending'),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    FacilityAdminRequestModel request,
    FacilityAdminRequestProvider provider,
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
                      Text(request.applicantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(request.applicantEmail, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                _statusChip(request.status),
              ],
            ),
            const SizedBox(height: 10),
            _detailRow('Facility', request.facilityName ?? 'Unknown'),
            if (request.title != null && request.title!.isNotEmpty)
              _detailRow('Title', request.title!),
            _detailRow('Submitted', _formatDate(request.createdAt)),
            if (request.status == FacilityAdminRequestStatus.rejected && request.rejectionReason != null)
              _detailRow('Rejection reason', request.rejectionReason!),
            if (request.status == FacilityAdminRequestStatus.pending) ...[
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

  Widget _statusChip(FacilityAdminRequestStatus status) {
    final color = switch (status) {
      FacilityAdminRequestStatus.approved => const Color(0xFF43A047),
      FacilityAdminRequestStatus.pending => const Color(0xFFFB8C00),
      FacilityAdminRequestStatus.rejected => const Color(0xFFE53935),
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

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _confirmApprove(BuildContext context, FacilityAdminRequestProvider provider, FacilityAdminRequestModel request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve facility admin'),
        content: Text(
          'Approve ${request.applicantName} to administer '
          '${request.facilityName ?? 'this facility'}? The facility will be marked '
          'verified and ${request.applicantEmail} will receive a real invite email '
          'to activate their account -- no account exists until they accept it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await provider.approve(request);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Request approved' : 'Approval failed: ${provider.error}')),
                );
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context, FacilityAdminRequestProvider provider, FacilityAdminRequestModel request) {
    final reasonCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reject ${request.applicantName}'s request?"),
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
              final ok = await provider.reject(request.id, reasonCtl.text.trim());
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
