import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/facility_model.dart';
import '../../models/patient_profile_model.dart';
import '../../providers/admin_facility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dependent_provider.dart';
import '../../providers/patient_profile_provider.dart';
import '../../utils/theme.dart';

/// First-run onboarding wizard shown after a patient creates their
/// MediLink ID. Steps: Welcome → Complete profile → Care setup → QR code.
class PatientOnboardingScreen extends StatefulWidget {
  const PatientOnboardingScreen({super.key});

  @override
  State<PatientOnboardingScreen> createState() => _PatientOnboardingScreenState();
}

class _PatientOnboardingScreenState extends State<PatientOnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 2 — Complete profile
  DateTime? _dob;
  String? _gender;
  String? _bloodType;
  final _allergies = <String>[];
  final _allergyController = TextEditingController();
  final _dobController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Step 3 — Care setup
  String? _facilityId;
  final _dependents = <String>[];
  final _depController = TextEditingController();
  List<FacilityModel> _facilities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFacilities());
  }

  Future<void> _loadFacilities() async {
    final provider = Provider.of<AdminFacilityProvider>(context, listen: false);
    await provider.loadFacilities();
    if (!mounted) return;
    setState(() => _facilities = provider.facilities);
  }

  @override
  void dispose() {
    _allergyController.dispose();
    _dobController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _depController.dispose();
    super.dispose();
  }

  String get _firstName {
    final name = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.fullName
            .trim() ??
        'there';
    return name.split(' ').first;
  }

  String get _medilinkId {
    final id = Provider.of<AuthProvider>(context, listen: false)
        .currentUser
        ?.medilinkId;
    return (id == null || id.isEmpty) ? 'ML-XXX-XXXX' : id;
  }

  Future<void> _saveProfile() async {
    final provider = Provider.of<PatientProfileProvider>(context, listen: false);
    final existing = provider.profile;
    final profile = PatientProfileModel(
      id: existing?.id ??
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
          '',
      dateOfBirth: _dob ?? existing?.dateOfBirth,
      gender: _gender ?? existing?.gender,
      bloodType: _bloodType ?? existing?.bloodType,
      allergies: _allergies.isNotEmpty
          ? List.of(_allergies)
          : (existing?.allergies ?? const <String>[]),
      chronicConditions: existing?.chronicConditions ?? const <String>[],
      emergencyContactName: _emergencyNameController.text.trim().isNotEmpty
          ? _emergencyNameController.text.trim()
          : existing?.emergencyContactName,
      emergencyContactPhone: _emergencyPhoneController.text.trim().isNotEmpty
          ? _emergencyPhoneController.text.trim()
          : existing?.emergencyContactPhone,
      address: existing?.address,
      insuranceId: existing?.insuranceId,
    );
    await provider.saveProfile(profile);
  }

  Future<void> _saveFacilityAndDependents() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dep = Provider.of<DependentProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    if (_facilityId != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'facility_id': _facilityId}).eq('id', userId);
      } catch (_) {}
    }

    for (final name in _dependents) {
      await dep.addDependent(
        guardianId: userId,
        fullName: name,
        relationship: 'family',
      );
    }
  }

  Future<void> _markSkipped() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_skip_$id', true);
  }

  void _goTo(int step) => setState(() => _step = step);

  Future<void> _continueFromProfile() async {
    var dob = _dob;
    final typed = _dobController.text.trim();
    if (dob == null && typed.isNotEmpty) {
      dob = _tryParseDob(typed);
      if (dob != null) {
        _dob = dob;
        _dobController.text = DateFormat('dd/MM/yyyy').format(dob);
      }
    }
    if (dob == null) {
      _showSnack(
        typed.isEmpty
            ? 'Please select your date of birth'
            : 'Please enter a valid date of birth (DD/MM/YYYY)',
      );
      return;
    }
    if (_emergencyNameController.text.trim().isEmpty) {
      _showSnack('Please enter an emergency contact name');
      return;
    }
    if (_emergencyPhoneController.text.trim().isEmpty) {
      _showSnack('Please enter an emergency contact phone');
      return;
    }
    setState(() => _saving = true);
    await _saveProfile();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = 2;
    });
  }

  DateTime? _tryParseDob(String text) {
    final formats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('yyyy-MM-dd'),
    ];
    for (final format in formats) {
      try {
        final parsed = format.parseStrict(text);
        final now = DateTime.now();
        if (parsed.isAfter(now)) return null;
        if (parsed.isBefore(DateTime(now.year - 120))) return null;
        return parsed;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _continueFromCare() async {
    setState(() => _saving = true);
    await _saveFacilityAndDependents();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = 3;
    });
  }

  Future<void> _skipFromWelcome() async {
    await _markSkipped();
    if (!mounted) return;
    context.go('/patient');
  }

  void _finish() {
    context.go('/patient');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AfiCareTheme.clay),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The onboarding is a self-contained light experience. Wrapping it in a
    // light Theme keeps all inherited text colors dark even when the device
    // is in dark mode (the app follows the system theme by default).
    return Theme(
      data: AfiCareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AfiCareTheme.mist,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _WizardTopBar(
                    step: _step,
                    canGoBack: _step > 0,
                    onBack: () => _goTo(_step - 1),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
                      child: switch (_step) {
                        0 => _WelcomeStep(
                          firstName: _firstName,
                          onNext: () => _goTo(1),
                          onSkip: _skipFromWelcome,
                        ),
                        1 => _ProfileStep(
                          dobController: _dobController,
                          gender: _gender,
                          bloodType: _bloodType,
                          allergies: _allergies,
                          allergyController: _allergyController,
                          emergencyNameController: _emergencyNameController,
                          emergencyPhoneController: _emergencyPhoneController,
                          onPickDob: _pickDob,
                          onGenderChanged: (v) => setState(() => _gender = v),
                          onBloodTypeChanged: (v) => setState(() => _bloodType = v),
                        onAddAllergy: _addAllergy,
                        onRemoveAllergy: (a) => setState(() => _allergies.remove(a)),
                        saving: _saving,
                        onContinue: _continueFromProfile,
                      ),
                      2 => _CareStep(
                        facilities: _facilities,
                        facilityId: _facilityId,
                        dependents: _dependents,
                        depController: _depController,
                        onFacilityChanged: (v) => setState(() => _facilityId = v),
                        onAddDependent: _addDependent,
                        onRemoveDependent: (n) => setState(() => _dependents.remove(n)),
                        saving: _saving,
                        onContinue: _continueFromCare,
                        onSkip: () => _goTo(3),
                      ),
                      _ => _QrStep(
                        fullName: Provider.of<AuthProvider>(context).currentUser?.fullName ?? '',
                        medilinkId: _medilinkId,
                        onFinish: _finish,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? _tryParseDob(_dobController.text.trim()) ??
        DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AfiCareTheme.canopy,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _addAllergy() {
    final value = _allergyController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _allergies.add(value);
      _allergyController.clear();
    });
  }

  void _addDependent() {
    final value = _depController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _dependents.add(value);
      _depController.clear();
    });
  }
}

// ── Shared wizard chrome ────────────────────────────────────────────────

class _WizardTopBar extends StatelessWidget {
  const _WizardTopBar({
    required this.step,
    required this.canGoBack,
    required this.onBack,
  });

  final int step;
  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            visible: canGoBack,
            onTap: onBack,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == step ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= step ? AfiCareTheme.canopy : AfiCareTheme.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      visible: visible,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: AfiCareTheme.white,
          shape: const CircleBorder(
            side: BorderSide(color: AfiCareTheme.line),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: 15, color: AfiCareTheme.slate),
          ),
        ),
      ),
    );
  }
}

class _WizHeader extends StatelessWidget {
  const _WizHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.leftAlign = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool leftAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          leftAlign ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (!leftAlign) ...[
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AfiCareTheme.canopy, AfiCareTheme.canopyDark],
              ),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          title,
          textAlign: leftAlign ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AfiCareTheme.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: leftAlign ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AfiCareTheme.slate,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AfiCareTheme.slate,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AfiCareTheme.emergencyRed),
              ),
          ],
        ),
      ),
    );
  }
}

class _WizInput extends StatelessWidget {
  const _WizInput({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: AfiCareTheme.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 18, color: AfiCareTheme.slate),
        filled: true,
        fillColor: AfiCareTheme.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.canopy, width: 2),
        ),
      ),
    );
  }
}

class _WizSelect extends StatelessWidget {
  const _WizSelect({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
      icon: const Icon(Icons.expand_more, size: 20, color: AfiCareTheme.slate),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AfiCareTheme.slate),
        filled: true,
        fillColor: AfiCareTheme.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AfiCareTheme.canopy, width: 2),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Step 1: Welcome ─────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.firstName,
    required this.onNext,
    required this.onSkip,
  });

  final String firstName;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizHeader(
          icon: '👋',
          title: 'Welcome to AfiCare, $firstName',
          subtitle: "You've got a MediLink ID now — here's what that gets you.",
        ),
        const _PromiseRow(icon: '📁', text: 'Own your records — see them from any facility'),
        const _PromiseRow(icon: '📅', text: 'Book visits without calling the clinic'),
        const _PromiseRow(icon: '💬', text: 'Message your providers directly'),
        const SizedBox(height: 22),
        _PrimaryButton(label: "Let's go", onTap: onNext),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onSkip,
          child: const Text(
            "I'll do this later",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AfiCareTheme.slate,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Complete profile ────────────────────────────────────────────

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.dobController,
    required this.gender,
    required this.bloodType,
    required this.allergies,
    required this.allergyController,
    required this.emergencyNameController,
    required this.emergencyPhoneController,
    required this.onPickDob,
    required this.onGenderChanged,
    required this.onBloodTypeChanged,
    required this.onAddAllergy,
    required this.onRemoveAllergy,
    required this.saving,
    required this.onContinue,
  });

  final TextEditingController dobController;
  final String? gender;
  final String? bloodType;
  final List<String> allergies;
  final TextEditingController allergyController;
  final TextEditingController emergencyNameController;
  final TextEditingController emergencyPhoneController;
  final VoidCallback onPickDob;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onBloodTypeChanged;
  final VoidCallback onAddAllergy;
  final ValueChanged<String> onRemoveAllergy;
  final bool saving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizHeader(
          icon: '✏️',
          title: 'Complete your profile',
          subtitle:
              'This helps us get your health summary right, and reach the right person if there\u2019s ever an emergency.',
          leftAlign: true,
        ),
        const _FieldLabel(label: 'Date of birth', required: true),
        TextField(
          controller: dobController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14, color: AfiCareTheme.ink),
          onTap: onPickDob,
          decoration: InputDecoration(
            hintText: 'DD/MM/YYYY',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.cake_outlined, size: 18, color: AfiCareTheme.slate),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AfiCareTheme.canopy),
              tooltip: 'Open date picker',
              onPressed: onPickDob,
            ),
            filled: true,
            fillColor: AfiCareTheme.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Gender'),
        _WizSelect(
          value: gender,
          hint: 'Select gender',
          icon: Icons.wc_outlined,
          items: const ['Female', 'Male', 'Other'],
          onChanged: onGenderChanged,
        ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Blood type'),
        _WizSelect(
          value: bloodType,
          hint: 'Select blood type',
          icon: Icons.water_drop_outlined,
          items: const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
          onChanged: onBloodTypeChanged,
        ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Allergies (optional)'),
        Row(
          children: [
            Expanded(
              child: _WizInput(
                controller: allergyController,
                hint: 'e.g. Penicillin',
                icon: Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 48,
              child: Material(
                color: AfiCareTheme.canopy,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAddAllergy,
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (allergies.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final allergy in allergies)
                Chip(
                  label: Text(allergy),
                  backgroundColor: const Color(0xFFFFEBEE),
                  side: const BorderSide(color: Color(0xFFF5C6CB)),
                  labelStyle: const TextStyle(
                    color: AfiCareTheme.emergencyRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AfiCareTheme.emergencyRed),
                  onDeleted: () => onRemoveAllergy(allergy),
                ),
            ],
          ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Emergency contact name', required: true),
        _WizInput(
          controller: emergencyNameController,
          hint: 'Full name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Emergency contact phone', required: true),
        _WizInput(
          controller: emergencyPhoneController,
          hint: '712 345 678',
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 24),
        _PrimaryButton(label: saving ? 'Saving…' : 'Continue', onTap: onContinue, loading: saving),
      ],
    );
  }
}

// ── Step 3: Care setup ──────────────────────────────────────────────────

class _CareStep extends StatelessWidget {
  const _CareStep({
    required this.facilities,
    required this.facilityId,
    required this.dependents,
    required this.depController,
    required this.onFacilityChanged,
    required this.onAddDependent,
    required this.onRemoveDependent,
    required this.saving,
    required this.onContinue,
    required this.onSkip,
  });

  final List<FacilityModel> facilities;
  final String? facilityId;
  final List<String> dependents;
  final TextEditingController depController;
  final ValueChanged<String?> onFacilityChanged;
  final VoidCallback onAddDependent;
  final ValueChanged<String> onRemoveDependent;
  final bool saving;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizHeader(
          icon: '🏥',
          title: 'Set up your care',
          subtitle: 'Optional — you can add this later from your profile.',
          leftAlign: true,
        ),
        const _FieldLabel(label: 'Usual facility'),
        DropdownButtonFormField<String>(
          value: facilityId,
          isExpanded: true,
          hint: Text(
            facilities.isEmpty ? 'No facilities available' : 'Select your facility',
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          icon: const Icon(Icons.expand_more, size: 20, color: AfiCareTheme.slate),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.local_hospital_outlined, size: 18, color: AfiCareTheme.slate),
            filled: true,
            fillColor: AfiCareTheme.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AfiCareTheme.line, width: 1.5),
            ),
          ),
          items: facilities
              .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: onFacilityChanged,
        ),
        const SizedBox(height: 16),
        const _FieldLabel(label: 'Family members / dependents'),
        Row(
          children: [
            Expanded(
              child: _WizInput(
                controller: depController,
                hint: 'e.g. Baby Amara',
                icon: Icons.family_restroom_outlined,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 48,
              child: Material(
                color: AfiCareTheme.canopy,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAddDependent,
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dependents.isNotEmpty)
          Column(
            children: [
              for (final name in dependents)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AfiCareTheme.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AfiCareTheme.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: AfiCareTheme.slate),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 13.5)),
                      ),
                      InkWell(
                        onTap: () => onRemoveDependent(name),
                        child: const Icon(Icons.close, size: 16, color: AfiCareTheme.slate),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        _PrimaryButton(label: saving ? 'Saving…' : 'Continue', onTap: onContinue, loading: saving),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onSkip,
          child: const Text(
            'Skip for now',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AfiCareTheme.slate,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 4: QR code ─────────────────────────────────────────────────────

class _QrStep extends StatelessWidget {
  const _QrStep({
    required this.fullName,
    required this.medilinkId,
    required this.onFinish,
  });

  final String fullName;
  final String medilinkId;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _WizHeader(
          icon: '🎉',
          title: 'This is your MediLink ID',
          subtitle:
              'Show this to any provider to share your records instantly — no forms, no faxes.',
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AfiCareTheme.line),
          ),
          child: QrImageView(
            data: medilinkId,
            version: QrVersions.auto,
            size: 190,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AfiCareTheme.canopy,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AfiCareTheme.canopyDark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          medilinkId,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AfiCareTheme.slate,
          ),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Continue to My Health', onTap: onFinish),
      ],
    );
  }
}

// ── Shared button ───────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AfiCareTheme.canopy,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: AfiCareTheme.canopy.withOpacity(0.6),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
