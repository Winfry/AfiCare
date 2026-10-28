import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/active_patient.dart';
import '../../models/record_share_model.dart';
import '../../services/record_share_service.dart';
import '../../theme/patient_tokens.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// Share Records: choose which parts of the record a doctor or nurse may
/// see, and for how long. A share is a code the database checks (044):
/// only doctors and nurses can open it, only the first one to open it
/// keeps it, and they get back only the sections chosen. On a
/// dependant's profile, it shares the dependant's record.
class ShareRecords extends StatefulWidget {
  const ShareRecords({super.key, this.service});

  /// For tests; the app uses the real one.
  final RecordShareService? service;

  @override
  State<ShareRecords> createState() => _ShareRecordsState();
}

class _ShareRecordsState extends State<ShareRecords> {
  late final RecordShareService _service = widget.service ?? RecordShareService();

  int _tab = 0; // 0 = Share records, 1 = Scan QR
  bool _isLoading = false;
  bool _loadFailed = false;
  List<RecordShare> _shares = [];

  /// Whose shares are on screen; a profile switch loads the other's.
  String? _loadedFor;

  // ── Data ──────────────────────────────────────────────────────────────

  Future<void> _load(String patientId) async {
    _loadedFor = patientId;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final shares = await _service.mine(patientId);
      if (!mounted || _loadedFor != patientId) return;
      setState(() => _shares = shares);
    } catch (e) {
      debugPrint('share_records: loading shares failed: $e');
      if (mounted && _loadedFor == patientId) setState(() => _loadFailed = true);
    }
    if (mounted && _loadedFor == patientId) setState(() => _isLoading = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subject = ActivePatient.of(context);
    if (subject.id.isNotEmpty && subject.id != _loadedFor) {
      _loadedFor = subject.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(subject.id);
      });
    }
    final whose = subject.isDependent ? "${subject.firstName}'s" : 'your';
    final now = DateTime.now();
    final active = _shares.where((s) => s.isActiveAt(now)).toList();
    final past = _shares.where((s) => !s.isActiveAt(now)).toList();

    return PDetailScaffold(
      eyebrow: subject.isDependent ? 'Caring for ${subject.firstName}' : 'Your care',
      title: 'Share Records',
      subtitle: 'Let a doctor or nurse see the parts of $whose record you choose, for as long as you choose.',
      action: PButton('+ New share', onPressed: () => _openNewShare(subject)),
      children: [
        PTabs(
          tabs: const ['Share records', 'Scan QR'],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        if (_tab == 1)
          _scanCard()
        else ...[
          PGrid(
            columns: 2,
            children: [
              subject.isDependent ? _dependantIdCard(subject) : _medilinkQrCard(subject),
              _howItWorksCard(subject),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadFailed)
            PLoadError(what: 'shares', onRetry: () => _load(subject.id))
          else ...[
            _sharesCard(active, live: true),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sharesCard(past, live: false),
            ],
          ],
        ],
      ],
    );
  }

  // ── Share tab ─────────────────────────────────────────────────────────

  Widget _medilinkQrCard(ActivePatient subject) {
    final medilinkId = subject.medilinkId;
    return PCard(
      child: Column(
        children: [
          const PCardTitle('Your MediLink QR'),
          if (medilinkId == null || medilinkId.isEmpty)
            Text('Your MediLink ID will appear here once your account is set up.', style: PT.sub())
          else ...[
            _qrBox(medilinkId, label: 'QR code containing your MediLink ID'),
            const SizedBox(height: 12),
            Text(medilinkId, style: PT.h3()),
          ],
          const SizedBox(height: 4),
          Text(
            'Health workers scan this to look you up in AfiCare. What they can then see depends '
            'on their part in your care. To show a new doctor or nurse exactly what you choose, '
            'make a share.',
            textAlign: TextAlign.center,
            style: PT.sub(),
          ),
        ],
      ),
    );
  }

  Widget _dependantIdCard(ActivePatient subject) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle("${subject.firstName}'s records"),
          Text(
            "Clinics can't look ${subject.firstName} up by MediLink ID yet. To show a doctor or "
            "nurse ${subject.firstName}'s records, make a share and give them the code.",
            style: PT.sub(),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksCard(ActivePatient subject) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('How sharing works'),
          _step('1', 'Pick what to share and for how long.'),
          _step('2', 'Show the code or QR to the doctor or nurse. They open it in their AfiCare app.'),
          _step('3', 'They see only what you picked. The first health worker to open it keeps it; '
              'to anyone else the code is useless.'),
          _step('4', 'You see who opened it, and you can stop it any time.'),
          const SizedBox(height: 12),
          PButton('+ New share', onPressed: () => _openNewShare(subject)),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text('$n.', style: PT.body().copyWith(fontWeight: FontWeight.w700))),
          Expanded(child: Text(text, style: PT.sub())),
        ],
      ),
    );
  }

  Widget _sharesCard(List<RecordShare> rows, {required bool live}) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCardTitle(
            live ? 'Active shares' : 'Past shares',
            trailing: live
                ? PBadge('${rows.length} active', tone: rows.isEmpty ? PTone.gray : PTone.ok)
                : null,
          ),
          if (_isLoading && _shares.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: PT.teal)),
            )
          else if (rows.isEmpty)
            Text(live ? 'Nothing is being shared right now.' : 'No past shares.', style: PT.sub())
          else
            for (final s in rows) _shareRow(s, live: live),
        ],
      ),
    );
  }

  Widget _shareRow(RecordShare s, {required bool live}) {
    final opened = s.openedBy;
    final when = DateFormat('d MMM · HH:mm');
    final status = s.statusAt(DateTime.now());

    final String detail;
    if (live) {
      detail = opened == null
          ? 'Until ${when.format(s.expiresAt)}'
          : 'Until ${when.format(s.expiresAt)} · opened ${when.format(s.openedAt!)}'
              '${s.viewCount > 1 ? ' · viewed ${s.viewCount} times' : ''}';
    } else {
      final ended = status == ShareStatus.revoked ? s.revokedAt! : s.expiresAt;
      detail = '${status == ShareStatus.revoked ? 'Stopped' : 'Expired'} ${when.format(ended)}';
    }

    return Opacity(
      opacity: live ? 1 : .65,
      child: PRow(
        leadingEmoji: opened == null ? '📤' : '👁️',
        title: opened == null ? 'Not opened yet' : 'Opened by $opened',
        subtitle: s.sectionLabels,
        extraSubtitle: detail,
        trailing: live
            ? [
                PButton('Show code', kind: PButtonKind.alt, dense: true, onPressed: () => _showCode(s)),
                PButton('Stop', kind: PButtonKind.red, dense: true, onPressed: () => _confirmRevoke(s)),
              ]
            : [PBadge(status == ShareStatus.revoked ? 'Stopped' : 'Expired', tone: PTone.gray)],
      ),
    );
  }

  // ── Scan tab ──────────────────────────────────────────────────────────

  Widget _scanCard() {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Scan a QR code'),
          Text(
            'The scanner tells you what a code is: a MediLink ID, a share code, or something '
            'else. It never shares your records. Checking in at a facility by QR isn\'t '
            'available yet.',
            style: PT.sub(),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 300,
              height: 300,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0B2230),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 54, color: Color(0xFFD6ECE9)),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Point your camera at any QR code to see what it is.',
                      textAlign: TextAlign.center,
                      style: PT.sub().copyWith(color: const Color(0xFFD6ECE9)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PButton(
                    'Open scanner',
                    // Full screen over the shell: the camera needs the room.
                    onPressed: () => context.push(PatientRoutes.scan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _openNewShare(ActivePatient subject) async {
    if (subject.id.isEmpty) return;
    final selected = <String>{'basic_info', 'allergies'};
    var hours = 4;
    var creating = false;
    String? formError;
    final whose = subject.isDependent ? "${subject.firstName}'s" : 'your';

    await showPModal<void>(
      context: context,
      title: subject.isDependent ? "Share ${subject.firstName}'s records" : 'New share',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only a doctor or nurse can open it, and they see only what you pick from '
              '$whose record. Mental health is never shared.',
              style: PT.sub(),
            ),
            const SizedBox(height: 18),
            Text('What can they see?', style: PT.h3()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in ShareSection.all)
                  _SelectPill(
                    label: section.label,
                    selected: selected.contains(section.id),
                    onTap: () => setSheetState(() {
                      if (!selected.remove(section.id)) selected.add(section.id);
                      formError = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('How long?', style: PT.h3()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in RecordShare.durations)
                  _SelectPill(
                    label: d.$2,
                    selected: hours == d.$1,
                    onTap: () => setSheetState(() => hours = d.$1),
                  ),
              ],
            ),
            if (formError != null) ...[
              const SizedBox(height: 16),
              PCallout(body: formError!, tone: PTone.red),
            ],
            const SizedBox(height: 22),
            PButton(
              creating ? 'Creating…' : 'Create share',
              expand: true,
              onPressed: creating
                  ? null
                  : () async {
                      if (selected.isEmpty) {
                        setSheetState(() => formError = 'Pick at least one thing to share.');
                        return;
                      }
                      setSheetState(() {
                        creating = true;
                        formError = null;
                      });
                      try {
                        final ordered = [
                          for (final s in ShareSection.all)
                            if (selected.contains(s.id)) s.id,
                        ];
                        final share = await _service.create(subject.id, ordered, hours);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          _showCode(share, justMade: true);
                          _load(subject.id);
                        }
                      } on RecordShareException catch (e) {
                        if (ctx.mounted) {
                          setSheetState(() {
                            creating = false;
                            formError = e.message;
                          });
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showCode(RecordShare s, {bool justMade = false}) {
    final code = RecordShare.formatCode(s.code);
    final until = DateFormat('d MMM · HH:mm').format(s.expiresAt);
    showPModal<void>(
      context: context,
      title: justMade ? 'Share created' : 'Share code',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shares: ${s.sectionLabels}. Works until $until, unless you stop it sooner.',
              style: PT.sub()),
          const SizedBox(height: 16),
          Center(child: _qrBox(RecordShare.qrData(s.code), label: 'QR code for share code $code')),
          const SizedBox(height: 14),
          Center(child: SelectableText(code, style: PT.h3().copyWith(fontSize: 26, letterSpacing: 3))),
          const SizedBox(height: 10),
          Text(
            'Show this to the doctor or nurse. In AfiCare they go to Patient access, then scan '
            'the QR or type the code under "Access code".',
            style: PT.sub(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PButton(
                  'Copy code',
                  kind: PButtonKind.alt,
                  expand: true,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    pToast(ctx, 'Code copied');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  'Send',
                  expand: true,
                  onPressed: () => Share.share(
                    'My AfiCare share code is $code. A doctor or nurse can open it in AfiCare '
                    '(Patient access → Access code) until $until. It shows: ${s.sectionLabels}.',
                    subject: 'AfiCare share code',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrBox(String data, {required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PT.white,
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        label: label,
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 170,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: PT.navy),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: PT.navy,
          ),
        ),
      ),
    );
  }

  void _confirmRevoke(RecordShare s) {
    final opened = s.openedBy;
    showPModal<void>(
      context: context,
      title: 'Stop this share?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opened == null
                ? 'The code stops working straight away.'
                : 'The code stops working straight away, and $opened can no longer open it.',
            style: PT.sub(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PButton('Cancel', kind: PButtonKind.alt, expand: true, onPressed: () => Navigator.pop(ctx)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  'Stop sharing',
                  kind: PButtonKind.red,
                  expand: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _revoke(s);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(RecordShare s) async {
    try {
      final stopped = await _service.revoke(s.id);
      if (mounted) pToast(context, stopped ? 'Share stopped' : 'This share had already ended');
    } on RecordShareException catch (e) {
      if (mounted) pToast(context, e.message);
    }
    final id = _loadedFor;
    if (mounted && id != null) await _load(id);
  }
}

/// Selectable pill matching the spec's `.checks` control.
class _SelectPill extends StatelessWidget {
  const _SelectPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PT.calloutBg : PT.white,
        borderRadius: BorderRadius.circular(PT.rPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(PT.rPill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? PT.teal : PT.line),
              borderRadius: BorderRadius.circular(PT.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: selected ? PT.teal : PT.muted,
                ),
                const SizedBox(width: 7),
                Text(label,
                    style: PT.body().copyWith(color: selected ? PT.ink : PT.muted, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
