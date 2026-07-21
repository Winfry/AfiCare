import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/referral_provider.dart';
import '../../models/referral_model.dart';
import '../../utils/theme.dart';

class ReferralReceivingPortalScreen extends StatefulWidget {
  final String? referralId;

  const ReferralReceivingPortalScreen({super.key, this.referralId});

  @override
  State<ReferralReceivingPortalScreen> createState() => _ReferralReceivingPortalScreenState();
}

class _ReferralReceivingPortalScreenState extends State<ReferralReceivingPortalScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _referral;
  String? _error;
  final _notesController = TextEditingController();
  String? _declineReason;

  @override
  void initState() {
    super.initState();
    if (widget.referralId != null) {
      _loadReferral();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadReferral() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('referrals')
          .select('*, users!referrals_patient_id_fkey(full_name, medilink_id)')
          .eq('id', widget.referralId!)
          .single();
      setState(() {
        _referral = Map<String, dynamic>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load referral: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptReferral() async {
    if (_referral == null) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ReferralProvider>();
      await provider.updateReferralStatus(
        _referral!['id'] as String,
        ReferralStatus.accepted,
        responseNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      _referral!['status'] = 'accepted';
      setState(() => _isLoading = false);
      if (context.mounted) {
        _showSchedulingDialog(context, _referral!);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to accept: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _declineReferral() async {
    if (_referral == null) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ReferralProvider>();
      final notes = [
        if (_declineReason != null) 'Reason: $_declineReason',
        if (_notesController.text.isNotEmpty) _notesController.text,
      ].join('\n');
      await provider.updateReferralStatus(
        _referral!['id'] as String,
        ReferralStatus.declined,
        responseNotes: notes.isNotEmpty ? notes : null,
      );
      _referral!['status'] = 'rejected';
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to decline: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Portal'),
        backgroundColor: AfiCareTheme.primaryBlue,
        actions: [
          if (_referral != null && _referral!['status'] == 'pending')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.orange,
                radius: 12,
                child: Text('!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReferral,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _referral == null
                  ? _buildNoReferral(context)
                  : isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildNoReferral(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No referral linked', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Access this page via a secure referral link or QR code',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SizedBox(
          width: 800,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildReferralSummary()),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildActionPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildReferralSummary(),
          const SizedBox(height: 16),
          _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildReferralSummary() {
    final r = _referral!;
    final patient = r['users'] as Map<String, dynamic>? ?? {};
    final status = r['status'] as String? ?? 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: AfiCareTheme.primaryBlue, size: 28),
                const SizedBox(width: 8),
                const Text('Referral Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            _infoRow('Patient', patient['full_name'] as String? ?? 'Unknown'),
            _infoRow('MediLink ID', patient['medilink_id'] as String? ?? '-'),
            const SizedBox(height: 12),
            _infoRow('From Provider', r['from_provider_id'] as String? ?? '-'),
            _infoRow('Specialty Needed', r['to_specialty'] as String? ?? '-'),
            _infoRow('Facility', r['to_facility'] as String? ?? '-'),
            const SizedBox(height: 12),
            _urgencyBadge(r['urgency'] as String? ?? 'routine'),
            const SizedBox(height: 8),
            _statusBadge(status),
            const SizedBox(height: 16),
            const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(r['reason'] as String? ?? '', style: const TextStyle(fontSize: 15)),
            if (r['clinical_notes'] != null && (r['clinical_notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Clinical Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(r['clinical_notes'] as String, style: TextStyle(color: Colors.grey[700])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel() {
    final status = _referral!['status'] as String? ?? 'pending';

    if (status != 'pending') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                status == 'accepted' ? Icons.check_circle : Icons.cancel,
                size: 64,
                color: status == 'accepted' ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                status == 'accepted' ? 'Referral Accepted' : 'Referral Declined',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                status == 'accepted'
                    ? 'You have accepted this referral'
                    : 'This referral has been declined',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Response', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _acceptReferral,
                icon: const Icon(Icons.check),
                label: const Text('Accept Referral'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _showDeclineForm(),
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('Decline', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_declineReason != null) ...[
              const SizedBox(height: 12),
              const Text('Decline Reason', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Chip(
                label: Text(_declineReason!, style: const TextStyle(fontSize: 12)),
                onDeleted: () => setState(() => _declineReason = null),
              ),
            ],
            if (_declineReason != null || _notesController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  hintText: 'Optional notes about your response',
                  isDense: true,
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _urgencyBadge(String urgency) {
    final color = urgency == 'emergency'
        ? Colors.red
        : urgency == 'urgent'
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${urgency[0].toUpperCase()}${urgency.substring(1)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final config = status == 'pending'
        ? {'label': 'Awaiting Response', 'color': Colors.orange}
        : status == 'accepted'
            ? {'label': 'Accepted', 'color': Colors.green}
            : {'label': 'Resolved', 'color': Colors.grey};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        config['label'] as String,
        style: TextStyle(color: config['color'] as Color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  void _showDeclineForm() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you declining?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...['Out of specialty', 'No capacity', 'Incorrect referral', 'Patient declined', 'Other'].map((r) => RadioListTile<String>(
              title: Text(r),
              value: r,
              groupValue: _declineReason,
              onChanged: (v) {
                setState(() => _declineReason = v);
                Navigator.pop(ctx);
              },
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  void _showSchedulingDialog(BuildContext context, Map<String, dynamic> referral) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Appointment'),
        content: const Text('A scheduling form will be pre-filled with this referral information.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scheduling form ready')),
              );
            },
            child: const Text('Schedule Now'),
          ),
        ],
      ),
    );
  }
}