import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/care_team_member_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/care_team_provider.dart';
import '../../../widgets/avatar_picker.dart';
import '../../../widgets/provider_avatar.dart';

/// Care team section shown at the top of the Appointments screen.
/// A horizontal scrollable row of fixed-width cards sitting directly
/// on the page background, with an "Add member" card at the end of
/// the row plus auto-suggested providers from appointment history.
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
  static const _greyLight = Color(0xFFF1F3F5);

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text('My care team',
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
            ),
            // Loading
            if (ct.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            // Empty state — just the add card
            else if (ct.members.isEmpty && ct.suggestions.isEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAddCard(),
                  ],
                ),
              )
            // Has members — horizontal scroll row
            else ...[
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: ct.members.length + 1, // +1 for add card
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (ctx, i) {
                    if (i == ct.members.length) return _buildAddCard();
                    return _buildCareCard(ct, ct.members[i]);
                  },
                ),
              ),
              // Suggestions row below
              if (ct.suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Suggested from your history',
                    style: TextStyle(
                        fontSize: 13,
                        color: _slate,
                        fontWeight: FontWeight.w500)),
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
        );
      },
    );
  }

  Widget _buildCareCard(CareTeamProvider ct, CareTeamMemberModel m) {
    final isCustom = m.providerId == widget.patientId;
    final notes = _parseNotes(m.notes);
    final phone = notes['phone'] as String?;
    final hospital = notes['hospital'] as String?;

    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Remove button (top-right)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => _confirmRemove(ct, m),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: _greyLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 11, color: _slate),
              ),
            ),
          ),
          // Content — tapping the card body opens the edit dialog
          GestureDetector(
            onTap: () => _showEditDialog(ct, m, phone, hospital),
            behavior: HitTestBehavior.translucent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo circle (52x52)
                ProviderAvatar(
                  name: m.providerName,
                  role: m.providerRole == 'nurse'
                      ? UserRole.nurse
                      : UserRole.doctor,
                  gender: m.providerGender,
                  photoUrl: m.providerPhotoUrl,
                  patientId: widget.patientId,
                  providerId: m.providerId,
                  radius: 26,
                  onChooseAvatar: () => showAvatarPicker(
                    context: context,
                    patientId: widget.patientId,
                    providerId: m.providerId,
                  ).then((_) {
                    if (mounted) setState(() {});
                  }),
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  isCustom
                      ? (m.specialtyLabel ?? m.providerName)
                      : m.providerName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Role
                Text(
                  isCustom ? '' : (m.specialtyLabel ?? m.providerRole),
                  style: const TextStyle(fontSize: 12, color: _slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Book button
                if (!isCustom)
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => widget.onBookFromCareTeam(UserModel(
                        id: m.providerId,
                        email: '',
                        fullName: m.providerName,
                        role: m.providerRole == 'nurse'
                            ? UserRole.nurse
                            : UserRole.doctor,
                        createdAt: DateTime.now(),
                      )),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _navyBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Book',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _navy)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: () {
        final ct = Provider.of<CareTeamProvider>(context, listen: false);
        _showAddProviderSheet(ct);
      },
      child: Container(
        width: 148,
        height: 220,
        decoration: BoxDecoration(
          color: _greyLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _line, width: 1.5),
              ),
              child: const Icon(Icons.add, size: 18, color: _navy),
            ),
            const SizedBox(height: 8),
            const Text('Add member',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _slate)),
          ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 15, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        u.fullName,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        u.role.name,
                        style:
                            const TextStyle(fontSize: 10.5, color: _slate),
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
