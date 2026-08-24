import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/dependent_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';

class ManageDependentsScreen extends StatefulWidget {
  const ManageDependentsScreen({super.key});

  @override
  State<ManageDependentsScreen> createState() =>
      _ManageDependentsScreenState();
}

class _ManageDependentsScreenState extends State<ManageDependentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) await dep.loadDependents(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
                Border(bottom: BorderSide(color: Color(0xFFDCE3EA), width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const SizedBox(width: 4),
              Text(
                'Manage Dependents',
                style: GoogleFonts.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(),
        backgroundColor: const Color(0xFF1D3557),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Dependent'),
      ),
      body: Consumer<DependentProvider>(
        builder: (ctx, dep, _) {
          if (dep.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (dep.dependents.isEmpty) {
            return _buildEmptyState();
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: dep.dependents.length,
                itemBuilder: (ctx, i) =>
                    _buildDependentCard(dep, dep.dependents[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF3FC),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.child_care, size: 36, color: Color(0xFF1D3557)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No dependents added yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF152A45),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a child or family member to manage\ntheir health records under your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF55708A), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependentCard(DependentProvider dep, DependentProfileModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8EDF3),
                child: Text(
                  d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D3557),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        _buildBadge(_capitalize(d.relationship),
                            const Color(0xFF457B9D)),
                        if (d.gender != null) ...[
                          const SizedBox(width: 6),
                          _buildBadge(
                              _capitalize(d.gender!), const Color(0xFF64B5F6)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _showFormSheet(existing: d);
                  if (v == 'delete') _confirmDelete(dep, d);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (d.dateOfBirth != null)
                _infoChip(
                    Icons.cake,
                    '${d.dateOfBirth!.day}/${d.dateOfBirth!.month}/${d.dateOfBirth!.year}'),
              if (d.bloodType != null) _infoChip(Icons.bloodtype, d.bloodType!),
              _infoChip(Icons.badge_outlined, d.medilinkId ?? 'No ID'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _confirmDelete(
      DependentProvider dep, DependentProfileModel d) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final guardianId = auth.currentUser?.id ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Dependent?'),
        content: Text(
            'Remove ${d.fullName} and all associated data? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await dep.deleteDependent(d.id, guardianId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '${d.fullName} removed'
              : 'Could not delete — try again'),
          backgroundColor: ok ? const Color(0xFF1D3557) : Colors.red,
        ));
      }
    }
  }

  void _showFormSheet({DependentProfileModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DependentFormSheet(
        existing: existing,
        onSaved: _load,
      ),
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
  bool _submitting = false;

  static const _relationships = ['child', 'grandchild', 'sibling', 'other'];
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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
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
                    color: const Color(0xFF152A45),
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
