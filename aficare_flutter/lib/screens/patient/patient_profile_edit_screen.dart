import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../utils/theme.dart';

/// B2 — Patient Profile (Edit)
class PatientProfileEditScreen extends StatefulWidget {
  const PatientProfileEditScreen({super.key});

  @override
  State<PatientProfileEditScreen> createState() =>
      _PatientProfileEditScreenState();
}

class _PatientProfileEditScreenState extends State<PatientProfileEditScreen> {
  bool _isLoading = true;
  bool _saving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emContactName = TextEditingController();
  final _emContactPhone = TextEditingController();
  final _insuranceProvider = TextEditingController();
  final _policyNumber = TextEditingController();

  DateTime? _dob;
  String? _bloodType;
  List<String> _allergies = [];
  List<String> _chronic = [];

  static const _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emContactName.dispose();
    _emContactPhone.dispose();
    _insuranceProvider.dispose();
    _policyNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pp = Provider.of<PatientProfileProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = (user.phone ?? '').replaceFirst('+254', '');
      await pp.loadProfile(user.id);
      final p = pp.profile;
      if (p != null) {
        _dob = p.dateOfBirth;
        _bloodType = _bloodTypes.contains(p.bloodType) ? p.bloodType : null;
        _allergies = List.of(p.allergies);
        _chronic = List.of(p.chronicConditions);
        _emContactName.text = p.emergencyContactName ?? '';
        _emContactPhone.text = p.emergencyContactPhone ?? '';
        _insuranceProvider.text = p.insuranceId != null ? '' : '';
        _policyNumber.text = p.insuranceId ?? '';
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pp = Provider.of<PatientProfileProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    // 1) users table (name + phone)
    await auth.updateProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : '+254${_phoneController.text.trim()}',
    );

    // 2) patients table (medical + insurance)
    final profile = PatientProfileModel(
      id: user.id,
      dateOfBirth: _dob,
      gender: pp.profile?.gender,
      bloodType: _bloodType,
      allergies: _allergies,
      chronicConditions: _chronic,
      emergencyContactName: _emContactName.text.trim().isEmpty
          ? null
          : _emContactName.text.trim(),
      emergencyContactPhone: _emContactPhone.text.trim().isEmpty
          ? null
          : _emContactPhone.text.trim(),
      address: pp.profile?.address,
      insuranceId: _policyNumber.text.trim().isEmpty
          ? null
          : _policyNumber.text.trim(),
    );
    final ok = await pp.saveProfile(profile);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profile saved' : 'Could not save profile'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                AfiCareTheme.primaryGreen.withOpacity(0.1),
                            child: Icon(Icons.person,
                                size: 50,
                                color: AfiCareTheme.primaryGreen),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AfiCareTheme.primaryGreen,
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('CHANGE PHOTO',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeader(Icons.person, 'Personal Details'),
                _label('Full Name'),
                TextField(controller: _nameController),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Code'),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AfiCareTheme.primaryGreen
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('+254'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Phone Number'),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Date of Birth'),
                          InkWell(
                            onTap: _pickDob,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _dob != null
                                    ? '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}'
                                    : 'Select',
                                style: TextStyle(
                                    color: _dob != null
                                        ? Colors.black87
                                        : Colors.grey[500]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Blood Type'),
                          DropdownButtonFormField<String>(
                            value: _bloodType,
                            hint: const Text('Select'),
                            items: _bloodTypes
                                .map((b) => DropdownMenuItem(
                                    value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _bloodType = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionHeader(
                    Icons.medical_services_outlined, 'Medical Information'),
                _label('Allergies'),
                _chipEditor(_allergies, Colors.red),
                const SizedBox(height: 16),
                _label('Chronic Conditions'),
                _chipEditor(_chronic, AfiCareTheme.primaryGreen),
                const SizedBox(height: 16),
                _label('Emergency Contact'),
                TextField(
                  controller: _emContactName,
                  decoration: const InputDecoration(hintText: 'Contact name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emContactPhone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(hintText: 'Contact phone'),
                ),
                const SizedBox(height: 24),
                _sectionHeader(Icons.shield_outlined, 'Insurance'),
                _label('Provider'),
                TextField(controller: _insuranceProvider),
                const SizedBox(height: 16),
                _label('Policy Number'),
                TextField(controller: _policyNumber),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AfiCareTheme.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AfiCareTheme.primaryGreen)),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _chipEditor(List<String> items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...items.map((item) => Chip(
              label: Text(item),
              backgroundColor: color.withOpacity(0.1),
              labelStyle: TextStyle(color: color),
              deleteIconColor: color,
              onDeleted: () => setState(() => items.remove(item)),
            )),
        ActionChip(
          avatar: Icon(Icons.add, size: 16, color: AfiCareTheme.primaryGreen),
          label: const Text('Add'),
          onPressed: () => _addChip(items),
          side: BorderSide(
              color: AfiCareTheme.primaryGreen.withOpacity(0.5)),
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }

  Future<void> _addChip(List<String> items) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter value'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() => items.add(value));
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }
}
