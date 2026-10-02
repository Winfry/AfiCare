import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/medical_ai_service.dart';
import '../../theme/patient_tokens.dart';
import 'qr_scanner.dart';
import 'widgets/patient_ui.dart';

/// Share Records — choose what leaves the record, who can open it, and
/// for how long. A share is a time-limited, revocable access code; the
/// QR carries that token, never the records themselves.
class ShareRecords extends StatefulWidget {
  const ShareRecords({super.key});

  @override
  State<ShareRecords> createState() => _ShareRecordsState();
}

class _ShareItem {
  const _ShareItem(this.id, this.label);
  final String id;
  final String label;
}

const _shareItems = [
  _ShareItem('basic_info', 'Basic info'),
  _ShareItem('vital_signs', 'Vital signs'),
  _ShareItem('medical_history', 'Medical history'),
  _ShareItem('medications', 'Medications'),
  _ShareItem('lab_results', 'Lab results'),
  _ShareItem('allergies', 'Allergies'),
];

const _durations = [
  (1, '1 hour'),
  (4, '4 hours'),
  (24, '24 hours'),
  (72, '3 days'),
  (168, '7 days'),
];

class _ShareRecordsState extends State<ShareRecords> {
  int _tab = 0; // 0 = Share my records, 1 = Scan QR
  bool _isLoading = false;
  List<Map<String, dynamic>> _shares = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShares());
  }

  // ── Data ──────────────────────────────────────────────────────────────

  Future<void> _loadShares() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('access_codes')
          .select(
              'id, code, expires_at, permissions, is_used, used_by, created_at, users(full_name, department)')
          .eq('patient_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final rows = <Map<String, dynamic>>[];
      for (final row in response as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final usedBy = map['users'] as Map<String, dynamic>?;
        rows.add({
          'id': map['id'],
          'code': map['code'],
          'provider': usedBy != null
              ? (usedBy['full_name'] ?? 'Healthcare provider')
              : 'Anyone with the code',
          'department': usedBy?['department'] ?? '',
          'grantedAt': DateTime.parse(map['created_at'] as String),
          'expiresAt': DateTime.parse(map['expires_at'] as String),
          'permissions': map['permissions'] is List
              ? (map['permissions'] as List).cast<String>()
              : <String>['view_records'],
          'used': (map['is_used'] as bool?) ?? false,
        });
      }

      if (mounted) setState(() => _shares = rows);
    } catch (e) {
      debugPrint('share_records: loading shares failed: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  bool _isLive(Map<String, dynamic> s) =>
      !(s['used'] as bool) && (s['expiresAt'] as DateTime).isAfter(DateTime.now());

  String _shareUrl(String? code) {
    if (code != null) return '${MedicalAIService.backendUrl}/v/$code';
    final id = context.read<AuthProvider>().currentUser?.medilinkId ?? 'unknown';
    return '${MedicalAIService.backendUrl}/v/$id';
  }

  String _generateSecureCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return PDetailScaffold(
      eyebrow: 'Your care',
      title: 'Share Records',
      subtitle: 'Choose what leaves your record, who can open it, and for how long.',
      action: PButton('+ New share', onPressed: _openNewShare),
      children: [
        PTabs(
          tabs: const ['Share my records', 'Scan QR'],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        if (_tab == 1)
          _scanCard()
        else ...[
          PGrid(
            columns: 2,
            children: [_medilinkQrCard(user), _newShareCard()],
          ),
          const SizedBox(height: 16),
          _sharesCard(live: true),
          if (_shares.any((s) => !_isLive(s))) ...[
            const SizedBox(height: 16),
            _sharesCard(live: false),
          ],
        ],
      ],
    );
  }

  // ── Share tab ─────────────────────────────────────────────────────────

  Widget _medilinkQrCard(UserModel? user) {
    final medilinkId = user?.medilinkId ?? '—';
    return PCard(
      child: Column(
        children: [
          const PCardTitle('Your MediLink QR'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PT.white,
              border: Border.all(color: PT.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              label: 'QR code containing your MediLink ID',
              child: QrImageView(
                data: _shareUrl(null),
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
          ),
          const SizedBox(height: 12),
          Text(medilinkId, style: PT.h3()),
          const SizedBox(height: 4),
          Text(
            'Show this at a facility. Scanning it lets them request access, and nothing is '
            'shared until you approve.',
            textAlign: TextAlign.center,
            style: PT.sub(),
          ),
        ],
      ),
    );
  }

  Widget _newShareCard() {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Share a copy of the record'),
          Text(
            'Pick what to include, who can open it and for how long. You can revoke any time.',
            style: PT.sub(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in _shareItems) PBadge(i.label, tone: PTone.blue)],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PButton('+ New share', onPressed: _openNewShare),
              PButton(
                '📷 Scan a QR',
                kind: PButtonKind.alt,
                onPressed: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sharesCard({required bool live}) {
    final rows = _shares.where((s) => _isLive(s) == live).toList();

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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: PT.teal)),
            )
          else if (rows.isEmpty)
            Text(
              live ? 'Nothing is being shared right now.' : 'No past shares.',
              style: PT.sub(),
            )
          else
            for (final s in rows) _shareRow(s, live: live),
        ],
      ),
    );
  }

  Widget _shareRow(Map<String, dynamic> s, {required bool live}) {
    final expiresAt = s['expiresAt'] as DateTime;
    final permissions = (s['permissions'] as List<String>)
        .map((p) => _shareItems
            .firstWhere((i) => i.id == p, orElse: () => _ShareItem(p, p.replaceAll('_', ' ')))
            .label)
        .join(', ');

    final expired = expiresAt.isBefore(DateTime.now());
    final opened = s['used'] as bool;

    return Opacity(
      opacity: live ? 1 : .65,
      child: PRow(
        leadingEmoji: '📤',
        title: s['provider'] as String,
        subtitle: permissions,
        extraSubtitle: live
            ? 'Expires ${DateFormat('d MMM · HH:mm').format(expiresAt)}'
            : (expired ? 'Expired ${DateFormat('d MMM').format(expiresAt)}' : 'Revoked'),
        trailing: live
            ? [
                PButton(
                  'Show QR',
                  kind: PButtonKind.alt,
                  dense: true,
                  onPressed: () => _showShareQr(s),
                ),
                PButton(
                  'Revoke',
                  kind: PButtonKind.red,
                  dense: true,
                  onPressed: () => _confirmRevoke(s),
                ),
              ]
            : [PBadge(expired && !opened ? 'Expired' : 'Revoked', tone: PTone.gray)],
      ),
    );
  }

  // ── Scan tab ──────────────────────────────────────────────────────────

  Widget _scanCard() {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Scan a facility QR'),
          Text(
            'Scanning a facility\'s QR checks you in and shares only what you approve. '
            'Your records are never sent by the code itself.',
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
                      'Point your camera at the facility\'s QR code.',
                      textAlign: TextAlign.center,
                      style: PT.sub().copyWith(color: const Color(0xFFD6ECE9)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PButton(
                    'Open scanner',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QRScanner()),
                    ),
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

  Future<void> _openNewShare() async {
    final selected = <String>{'basic_info', 'vital_signs'};
    var hours = 24;
    var creating = false;

    await showPModal<void>(
      context: context,
      title: 'New share',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A share is a time-limited code. Anyone you give it to can open only the '
              'categories you pick, until it expires or you revoke it.',
              style: PT.sub(),
            ),
            const SizedBox(height: 18),
            Text('What can they see?', style: PT.h3()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _shareItems)
                  _SelectPill(
                    label: item.label,
                    selected: selected.contains(item.id),
                    onTap: () => setSheetState(() {
                      if (!selected.remove(item.id)) selected.add(item.id);
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
                for (final d in _durations)
                  _SelectPill(
                    label: d.$2,
                    selected: hours == d.$1,
                    onTap: () => setSheetState(() => hours = d.$1),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            PButton(
              creating ? 'Creating…' : 'Create share',
              expand: true,
              onPressed: creating
                  ? null
                  : () async {
                      if (selected.isEmpty) {
                        pToast(ctx, 'Pick at least one category to share.');
                        return;
                      }
                      setSheetState(() => creating = true);
                      final code = await _createShare(selected.toList(), hours);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (code != null && mounted) _showCodeCreated(code, hours);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _createShare(List<String> permissions, int hours) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;

    try {
      final code = _generateSecureCode();
      await Supabase.instance.client.from('access_codes').insert({
        'patient_id': user.id,
        'code': code,
        'expires_at': DateTime.now().add(Duration(hours: hours)).toIso8601String(),
        'permissions': permissions,
        'created_at': DateTime.now().toIso8601String(),
        'is_used': false,
      });
      await _loadShares();
      return code;
    } catch (e) {
      debugPrint('share_records: creating share failed: $e');
      if (mounted) pToast(context, 'Could not create the share. Please try again.');
      return null;
    }
  }

  void _showCodeCreated(String code, int hours) {
    final url = _shareUrl(code);
    showPModal<void>(
      context: context,
      title: 'Share created',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valid for ${_durations.firstWhere((d) => d.$1 == hours).$2}. Revoke any time.',
              style: PT.sub()),
          const SizedBox(height: 16),
          Center(child: _qrBox(url)),
          const SizedBox(height: 14),
          Center(child: Text(code, style: PT.h3().copyWith(letterSpacing: 2))),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PButton(
                  'Copy link',
                  kind: PButtonKind.alt,
                  expand: true,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    pToast(ctx, 'Share link copied');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  'Send',
                  expand: true,
                  onPressed: () => Share.share(
                    'Access my medical records via AfiCare: $url\n\nThis link expires.',
                    subject: 'AfiCare Medical Records',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShareQr(Map<String, dynamic> s) {
    final url = _shareUrl(s['code'] as String?);
    showPModal<void>(
      context: context,
      title: 'Share QR',
      builder: (ctx) => Column(
        children: [
          _qrBox(url),
          const SizedBox(height: 14),
          Text('${s['code']}', style: PT.h3().copyWith(letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(
            'Expires ${DateFormat('d MMM · HH:mm').format(s['expiresAt'] as DateTime)}',
            style: PT.sub(),
          ),
          const SizedBox(height: 18),
          PButton(
            'Copy link',
            kind: PButtonKind.alt,
            expand: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              pToast(ctx, 'Share link copied');
            },
          ),
        ],
      ),
    );
  }

  Widget _qrBox(String data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PT.white,
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(12),
      ),
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
    );
  }

  void _confirmRevoke(Map<String, dynamic> s) {
    showPModal<void>(
      context: context,
      title: 'Revoke this share?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The code stops working immediately. Anyone holding it will no longer be able to '
            'open your records.',
            style: PT.sub(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PButton(
                  'Cancel',
                  kind: PButtonKind.alt,
                  expand: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  'Revoke',
                  kind: PButtonKind.red,
                  expand: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _revoke(s['id'] as String?);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(String? id) async {
    if (id == null) return;
    try {
      await Supabase.instance.client.from('access_codes').update({
        'is_used': true,
        'used_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('share_records: revoking failed: $e');
    }
    await _loadShares();
    if (mounted) pToast(context, 'Access revoked');
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
    return Material(
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
    );
  }
}
