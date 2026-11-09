import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/patient_tokens.dart';
import 'package:provider/provider.dart';

import '../../models/patient_profile_model.dart';
import '../../presentation/auth/register/patient/utils/phone_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../utils/theme.dart';
import 'widgets/patient_photo_avatar.dart';
import 'widgets/patient_ui.dart';
import 'widgets/pin_account_dialogs.dart';

/// B2 — Patient Profile (Edit)
class PatientProfileEditScreen extends StatefulWidget {
  const PatientProfileEditScreen({super.key});

  @override
  State<PatientProfileEditScreen> createState() =>
      _PatientProfileEditScreenState();
}

class _PatientProfileEditScreenState extends State<PatientProfileEditScreen> {
  bool _isLoading = true;
  /// Her profile didn't load: Save would write an empty (or old) form over
  /// her real allergies, conditions and date of birth, so it is blocked.
  bool _loadFailed = false;
  /// Why Save didn't go ahead, shown above the button.
  String? _problem;
  bool _saving = false;
  bool _savingPhoto = false;

  /// Takes, chooses or removes her photo. It is saved straight away (not
  /// with Save), and the message says whether it really was.
  Future<void> _changePhoto() async {
    final auth = context.read<AuthProvider>();
    final hasPhoto = (auth.currentUser?.photoUrl ?? '').isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Only you, anyone you look after the account for, and the '
                'clinicians caring for you can see your photo.',
              ),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheet, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    Uint8List? bytes;
    var contentType = 'image/jpeg';
    if (choice != 'remove') {
      final XFile? picked;
      try {
        picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
      } catch (e) {
        debugPrint('Photo picker failed: $e');
        if (mounted) pToast(context, "Couldn't open your photos. Check AfiCare may use them.");
        return;
      }
      if (picked == null || !mounted) return;
      bytes = await picked.readAsBytes();
      final type = picked.mimeType ?? '';
      if (type.startsWith('image/')) {
        contentType = type;
      } else if (picked.name.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      }
    }

    setState(() => _savingPhoto = true);
    final problem = await auth.setPatientPhoto(bytes, contentType: contentType);
    if (!mounted) return;
    setState(() => _savingPhoto = false);
    pToast(context, problem ?? (bytes == null ? 'Photo removed' : 'Photo saved'));
  }

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
      _loadFailed = pp.loadFailed;
      final p = pp.profile;
      if (p != null) {
        _dob = p.dateOfBirth;
        _bloodType = _bloodTypes.contains(p.bloodType) ? p.bloodType : null;
        _allergies = List.of(p.allergies);
        _chronic = List.of(p.chronicConditions);
        _emContactName.text = p.emergencyContactName ?? '';
        _emContactPhone.text = p.emergencyContactPhone ?? '';
        _insuranceProvider.text = p.insuranceProvider ?? '';
        _policyNumber.text = p.insuranceId ?? '';
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoading = true;
      _problem = null;
    });
    await _load();
  }

  Future<void> _save() async {
    if (_loadFailed) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = 'Add your name.');
      return;
    }
    final emPhone = _emContactPhone.text.trim();
    String? emPhoneFormatted;
    if (emPhone.isNotEmpty) {
      emPhoneFormatted = PhoneFormatter.format(emPhone);
      if (emPhoneFormatted == null) {
        setState(() => _problem = "The emergency contact's phone doesn't look right. Use a Kenyan number, like 0712 345 678.");
        return;
      }
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pp = Provider.of<PatientProfileProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    // A PIN account's phone is changed only through its own dialog (it is
    // part of how they log in), so it is never sent from here.
    String? phone;
    if (!auth.usesPinLogin && _phoneController.text.trim().isNotEmpty) {
      phone = PhoneFormatter.format(_phoneController.text);
      if (phone == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid Kenyan phone number, like 0712 345 678.'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    // 1) users table (name + phone)
    final userOk = await auth.updateProfile(
      fullName: name,
      phone: phone,
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
      emergencyContactPhone: emPhoneFormatted,
      address: pp.profile?.address,
      insuranceId: _policyNumber.text.trim().isEmpty
          ? null
          : _policyNumber.text.trim(),
      insuranceProvider: _insuranceProvider.text.trim().isEmpty
          ? null
          : _insuranceProvider.text.trim(),
    );
    final profileOk = await pp.saveProfile(profile);
    final ok = userOk && profileOk;

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Profile saved'
            : !userOk && profileOk
                ? 'Your health details were saved, but your name and phone were not. Please try again.'
                : 'Could not save profile'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  Future<void> _changePhone() async {
    final changed = await showChangePhoneDialog(context);
    if (!changed || !mounted) return;
    final phone = context.read<AuthProvider>().currentUser?.phone ?? '';
    setState(() => _phoneController.text = phone.replaceFirst('+254', ''));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Phone number changed. Use it next time you log in.'),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final usesPin = context.watch<AuthProvider>().usesPinLogin;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const PSubPageBar(title: 'Edit profile'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          if (_problem != null) ...[
            PCallout(tone: PTone.red, body: _problem!),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || _loadFailed || _isLoading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const PLoadingPage()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                if (_loadFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: PCallout(
                      tone: PTone.warn,
                      title: "Your profile didn't load",
                      body: "So nothing can be saved yet: saving now could erase details you've "
                          'added before, like allergies. Check your connection and try again.',
                      trailing: PButton('Try again', kind: PButtonKind.alt, dense: true, onPressed: _retryLoad),
                    ),
                  ),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Change photo',
                    child: InkWell(
                      onTap: _savingPhoto ? null : _changePhoto,
                      customBorder: const CircleBorder(),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) => PatientPhotoAvatar(
                                  name: auth.currentUser?.fullName ?? '',
                                  storedPhoto: auth.currentUser?.photoUrl,
                                  size: 100,
                                ),
                              ),
                              if (_savingPhoto)
                                const Positioned.fill(
                                  child: Center(child: CircularProgressIndicator()),
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
                          Text(_savingPhoto ? 'SAVING PHOTO…' : 'CHANGE PHOTO',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: PT.muted)),
                        ],
                      ),
                    ),
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
                          if (usesPin)
                            TextField(
                              controller: _phoneController,
                              readOnly: true,
                              decoration: InputDecoration(
                                helperText: 'You log in with this number.',
                                suffixIcon: TextButton(
                                  onPressed: _changePhone,
                                  child: const Text('Change'),
                                ),
                              ),
                            )
                          else
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
                                    ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
                                    : 'Select',
                                style: TextStyle(
                                    color: _dob != null
                                        ? Colors.black87
                                        : PT.muted),
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
                TextField(
                  controller: _insuranceProvider,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. SHA, AAR, Jubilee, CIC'),
                ),
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
              color: PT.muted,
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
