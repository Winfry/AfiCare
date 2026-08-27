import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../models/referral_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/referral_provider.dart';

class PatientReferralScreen extends StatefulWidget {
  const PatientReferralScreen({super.key});

  @override
  State<PatientReferralScreen> createState() => _PatientReferralScreenState();
}

class _PatientReferralScreenState extends State<PatientReferralScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, String> _fromProviderCache = {};
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id == null) return;

    final provider = Provider.of<ReferralProvider>(context, listen: false);
    await provider.loadPatientReferrals(id);

    _fromProviderCache = {};
    for (final r in provider.referrals) {
      _fromProviderCache[r.fromProviderId] = await _providerName(r.fromProviderId);
    }
    if (mounted) setState(() {});
  }

  Future<String> _providerName(String pid) async {
    try {
      final res = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', pid)
          .maybeSingle();
      return (res != null && res['full_name'] != null)
          ? res['full_name'] as String
          : 'Your doctor';
    } catch (_) {
      return 'Your doctor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final referrals = provider.referrals;
    _loadError = provider.error != null;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/patient'),
            ),
            title: const Text('My Referrals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_information_outlined, color: Color(0xFF1565C0), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Referrals are sent by your healthcare provider to a higher-level facility (e.g. from a dispensary to a county hospital). Track their status here.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE57373)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Could not load your referrals. Check your connection and try again.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  const Text('Referral History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.canopy)),
            )
          else if (referrals.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.send_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No referrals yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('When your doctor refers you, it will appear here.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: referrals.length,
                itemBuilder: (context, i) {
                  final r = referrals[i];
                  final providerName = _fromProviderCache[r.fromProviderId] ?? 'Your doctor';
                  return _referralCard(r, providerName);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _referralCard(ReferralModel r, String providerName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(r.status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: r.statusColor),
                ),
              ),
              const SizedBox(width: 8),
              _urgencyBadge(r),
              const Spacer(),
              Text(
                '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.local_hospital_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.toFacility,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          if (r.toDepartment != null) ...[
            const SizedBox(height: 2),
            Text('Dept: ${r.toDepartment}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 8),
          Text(r.reason, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Referred by: $providerName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
              InkWell(
                onTap: () => _showDetail(r, providerName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.canopy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Details',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.canopy)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.canopy),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _urgencyBadge(ReferralModel r) {
    final isUrgent = r.urgency == ReferralUrgency.urgent || r.urgency == ReferralUrgency.emergency;
    if (!isUrgent) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        r.urgency == ReferralUrgency.emergency ? 'EMERGENCY' : 'URGENT',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }

  void _showDetail(ReferralModel r, String providerName) {
    final steps = ['Pending', 'Accepted', 'Completed'];
    final currentStepIndex = r.status == ReferralStatus.pending
        ? 0
        : r.status == ReferralStatus.accepted
            ? 1
            : r.status == ReferralStatus.completed
                ? 2
                : -1;
    final isRejected = r.status == ReferralStatus.declined || r.status == ReferralStatus.closed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Referral Status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('$providerName → ${r.toFacility}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: r.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusDescription(r.status),
                  style: TextStyle(fontSize: 13, color: r.statusColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Status Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              if (isRejected)
                _timelineStep('Rejected', Colors.red,
                    datetime: r.respondedAt ?? r.createdAt)
              else
                ...List.generate(steps.length, (i) {
                  final isActive = i <= currentStepIndex;
                  final isCurrent = i == currentStepIndex;
                  return _timelineStep(
                    steps[i],
                    isActive ? AppColors.canopy : Colors.grey.shade300,
                    isCurrent: isCurrent,
                    datetime: i == 0
                        ? r.createdAt
                        : (i == currentStepIndex && r.respondedAt != null
                            ? r.respondedAt
                            : null),
                  );
                }),
              if (r.responseNotes != null && r.responseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Response from facility',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1565C0))),
                      const SizedBox(height: 4),
                      Text(r.responseNotes!, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineStep(String label, Color color,
      {bool isCurrent = false, DateTime? datetime}) {
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
                color: color,
                border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow: isCurrent
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                    : null,
              ),
            ),
            Container(width: 2, height: 30, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              color: color == Colors.grey.shade300 ? Colors.grey.shade500 : Colors.black87,
            ),
          ),
        ),
        const Spacer(),
        if (datetime != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${datetime.day}/${datetime.month}/${datetime.year}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
      ],
    );
  }

  String _statusLabel(ReferralStatus s) {
    switch (s) {
      case ReferralStatus.pending: return 'Pending';
      case ReferralStatus.accepted: return 'Accepted';
      case ReferralStatus.completed: return 'Completed';
      case ReferralStatus.declined: return 'Declined';
      case ReferralStatus.closed: return 'Closed';
    }
  }

  String _statusDescription(ReferralStatus s) {
    switch (s) {
      case ReferralStatus.pending:
        return 'Your referral has been sent and is awaiting response from the receiving facility.';
      case ReferralStatus.accepted:
        return 'The receiving facility has accepted your referral. Follow up as directed.';
      case ReferralStatus.completed:
        return 'Your referral has been completed. Visit the facility if you have further questions.';
      case ReferralStatus.declined:
        return 'The receiving facility declined this referral. Contact your doctor for alternatives.';
      case ReferralStatus.closed:
        return 'This referral is closed. Contact your doctor for more information.';
    }
  }
}
