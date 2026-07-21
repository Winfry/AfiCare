import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class ReferralTrackerScreen extends StatefulWidget {
  const ReferralTrackerScreen({super.key});

  @override
  State<ReferralTrackerScreen> createState() => _ReferralTrackerScreenState();
}

class _ReferralTrackerScreenState extends State<ReferralTrackerScreen> {
  List<Map<String, dynamic>> _referrals = [];
  bool _isLoading = true;
  String _filter = 'All';
  final List<String> _filterTabs = [
    'All', 'Pending', 'Accepted', 'Completed', 'Rejected',
  ];
  final Map<String, String> _patientNameCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferrals());
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id;
    if (providerId == null) return;

    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('referrals')
          .select()
          .eq('from_provider_id', providerId)
          .order('created_at', ascending: false);

      _referrals = List<Map<String, dynamic>>.from(response as List);
      for (final r in _referrals) {
        _patientNameCache[r['patient_id']] =
            await _getPatientName(supabase, r['patient_id']);
      }
      _isLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<String> _getPatientName(SupabaseClient supabase, String pid) async {
    try {
      final res = await supabase
          .from('users')
          .select('full_name, medilink_id')
          .eq('id', pid)
          .single();
      return '${res['full_name'] ?? 'Unknown'} (${res['medilink_id'] ?? 'N/A'})';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _referrals
        : _referrals.where((r) {
            final status = r['status'] as String? ?? '';
            return status.toLowerCase() == _filter.toLowerCase();
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Referrals (${_referrals.length})'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterTabs.map((t) {
                  final selected = _filter == t;
                  final count = t == 'All'
                      ? _referrals.length
                      : _referrals
                          .where((r) =>
                              (r['status'] as String? ?? '').toLowerCase() ==
                              t.toLowerCase())
                          .length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text('$t ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : Colors.grey[700],
                          )),
                      selected: selected,
                      selectedColor: _statusColor(t),
                      backgroundColor: _statusColor(t).withOpacity(0.1),
                      onSelected: (_) => setState(() => _filter = t),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          // Referral list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No referrals sent yet',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReferrals,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final r = filtered[i];
                            final name =
                                _patientNameCache[r['patient_id']] ??
                                    'Unknown';
                            return _buildReferralCard(r, name);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> r, String patientName) {
    final status = r['status'] as String? ?? 'pending';
    final urgency = r['urgency'] as String? ?? 'routine';
    final reason = r['reason'] as String? ?? '';
    final toFacility = r['to_facility'] as String? ?? '';
    final toDepartment = r['to_department'] as String? ?? '';
    final createdAt = DateTime.parse(r['created_at'] as String);
    final respondedAt = r['responded_at'] != null
        ? DateTime.parse(r['responded_at'] as String)
        : null;

    final isUrgent = urgency == 'urgent' || urgency == 'emergency';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetailSheet(r, patientName, createdAt, respondedAt),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: patient name + ML-ID
              Row(
                children: [
                  Expanded(
                    child: Text(
                      patientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        urgency.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 2: destination
              Row(
                children: [
                  Icon(Icons.arrow_forward,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (toDepartment.isNotEmpty) toDepartment,
                        toFacility,
                      ].join(', '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 3: reason
              Text(
                reason,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Row 4: status + date
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> r, String patientName,
      DateTime createdAt, DateTime? respondedAt) {
    final status = r['status'] as String? ?? 'pending';
    final urgency = r['urgency'] as String? ?? 'routine';
    final reason = r['reason'] as String? ?? '';
    final toFacility = r['to_facility'] as String? ?? '';
    final toDepartment = r['to_department'] as String? ?? '';
    final clinicalNotes = r['clinical_notes'] as String? ?? '';
    final responseNotes = r['response_notes'] as String? ?? '';
    final toSpecialist = r['to_specialist'] as String? ?? '';

    final steps = ['Sent', 'Accepted', 'Completed'];
    final currentStepIndex = status == 'pending'
        ? 0
        : status == 'accepted'
            ? 1
            : status == 'completed'
                ? 2
                : -1;
    final isRejected = status == 'declined';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Patient header
              Text(patientName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '→ ${[toDepartment, toFacility].where((s) => s.isNotEmpty).join(', ')}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              if (toSpecialist.isNotEmpty)
                Text('Specialist: $toSpecialist',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),

              // Urgency
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _urgencyColor(urgency).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Urgency: ${urgency[0].toUpperCase()}${urgency.substring(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _urgencyColor(urgency),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              const Text('Reason',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(reason,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800])),
              if (clinicalNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Clinical Notes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(clinicalNotes,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[800])),
              ],
              if (responseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Response Notes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue)),
                      const SizedBox(height: 4),
                      Text(responseNotes,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[800])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Status timeline
              const Text('Status',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              if (isRejected)
                _buildTimelineStep('Rejected', true, Colors.red,
                    subtitle: respondedAt != null
                        ? _formatDate(respondedAt)
                        : null)
              else
                ...List.generate(steps.length, (i) {
                  final isActive = i <= currentStepIndex;
                  final isCurrent = i == currentStepIndex;
                  return _buildTimelineStep(
                    steps[i],
                    isActive,
                    isCurrent
                        ? AfiCareTheme.primaryBlue
                        : Colors.grey[400]!,
                    isCurrent: isCurrent,
                    subtitle: i == 0
                        ? _formatDate(createdAt)
                        : (i == currentStepIndex && respondedAt != null
                            ? _formatDate(respondedAt)
                            : null),
                  );
                }),

              const SizedBox(height: 20),
              if (status == 'accepted' || status == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final supabase = Supabase.instance.client;
                      await supabase
                          .from('referrals')
                          .update({
                            'status': 'completed',
                            'responded_at':
                                DateTime.now().toIso8601String(),
                          })
                          .eq('id', r['id']);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadReferrals();
                    },
                    icon: const Icon(Icons.check_circle,
                        size: 18, color: Colors.green),
                    label: const Text('Close Referral',
                        style: TextStyle(color: Colors.green)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(
    String label,
    bool isActive,
    Color color, {
    bool isCurrent = false,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: isCurrent ? 16 : 12,
              height: isCurrent ? 16 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? color : Colors.grey[300],
                border: isCurrent
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: isCurrent
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                    : null,
              ),
            ),
            Container(
              width: 2,
              height: 32,
              color: isActive ? color : Colors.grey[200],
            ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: isActive ? Colors.black87 : Colors.grey[500],
                ),
              ),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'declined':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case 'emergency':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}
