import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dependent_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../utils/theme.dart';

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
      appBar: AppBar(
        title: const Text('Manage Dependents'),
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(),
        backgroundColor: AfiCareTheme.primaryGreen,
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: dep.dependents.length,
            itemBuilder: (ctx, i) =>
                _buildDependentCard(dep, dep.dependents[i]),
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
            Icon(Icons.child_care, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No dependents added yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a child or family member to manage their health records under your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependentCard(DependentProvider dep, DependentProfileModel d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.15),
                  child: Text(
                    d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AfiCareTheme.primaryGreen),
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
                          _buildBadge(
                              _capitalize(d.relationship), Colors.blue),
                          if (d.gender != null) ...[
                            const SizedBox(width: 6),
                            _buildBadge(
                                _capitalize(d.gender!), Colors.purple),
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
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
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
                if (d.bloodType != null)
                  _infoChip(Icons.bloodtype, d.bloodType!),
                _infoChip(
                    Icons.badge_outlined, d.medilinkId ?? 'No ID'),
              ],
            ),
          ],
        ),
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
          backgroundColor: ok ? Colors.green : Colors.red,
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
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) widget.onSaved();
    }
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Amani Waweru',
              ),
            ),
            const SizedBox(height: 16),

            // Relationship
            const Text('Relationship *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select relationship',
              ),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select gender',
              ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select blood type',
              ),
              items: _bloodTypes
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodType = v),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
                  backgroundColor: AfiCareTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
