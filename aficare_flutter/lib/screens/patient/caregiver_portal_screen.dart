import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/caregiver_model.dart';
import '../../services/caregiver_service.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// The patient's side of caregiver access: make a code for someone they
/// trust, see who can look at their record, and stop it at any time.
class CaregiverPortalScreen extends StatefulWidget {
  const CaregiverPortalScreen({super.key});

  @override
  State<CaregiverPortalScreen> createState() => _CaregiverPortalScreenState();
}

class _CaregiverPortalScreenState extends State<CaregiverPortalScreen> {
  final _service = CaregiverService();
  List<CaregiverAccess> _grants = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      _grants = await _service.myGrants();
      _loadFailed = false;
    } on CaregiverException {
      _loadFailed = true;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Makes the code and returns it; throws [CaregiverException] with a
  /// message to show if it couldn't.
  Future<String> _grant(String accessLevel, String relationship) async {
    final code = await _service.createCode(accessLevel, relationship);
    _loadAccess();
    return code;
  }

  Future<void> _showGrant() async {
    await showPModal<void>(
      context: context,
      title: 'Share with someone you trust',
      builder: (ctx) => _GrantForm(onGrant: _grant),
    );
  }

  Future<void> _revokeAccess(CaregiverAccess access) async {
    final who = access.redeemedAt != null
        ? '${access.caregiverName ?? 'This person'} will no longer be able to see your record.'
        : 'Code ${CaregiverAccess.formatCode(access.accessCode)} will stop working.';
    final confirmed = await showPModal<bool>(
      context: context,
      title: 'Stop this access?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$who This happens straight away. You can share again later with a new code.', style: PT.sub()),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PButton('Keep it', kind: PButtonKind.alt, onPressed: () => Navigator.pop(ctx, false)),
              const SizedBox(width: 8),
              PButton('Stop access', kind: PButtonKind.red, onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingId = access.id);
    try {
      final stopped = await _service.revoke(access.id);
      if (!mounted) return;
      pToast(context, stopped ? 'Access stopped.' : "That access wasn't stopped. Please try again.");
      await _loadAccess();
    } on CaregiverException catch (e) {
      if (mounted) pToast(context, e.message);
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    final now = DateTime.now();
    final live = _grants.where((a) => a.isLiveAt(now)).toList();
    final ended = _grants.where((a) => !a.isLiveAt(now)).toList();

    return PSliverPage(
      eyebrow: 'Caregiver access',
      title: 'Share with someone you trust',
      subtitle: 'Let a family member, a friend or a carer you trust follow part of your care. '
          'They can look, not change anything, and you can stop it whenever you like.',
      action: PButton('Make a code', icon: Icons.add, onPressed: _showGrant),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadFailed) ...[
                PLoadError(what: "who you're sharing with", onRetry: _loadAccess),
                const SizedBox(height: 29),
              ] else ...[
                const PHeading('Sharing now'),
                PCard(
                  padding: const EdgeInsets.all(15),
                  child: live.isEmpty
                      ? PEmpty(
                          emoji: '🤝',
                          title: "You're not sharing with anyone",
                          body: 'Make a code and give it to the person you trust. '
                              'They enter it in their own AfiCare app.',
                          action: PButton('Make a code', icon: Icons.add, onPressed: _showGrant),
                        )
                      : Column(
                          children: [
                            for (final a in live)
                              _AccessRow(
                                access: a,
                                now: now,
                                busy: _revokingId == a.id,
                                onRevoke: () => _revokeAccess(a),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 29),
              ],
              const PHeading('How it works'),
              PCard(
                padding: const EdgeInsets.all(21),
                child: _HowItWorks(onGrant: _showGrant),
              ),
              if (!_loadFailed && ended.isNotEmpty) ...[
                const SizedBox(height: 29),
                const PHeading('No longer active'),
                PCard(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [for (final a in ended) _AccessRow(access: a, now: now, busy: false, onRevoke: null)],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Rows
// ═══════════════════════════════════════════════════════════════════════

String _day(DateTime d) => DateFormat('d MMM yyyy').format(d);
String _dayTime(DateTime d) => DateFormat('d MMM, HH:mm').format(d);

/// "2 hours ago", "yesterday", "3 Oct 2026".
String _ago(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inMinutes < 2) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
  if (diff.inHours < 24) return diff.inHours == 1 ? 'an hour ago' : '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return 'on ${_day(d)}';
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({required this.access, required this.now, required this.busy, required this.onRevoke});

  final CaregiverAccess access;
  final DateTime now;
  final bool busy;

  /// Null for access that has already ended.
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final a = access;
    final status = a.statusAt(now);
    final code = 'Code ${CaregiverAccess.formatCode(a.accessCode)}';
    final name = a.caregiverName?.trim();

    final who = a.redeemedAt != null && name != null && name.isNotEmpty ? name : code;
    final relationship = CaregiverRelationship.label(a.relationship);
    final title = relationship == null ? who : '$who · $relationship';
    final detail = switch (status) {
      CaregiverGrantStatus.waiting => 'Not entered yet · works until ${_dayTime(a.codeExpiresAt!)}',
      CaregiverGrantStatus.active => [
          'Since ${_day(a.redeemedAt!)}',
          a.lastViewedAt == null ? "hasn't looked yet" : 'last looked ${_ago(a.lastViewedAt!, now)}',
        ].join(' · '),
      CaregiverGrantStatus.expired => 'Made ${_day(a.grantedAt)} · never entered',
      CaregiverGrantStatus.stopped =>
        a.redeemedAt != null ? 'Shared from ${_day(a.redeemedAt!)} · stopped' : 'Made ${_day(a.grantedAt)} · stopped',
    };

    final (badge, tone, icon) = switch (status) {
      CaregiverGrantStatus.waiting => ('Waiting', PTone.blue, Icons.key_rounded),
      CaregiverGrantStatus.active => ('Can see', PTone.ok, Icons.visibility_outlined),
      CaregiverGrantStatus.expired => ('Expired', PTone.gray, Icons.key_off_rounded),
      CaregiverGrantStatus.stopped => ('Stopped', PTone.gray, Icons.key_off_rounded),
    };

    final controls = <Widget>[
      PBadge(badge, tone: tone),
      if (onRevoke != null)
        PButton(busy ? '…' : 'Stop', kind: PButtonKind.alt, dense: true, onPressed: busy ? null : onRevoke),
    ];
    final mobile = PT.isMobile(context);

    return PRow(
      leading: PSoftIcon(icon),
      title: title,
      subtitle: CaregiverAccess.accessLevelScope(a.accessLevel),
      extraSubtitle: detail,
      trailing: mobile ? const [] : controls,
      below: mobile
          ? Padding(
              padding: const EdgeInsets.only(left: 53),
              child: Row(children: [controls.first, const Spacer(), if (controls.length > 1) controls.last]),
            )
          : null,
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.onGrant});

  final VoidCallback onGrant;

  static const _steps = [
    ('Make a code', 'Choose what they can see. The code works once, within 48 hours.'),
    ('They enter it', 'In their own AfiCare app: More → People I care for → Enter a code.'),
    ('They can look', "They see only what you chose, and can't change anything. "
        'Mental health check-ins are never shared.'),
    ('You still decide', "Being your caregiver doesn't let them make medical decisions for you "
        'or agree to treatment on your behalf.'),
    ('You stay in control', 'Stop it here at any time and it ends straight away.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in _steps.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: PT.stepNumBg, shape: BoxShape.circle),
                child: Text('${i + 1}', style: PT.rowTitle().copyWith(color: PT.teal, fontSize: 13)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$1, style: PT.rowTitle()),
                    const SizedBox(height: 2),
                    Text(s.$2, style: PT.rowSub()),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        PButton('Make a code', icon: Icons.add, onPressed: onGrant),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Make a code (inside showPModal): choose a level, then show the code.
// ═══════════════════════════════════════════════════════════════════════

class _GrantForm extends StatefulWidget {
  const _GrantForm({required this.onGrant});

  final Future<String> Function(String accessLevel, String relationship) onGrant;

  @override
  State<_GrantForm> createState() => _GrantFormState();
}

class _GrantFormState extends State<_GrantForm> {
  static const _levels = ['full', 'medical_only', 'appointments_only', 'emergency_only'];

  String _level = 'full';

  /// Who the person is to the patient. No default: the patient chooses.
  String? _relationship;
  bool _saving = false;
  String? _error;

  /// Set once the code exists; the form then shows it instead.
  String? _code;

  Future<void> _generate() async {
    final relationship = _relationship;
    if (relationship == null) {
      setState(() => _error = 'Choose who this person is to you.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final code = await widget.onGrant(_level, relationship);
      if (mounted) setState(() => _code = code);
    } on CaregiverException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code != null) return _showCode(CaregiverAccess.formatCode(code));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who is this person to you?', style: PT.rowTitle()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in CaregiverRelationship.values)
              PChoicePill(
                label: CaregiverRelationship.label(r)!,
                selected: _relationship == r,
                onTap: () => setState(() {
                  _relationship = r;
                  _error = null;
                }),
              ),
          ],
        ),
        if (_relationshipNote(_relationship) case final note?) ...[
          const SizedBox(height: 10),
          Text(note, style: PT.rowSub()),
        ],
        const SizedBox(height: 22),
        Text('What can they see?', style: PT.rowTitle()),
        const SizedBox(height: 4),
        Text("They can look but not change anything.", style: PT.sub()),
        const SizedBox(height: 10),
        for (final level in _levels)
          _LevelOption(
            title: CaregiverAccess.accessLevelLabel(level),
            subtitle: CaregiverAccess.accessLevelScope(level),
            selected: _level == level,
            onTap: () => setState(() => _level = level),
          ),
        const SizedBox(height: 10),
        Text(
          'Medicines show everything you have been prescribed. '
          'Mental health check-ins are never shared, whatever you choose.',
          style: PT.rowSub(),
        ),
        const SizedBox(height: 12),
        const PCallout(
          body: "A caregiver can see what you choose. They can't make medical decisions for you.",
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Making…' : 'Make a code', onPressed: _saving ? null : _generate),
        ),
      ],
    );
  }

  Widget _showCode(String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Give this code to the person you trust, in person or in a private message. '
          'Anyone who has it can use it, once.',
          style: PT.sub(),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(color: PT.calloutBg, borderRadius: BorderRadius.circular(PT.rRow)),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(code, style: PT.score().copyWith(letterSpacing: 4)),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (CaregiverRelationship.label(_relationship) case final who?) 'For: $who',
                  CaregiverAccess.accessLevelScope(_level),
                ].join(' · '),
                style: PT.label(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'They enter it in their AfiCare app under More → People I care for. '
          'It works for 48 hours; after that, make a new one.',
          style: PT.rowSub(),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PButton(
              'Copy code',
              kind: PButtonKind.alt,
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (mounted) pToast(context, 'Code copied');
              },
            ),
            const SizedBox(width: 8),
            PButton('Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ],
    );
  }
}

/// A word on the two relationships people most often get wrong.
String? _relationshipNote(String? relationship) => switch (relationship) {
      'nurse' => "For a nurse you've arranged yourself, for example at home. "
          "Nurses treating you at a hospital or clinic don't need a code: they see your record through their facility.",
      'paid_carer' => 'Someone you pay to help you. When they stop working for you, stop their access here.',
      _ => null,
    };

class _LevelOption extends StatelessWidget {
  const _LevelOption({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? PT.badgeBlueBg : PT.white,
          borderRadius: BorderRadius.circular(PT.rRow),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PT.rRow),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? PT.teal : PT.line, width: selected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(PT.rRow),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? PT.teal : PT.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: PT.rowTitle()),
                        const SizedBox(height: 2),
                        Text(subtitle, style: PT.rowSub()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
