import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/care_team_member_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/care_team_provider.dart';

/// Care team section shown at the top of the Appointments screen.
/// Shows confirmed team members as cards with a quick-Book button,
/// plus auto-suggested providers from appointment history.
class CareTeamSection extends StatefulWidget {
  final String patientId;
  final void Function(UserModel provider) onBookFromCareTeam;

  const CareTeamSection({
    super.key,
    required this.patientId,
    required this.onBookFromCareTeam,
  });

  @override
  State<CareTeamSection> createState() => _CareTeamSectionState();
}

class _CareTeamSectionState extends State<CareTeamSection> {
  static const _navy = Color(0xFF1D3557);
  static const _slate = Color(0xFF55708A);
  static const _line = Color(0xFFDCE3EA);
  static const _ink = Color(0xFF152A45);
  static const _navyBg = Color(0xFFE8EDF3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(CareTeamSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final ct = Provider.of<CareTeamProvider>(context, listen: false);
    await ct.loadCareTeam(widget.patientId);
    await ct.fetchSuggestions(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CareTeamProvider>(
      builder: (ctx, ct, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, color: _navy, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'My Care Team',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddProviderSheet(ct),
                    icon: const Icon(Icons.add, size: 16, color: _navy),
                    label:
                        const Text('Add', style: TextStyle(color: _navy)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4)),
                  ),
                ],
              ),

              if (ct.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (ct.members.isEmpty && ct.suggestions.isEmpty)
                _buildEmptyState()
              else ...[
                if (ct.members.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 500) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: ct.members
                              .map((m) => SizedBox(
                                    width:
                                        (constraints.maxWidth - 12) / 2,
                                    child:
                                        _buildMemberCard(ct, m),
                                  ))
                              .toList(),
                        );
                      }
                      return SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: ct.members.length,
                          itemBuilder: (ctx, i) =>
                              _buildMemberCard(ct, ct.members[i]),
                        ),
                      );
                    },
                  ),
                ],
                if (ct.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Suggested from your history',
                    style: TextStyle(
                        fontSize: 13,
                        color: _slate,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 68,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ct.suggestions.length,
                      itemBuilder: (ctx, i) =>
                          _buildSuggestionCard(ct, ct.suggestions[i]),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF3FC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_outlined,
                  size: 26, color: _navy),
            ),
            const SizedBox(height: 10),
            const Text(
              'No care team members yet',
              style: TextStyle(
                  color: _ink, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add your specialists for quick booking',
              style: TextStyle(color: _slate, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(
      CareTeamProvider ct, CareTeamMemberModel m) {
    final isCustom = m.providerId == widget.patientId;
    final notes = _parseNotes(m.notes);
    final phone = notes['phone'] as String?;
    final hospital = notes['hospital'] as String?;
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: SizedBox(
        width: 165,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _navyBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCustom
                          ? Icons.person_add_alt
                          : Icons.medical_services,
                      size: 14,
                      color: _navy,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () =>
                        _showEditDialog(ct, m, phone, hospital),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.edit,
                          size: 12, color: Color(0xFF55708A)),
                    ),
                  ),
                  if (m.isPrimary)
                    const Icon(Icons.star,
                        size: 12, color: Color(0xFFF3A83C)),
                  InkWell(
                    onTap: () => _confirmRemove(ct, m),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close,
                          size: 13, color: Color(0xFF55708A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isCustom
                    ? (m.specialtyLabel ?? m.providerName)
                    : m.providerName,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCustom)
                Text(
                  m.specialtyLabel ?? m.providerRole,
                  style: const TextStyle(
                      fontSize: 11, color: _slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (phone != null)
                Text(phone,
                    style: const TextStyle(
                        fontSize: 10.5, color: _slate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              if (hospital != null)
                Text(hospital,
                    style: const TextStyle(
                        fontSize: 10.5, color: _slate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              const Spacer(),
              if (!isCustom)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        widget.onBookFromCareTeam(UserModel(
                      id: m.providerId,
                      email: '',
                      fullName: m.providerName,
                      role: m.providerRole == 'nurse'
                          ? UserRole.nurse
                          : UserRole.doctor,
                      createdAt: DateTime.now(),
                    )),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                    child: const Text('Book'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(CareTeamProvider ct, UserModel u) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: InkWell(
        onTap: () => _addSuggested(ct, u),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 15, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        u.fullName,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                      Text(
                        u.role.name,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: _slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addSuggested(
      CareTeamProvider ct, UserModel u) async {
    final ok = await ct.addMember(widget.patientId, u.id);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${u.fullName} added to your care team'),
        backgroundColor: _navy,
      ));
    }
  }

  Future<void> _confirmRemove(
      CareTeamProvider ct, CareTeamMemberModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from Care Team?'),
        content:
            Text('Remove ${m.providerName} from your care team?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ct.removeMember(m.id, widget.patientId);
    }
  }

  Map<String, dynamic> _parseNotes(String? notes) {
    if (notes == null || notes.isEmpty) return {};
    try {
      final decoded = jsonDecode(notes);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {}
    return {};
  }

  void _showEditDialog(CareTeamProvider ct,
      CareTeamMemberModel m, String? currentPhone, String? currentHospital) {
    final phoneCtrl = TextEditingController(text: currentPhone);
    final hospitalCtrl =
        TextEditingController(text: currentHospital);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(m.providerId == widget.patientId
            ? 'Edit details'
            : m.providerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. 0712 345 678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hospitalCtrl,
              decoration: const InputDecoration(
                labelText: 'Hospital / Clinic',
                hintText: 'e.g. Kenyatta National Hospital',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              final hospital = hospitalCtrl.text.trim();
              await ct.updateMemberNotes(
                  m.id,
                  widget.patientId,
                  phone.isNotEmpty ? phone : null,
                  hospital.isNotEmpty ? hospital : null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddProviderSheet(CareTeamProvider ct) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: _AddProviderSheet(
          patientId: widget.patientId,
          existingProviderIds:
              ct.members.map((m) => m.providerId).toList(),
          onAdded: (providerId, label, {customName}) =>
              providerId != null
                  ? ct.addMember(widget.patientId, providerId,
                      specialtyLabel: label)
                  : ct.addCustomMember(widget.patientId,
                      customName ?? label ?? ''),
        ),
      ),
    );
  }
}

// ── Add Provider dialog ─────────────────────────────────

class _AddProviderSheet extends StatefulWidget {
  final String patientId;
  final List<String> existingProviderIds;
  final Future<bool> Function(String? providerId, String? label,
      {String? customName}) onAdded;

  const _AddProviderSheet({
    required this.patientId,
    required this.existingProviderIds,
    required this.onAdded,
  });

  @override
  State<_AddProviderSheet> createState() => _AddProviderSheetState();
}

class _AddProviderSheetState extends State<_AddProviderSheet> {
  static const _navy = Color(0xFF1D3557);
  static const _line = Color(0xFFDCE3EA);

  List<UserModel> _providers = [];
  UserModel? _selected;
  final _labelController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        setState(() {
          _providers = (response as List)
              .map(
                  (j) => UserModel.fromJson(j as Map<String, dynamic>))
              .where(
                  (u) => !widget.existingProviderIds.contains(u.id))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim().isEmpty
        ? null
        : _labelController.text.trim();

    final providerId = _selected?.id;

    if (providerId == null && label == null) return;
    setState(() => _submitting = true);

    final ok = await widget.onAdded(
      providerId,
      label,
      customName: providerId == null ? label : null,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Added to your care team'
            : 'Could not add \u2014 try again'),
        backgroundColor: ok ? _navy : Colors.red,
      ));
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 1.5),
      ),
      hintText: hint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add to Care Team',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Label this provider',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'e.g. My Cardiologist, Family Doctor',
              style: TextStyle(fontSize: 12, color: Color(0xFF55708A)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                  'e.g. Cardiologist at Moi Hospital'),
            ),
            const SizedBox(height: 20),
            const Text('Attach to provider',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _providers.isEmpty
                    ? const Text(
                        'All providers are already in your care team.',
                        style: TextStyle(color: Color(0xFF55708A)),
                      )
                    : DropdownButtonFormField<UserModel>(
                        value: _selected,
                        isExpanded: true,
                        decoration: _fieldDecoration(
                            'Pick the provider this label refers to'),
                        items: _providers
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                      '${p.fullName} (${p.role.name})',
                                      overflow:
                                          TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selected = v),
                      ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_submitting ||
                        (_selected == null &&
                            _labelController.text.trim().isEmpty))
                    ? null
                    : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.group_add),
                label: Text(
                    _submitting ? 'Adding\u2026' : 'Add to Care Team'),
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
