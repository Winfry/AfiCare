import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/referral_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/referral_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// Referrals — follow a referral from request to facility response.
/// The status timeline is shown inline on each card rather than hidden
/// behind a detail sheet: this is the patient's view of progress, not an
/// internal workflow dump.
class PatientReferralScreen extends StatefulWidget {
  const PatientReferralScreen({super.key});

  @override
  State<PatientReferralScreen> createState() => _PatientReferralScreenState();
}

class _PatientReferralScreenState extends State<PatientReferralScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, String> _fromProviderCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id == null) return;

    final provider = Provider.of<ReferralProvider>(context, listen: false);
    await provider.loadPatientReferrals(id);

    final names = <String, String>{};
    for (final r in provider.referrals) {
      names[r.fromProviderId] = await _providerName(r.fromProviderId);
    }
    if (mounted) setState(() => _fromProviderCache = names);
  }

  Future<String> _providerName(String pid) async {
    try {
      final res = await _supabase.from('users').select('full_name').eq('id', pid).maybeSingle();
      return (res != null && res['full_name'] != null) ? res['full_name'] as String : 'Your doctor';
    } catch (_) {
      return 'Your doctor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final referrals = provider.referrals;

    return PDetailScaffold(
      eyebrow: 'Clinical',
      title: 'Referrals',
      subtitle: 'Follow referrals from request to facility response.',
      onBack: () => context.go('/patient'),
      children: [
        const PCallout(
          body: 'Referrals are sent by your healthcare provider to a higher-level facility — '
              'for example from a dispensary to a county hospital. Track their status here.',
        ),
        const SizedBox(height: 16),
        if (provider.error != null) ...[
          PCallout(
            title: 'Could not load your referrals',
            body: 'Check your connection and try again.',
            tone: PTone.red,
            trailing: PButton('Retry', kind: PButtonKind.alt, dense: true, onPressed: _load),
          ),
          const SizedBox(height: 16),
        ],
        const PHeading('Referral history'),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: PT.teal)),
          )
        else if (referrals.isEmpty)
          const PCard(
            child: PEmpty(
              emoji: '↗️',
              title: 'No referrals yet',
              body: 'When your doctor refers you to another facility, it will appear here.',
            ),
          )
        else
          PGrid(
            columns: 2,
            children: [
              for (final r in referrals)
                _referralCard(r, _fromProviderCache[r.fromProviderId] ?? 'Your doctor'),
            ],
          ),
      ],
    );
  }

  Widget _referralCard(ReferralModel r, String providerName) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            r.toDepartment == null ? r.toFacility : '${r.toDepartment} referral',
            trailing: _statusBadge(r.status),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.toDepartment == null ? r.reason : '${r.toFacility} · ${r.reason}',
                  style: PT.sub(),
                ),
              ),
              if (r.urgency != ReferralUrgency.routine) ...[
                const SizedBox(width: 8),
                PBadge(
                  r.urgency == ReferralUrgency.emergency ? 'Emergency' : 'Urgent',
                  tone: PTone.red,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          PTimeline(_events(r)),
          const SizedBox(height: 14),
          PCallout(
            title: 'Facility response',
            body: (r.responseNotes != null && r.responseNotes!.isNotEmpty)
                ? r.responseNotes!
                : _statusDescription(r.status, r.toFacility),
            tone: switch (r.status) {
              ReferralStatus.declined => PTone.red,
              ReferralStatus.pending => PTone.warn,
              _ => PTone.ok,
            },
          ),
          const SizedBox(height: 10),
          Text('Referred by $providerName', style: PT.rowSub()),
        ],
      ),
    );
  }

  List<PTimelineEvent> _events(ReferralModel r) {
    String when(DateTime? d) => d == null ? '' : DateFormat('d MMM · HH:mm').format(d);

    final events = <PTimelineEvent>[
      PTimelineEvent(title: 'Referral requested', subtitle: when(r.createdAt)),
    ];

    switch (r.status) {
      case ReferralStatus.pending:
        events.add(const PTimelineEvent(
          title: 'Awaiting facility response',
          subtitle: 'The receiving facility has not responded yet',
        ));
      case ReferralStatus.accepted:
        events.add(PTimelineEvent(title: 'Facility accepted', subtitle: when(r.respondedAt)));
        events.add(const PTimelineEvent(
          title: 'Appointment pending',
          subtitle: 'Follow up as directed',
        ));
      case ReferralStatus.completed:
        events.add(PTimelineEvent(title: 'Facility accepted', subtitle: when(r.respondedAt)));
        events.add(PTimelineEvent(title: 'Completed', subtitle: when(r.respondedAt)));
      case ReferralStatus.declined:
        events.add(PTimelineEvent(title: 'Facility declined', subtitle: when(r.respondedAt)));
      case ReferralStatus.closed:
        events.add(PTimelineEvent(title: 'Referral closed', subtitle: when(r.respondedAt)));
    }

    return events;
  }

  Widget _statusBadge(ReferralStatus s) => switch (s) {
        ReferralStatus.pending => const PBadge('Pending', tone: PTone.warn),
        ReferralStatus.accepted => const PBadge('In progress', tone: PTone.blue),
        ReferralStatus.completed => const PBadge('Completed', tone: PTone.ok),
        ReferralStatus.declined => const PBadge('Declined', tone: PTone.red),
        ReferralStatus.closed => const PBadge('Closed', tone: PTone.gray),
      };

  String _statusDescription(ReferralStatus s, String facility) => switch (s) {
        ReferralStatus.pending =>
          '$facility has received your referral. You will be notified when they respond.',
        ReferralStatus.accepted =>
          '$facility has accepted your referral. Follow up as directed.',
        ReferralStatus.completed =>
          'This referral is complete. Visit $facility if you have further questions.',
        ReferralStatus.declined =>
          '$facility declined this referral. Contact your doctor about alternatives.',
        ReferralStatus.closed => 'This referral is closed. Contact your doctor for more information.',
      };
}
