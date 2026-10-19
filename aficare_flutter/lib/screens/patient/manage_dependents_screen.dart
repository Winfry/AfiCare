import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/caregiver_model.dart';
import '../../models/dependent_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../services/caregiver_service.dart';
import '../../theme/patient_tokens.dart';
import '../../utils/default_avatars.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// Everyone the signed-in person looks after, in one list, because to them
/// it is one idea. Underneath there are two different things:
///
///  * **Dependants**: profiles this account owns, for people without an
///    account of their own (a child, a parent who doesn't use a phone).
///    Editable here, and switchable to from the profile menu.
///  * **Shared with you**: people with their own account who gave this
///    person a caregiver code. Read-only, and theirs to stop.
class ManageDependentsScreen extends StatefulWidget {
  const ManageDependentsScreen({super.key});

  @override
  State<ManageDependentsScreen> createState() =>
      _ManageDependentsScreenState();
}

class _ManageDependentsScreenState extends State<ManageDependentsScreen> {
  final _caregiver = CaregiverService();
  List<CaregiverLink> _shared = [];
  bool _sharedLoading = true;
  bool _sharedFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadShared();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) await dep.loadDependents(uid);
  }

  Future<void> _loadShared() async {
    try {
      final shared = await _caregiver.peopleICareFor();
      if (!mounted) return;
      setState(() {
        _shared = shared;
        _sharedFailed = false;
      });
    } on CaregiverException {
      if (mounted) setState(() => _sharedFailed = true);
    } finally {
      if (mounted) setState(() => _sharedLoading = false);
    }
  }

  Future<void> _enterCode() async {
    final name = await showPModal<String>(
      context: context,
      title: 'Enter a caregiver code',
      builder: (ctx) => _EnterCodeForm(onRedeem: _caregiver.redeem),
    );
    if (name == null || !mounted) return;
    pToast(context, "You can now see $name's shared record.");
    await _loadShared();
  }

  void _openShared(CaregiverLink link) =>
      context.go('${PatientRoutes.dependents}/shared/${Uri.encodeComponent(link.accessId)}');

  @override
  Widget build(BuildContext context) {
    final dep = context.watch<DependentProvider>();
    if (dep.isLoading && dep.dependents.isEmpty && _sharedLoading) return const PLoadingPage();

    return PSliverPage(
      eyebrow: 'Family & caregiving',
      title: 'People I care for',
      subtitle: 'Profiles you manage for family, and records others have shared with you.',
      action: PButton('Add a dependant', icon: Icons.person_add_alt_1_outlined, onPressed: () => _showFormSheet()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PHeading('You manage these profiles'),
              _managedCard(dep),
              const SizedBox(height: 29),
              PHeading(
                'Shared with you',
                action: PButton('Enter a code', kind: PButtonKind.alt, dense: true, icon: Icons.key_rounded, onPressed: _enterCode),
              ),
              _sharedCard(),
              const SizedBox(height: 29),
              const PHeading("What's the difference?"),
              PCard(
                padding: const EdgeInsets.all(21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _explainer(
                      Icons.family_restroom_outlined,
                      'A dependant has no account of their own',
                      'Like a young child. You create their profile, add their details and book for them.',
                    ),
                    const SizedBox(height: 14),
                    _explainer(
                      Icons.handshake_outlined,
                      'A shared record belongs to them',
                      'They use AfiCare themselves and gave you a code. You can look, not change anything, '
                          'and they can stop sharing at any time.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _explainer(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PSoftIcon(icon, size: 36),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PT.rowTitle()),
              const SizedBox(height: 2),
              Text(body, style: PT.rowSub()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _managedCard(DependentProvider dep) {
    if (dep.error != null && dep.dependents.isEmpty) {
      return PLoadError(what: 'the profiles you manage', onRetry: _load);
    }
    return PCard(
      padding: const EdgeInsets.all(15),
      child: dep.dependents.isEmpty
          ? PEmpty(
              emoji: '👶',
              title: 'No dependants yet',
              body: 'Add a child or family member who has no AfiCare account, '
                  'and keep their health records under yours.',
              action: PButton('Add a dependant', icon: Icons.person_add_alt_1_outlined, onPressed: () => _showFormSheet()),
            )
          : Column(children: [for (final d in dep.dependents) _dependentRow(dep, d)]),
    );
  }

  Widget _sharedCard() {
    if (_sharedLoading) {
      return const PCard(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: PT.teal)),
      );
    }
    if (_sharedFailed) return PLoadError(what: 'records shared with you', onRetry: _loadShared);
    return PCard(
      padding: const EdgeInsets.all(15),
      child: _shared.isEmpty
          ? PEmpty(
              emoji: '🤝',
              title: 'Nobody has shared with you yet',
              body: 'When someone gives you a caregiver code from their AfiCare app, enter it here '
                  'to follow their appointments, medicines and more.',
              action: PButton('Enter a code', icon: Icons.key_rounded, onPressed: _enterCode),
            )
          : Column(
              children: [
                for (final s in _shared)
                  PRow(
                    leading: PAvatar(initials: DefaultAvatar.initials(s.patientName)),
                    title: s.patientName,
                    subtitle: CaregiverAccess.accessLevelScope(s.accessLevel),
                    extraSubtitle: [
                      'View only',
                      if (s.since != null) 'since ${DateFormat('d MMM yyyy').format(s.since!)}',
                    ].join(' · '),
                    trailing: const [Icon(Icons.chevron_right_rounded, color: PT.muted)],
                    onTap: () => _openShared(s),
                  ),
              ],
            ),
    );
  }

  Widget _dependentRow(DependentProvider dep, DependentProfileModel d) {
    final facts = [
      _capitalize(d.relationship),
      if (d.gender != null) _capitalize(d.gender!),
      if (d.dateOfBirth != null) 'Born ${DateFormat('d MMM yyyy').format(d.dateOfBirth!)}',
    ].join(' · ');
    final ids = [
      d.medilinkId ?? 'No MediLink ID yet',
      if (d.bloodType != null) 'Blood ${d.bloodType}',
    ].join(' · ');

    final controls = [
      PButton('Edit', kind: PButtonKind.alt, dense: true, onPressed: () => _showFormSheet(existing: d)),
      PButton('Remove', kind: PButtonKind.alt, dense: true, onPressed: () => _confirmDelete(dep, d)),
    ];
    final mobile = PT.isMobile(context);

    return PRow(
      leading: PAvatar(initials: DefaultAvatar.initials(d.fullName), isDependent: true),
      title: d.fullName,
      subtitle: facts,
      extraSubtitle: ids,
      trailing: mobile ? const [] : [controls[0], controls[1]],
      below: (d.allergies.isEmpty && !mobile)
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shown on the row itself: an allergy is only useful if
                  // it is seen without opening anything.
                  if (d.allergies.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final a in d.allergies) PBadge('Allergy: $a', tone: PTone.red)],
                    ),
                  if (mobile) ...[
                    if (d.allergies.isNotEmpty) const SizedBox(height: 10),
                    Row(children: [controls[0], const SizedBox(width: 8), controls[1]]),
                  ],
                ],
              ),
            ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _confirmDelete(
      DependentProvider dep, DependentProfileModel d) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final guardianId = auth.currentUser?.id ?? '';

    final confirm = await showPModal<bool>(
      context: context,
      title: 'Remove ${d.fullName}?',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Their profile and everything recorded under it will be deleted. This can't be undone.",
              style: PT.sub()),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PButton('Keep', kind: PButtonKind.alt, onPressed: () => Navigator.pop(ctx, false)),
              const SizedBox(width: 8),
              PButton('Remove', kind: PButtonKind.red, onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await dep.deleteDependent(d.id, guardianId);
      if (mounted) pToast(context, ok ? '${d.fullName} removed' : "Couldn't remove them. Please try again.");
    }
  }

  void _showFormSheet({DependentProfileModel? existing}) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DependentFormSheet(
        existing: existing,
        onSaved: _load,
      ),
    );
  }
}

// ── Enter a caregiver code (inside showPModal) ────────────────

/// Pops with the name of the person who shared, once the code is accepted.
class _EnterCodeForm extends StatefulWidget {
  const _EnterCodeForm({required this.onRedeem});

  final Future<String> Function(String code) onRedeem;

  @override
  State<_EnterCodeForm> createState() => _EnterCodeFormState();
}

class _EnterCodeFormState extends State<_EnterCodeForm> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = CaregiverAccess.normaliseCode(_ctrl.text);
    if (code.length != 8) {
      setState(() => _error = 'Codes are 8 letters and numbers, like ABCD-2345.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = await widget.onRedeem(code);
      if (mounted) Navigator.pop(context, name);
    } on CaregiverException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask the person you care for to make a code in their AfiCare app '
          '(More → Share with a caregiver), then type it here.',
          style: PT.sub(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
            LengthLimitingTextInputFormatter(10),
          ],
          style: GoogleFonts.figtree(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3, color: PT.ink),
          textAlign: TextAlign.center,
          decoration: pInput(hint: 'ABCD-2345'),
          onSubmitted: (_) => _saving ? null : _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 12),
        Text("You'll be able to look at what they chose to share, not change it.", style: PT.rowSub()),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Checking…' : 'Use this code', onPressed: _saving ? null : _submit),
        ),
      ],
    );
  }
}

// ── Dependent add/edit form sheet ─────────────────────────────

class _DependentFormSheet extends StatefulWidget {
  final DependentProfileModel? existing;
  final VoidCallback onSaved;

  const _DependentFormSheet({this.existing, required this.onSaved});

  @override
  State<_DependentFormSheet> createState() => _DependentFormSheetState();
}

class _DependentFormSheetState extends State<_DependentFormSheet> {
  final _nameController = TextEditingController();
  String? _gender;
  String? _relationship;
  String? _bloodType;
  DateTime? _dob;
  final _allergies = <String>[];
  final _allergyController = TextEditingController();
  bool _submitting = false;

  // 'parent' matters: a common case is an adult keeping records for an
  // ageing parent, and leaving it out meant editing such a profile
  // silently cleared the relationship.
  static const _relationships = ['child', 'parent', 'grandchild', 'sibling', 'other'];
  static const _genders = ['male', 'female', 'other'];
  static const _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = widget.existing!;
      _nameController.text = d.fullName;
      _gender = d.gender;
      _relationship = d.relationship;
      _bloodType = d.bloodType;
      _dob = d.dateOfBirth;
      _allergies.addAll(d.allergies);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final value = _allergyController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _allergies.add(value);
      _allergyController.clear();
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name is required')),
      );
      return;
    }
    if (_relationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relationship is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final guardianId = auth.currentUser?.id ?? '';

    bool ok;
    if (widget.existing == null) {
      ok = await dep.addDependent(
        guardianId: guardianId,
        fullName: name,
        dateOfBirth: _dob,
        gender: _gender,
        relationship: _relationship!,
        bloodType: _bloodType,
        allergies: _allergies,
      );
    } else {
      ok = await dep.updateDependent(
        widget.existing!.id,
        guardianId: guardianId,
        fullName: name,
        dateOfBirth: _dob,
        gender: _gender,
        relationship: _relationship,
        bloodType: _bloodType,
        // Always sent, so removing the last allergy actually clears it.
        allergies: _allergies,
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? widget.existing == null
                ? '$name added successfully'
                : 'Profile updated'
            : 'Could not save — try again'),
        backgroundColor: ok ? const Color(0xFF1D3557) : Colors.red,
      ));
      if (ok) widget.onSaved();
    }
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E1D8), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E1D8), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1D3557), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                Text(
                  isEdit ? 'Edit Dependent' : 'Add Dependent',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B1B18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Full Name
            const Text('Full Name *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(hintText: 'e.g. Amani Waweru'),
            ),
            const SizedBox(height: 16),

            // Relationship
            const Text('Relationship *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration:
                  _fieldDecoration(hintText: 'Select relationship'),
              items: _relationships
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_capitalize(r)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _relationship = v),
            ),
            const SizedBox(height: 16),

            // Date of Birth
            const Text('Date of Birth',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(2010),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: InputDecorator(
                decoration: _fieldDecoration(
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dob != null
                      ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                      : 'Tap to select',
                  style: TextStyle(
                    color: _dob != null ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gender
            const Text('Gender',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _fieldDecoration(hintText: 'Select gender'),
              items: _genders
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(_capitalize(g)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),

            // Blood Type
            const Text('Blood Type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _bloodType,
              decoration:
                  _fieldDecoration(hintText: 'Select blood type'),
              items: _bloodTypes
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodType = v),
            ),
            const SizedBox(height: 16),

            // Allergies — kept against this profile rather than the
            // guardian's, which is the whole point of migration 032.
            const Text('Allergies',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Anything they react badly to — medicines, foods. This is what a '
              'clinician checks first.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allergyController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addAllergy(),
                    decoration: _fieldDecoration(hintText: 'e.g. Penicillin'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _addAllergy,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_allergies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _allergies)
                    InputChip(
                      label: Text(a),
                      backgroundColor: const Color(0xFFFFF0ED),
                      side: BorderSide.none,
                      deleteIconColor: const Color(0xFFA14D43),
                      labelStyle: const TextStyle(
                          color: Color(0xFFA14D43), fontWeight: FontWeight.w700),
                      onDeleted: () => setState(() => _allergies.remove(a)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(isEdit ? Icons.save : Icons.person_add),
              label: Text(_submitting
                  ? 'Saving…'
                  : isEdit
                      ? 'Save Changes'
                      : 'Add Dependent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D3557),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
