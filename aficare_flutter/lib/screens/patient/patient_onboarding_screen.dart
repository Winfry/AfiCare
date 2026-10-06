import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../theme/patient_tokens.dart';
import '../../utils/snackbar_utils.dart';
import 'widgets/patient_ui.dart';

/// First-run onboarding, shown once a patient has created their MediLink
/// ID. Four steps: Welcome → About you → Your care → Your MediLink ID.
///
/// The saving logic is unchanged from the original wizard: the profile
/// goes through [PatientProfileProvider.saveProfile], the home facility
/// is written to `users.facility_id`, and anyone the patient cares for is
/// created through [DependentProvider.addDependent].
class PatientOnboardingScreen extends StatefulWidget {
  const PatientOnboardingScreen({super.key});

  @override
  State<PatientOnboardingScreen> createState() => _PatientOnboardingScreenState();
}

/// Someone the patient looks after, as captured during signup.
class _NewDependent {
  const _NewDependent({required this.name, required this.relationship, this.dob});
  final String name;
  final String relationship;
  final DateTime? dob;
}

class _PatientOnboardingScreenState extends State<PatientOnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 2 — About you
  DateTime? _dob;
  String? _gender;
  String? _bloodType;
  final _allergies = <String>[];
  final _allergyController = TextEditingController();
  final _dobController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Step 3 — Your care
  String? _facilityId;
  final _dependents = <_NewDependent>[];
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
    super.dispose();
  }

  String get _firstName {
    final name =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.fullName.trim() ?? 'there';
    return name.split(' ').first;
  }

  String get _medilinkId {
    final id = Provider.of<AuthProvider>(context, listen: false).currentUser?.medilinkId;
    return (id == null || id.isEmpty) ? 'ML-XXX-XXXX' : id;
  }

  // ── Saving (unchanged behaviour) ──────────────────────────────────────

  Future<void> _saveProfile() async {
    final provider = Provider.of<PatientProfileProvider>(context, listen: false);
    final existing = provider.profile;
    final profile = PatientProfileModel(
      id: existing?.id ?? Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '',
      dateOfBirth: _dob ?? existing?.dateOfBirth,
      gender: _gender ?? existing?.gender,
      bloodType: _bloodType ?? existing?.bloodType,
      allergies:
          _allergies.isNotEmpty ? List.of(_allergies) : (existing?.allergies ?? const <String>[]),
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
      } catch (e) {
        debugPrint('patient_onboarding_screen: saving home facility failed: $e');
        if (mounted) showErrorSnackBar(context, 'Could not save your home facility');
      }
    }

    for (final d in _dependents) {
      await dep.addDependent(
        guardianId: userId,
        fullName: d.name,
        relationship: d.relationship,
        dateOfBirth: d.dob,
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
      _showSnack(typed.isEmpty
          ? 'We need your date of birth to continue'
          : 'That date doesn\'t look right — try DD/MM/YYYY');
      return;
    }
    if (_emergencyNameController.text.trim().isEmpty) {
      _showSnack('Please add someone we can call in an emergency');
      return;
    }
    if (_emergencyPhoneController.text.trim().isEmpty) {
      _showSnack('Please add a phone number for your emergency contact');
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

  Future<void> _finish() async {
    // Reload the profile so Home sees what was just saved.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId != null) {
      await Provider.of<PatientProfileProvider>(context, listen: false).loadProfile(userId);
    }
    if (!mounted) return;
    context.go('/patient');
  }

  void _showSnack(String message) => pToast(context, message);

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Self-contained light experience: the wizard keeps its own light
    // surface even when the device is in dark mode.
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: PT.page),
      child: Scaffold(
        backgroundColor: PT.page,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _WizardBar(step: _step, canGoBack: _step > 0, onBack: () => _goTo(_step - 1)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 60),
                      child: switch (_step) {
                        0 => _WelcomeStep(
                            firstName: _firstName,
                            onNext: () => _goTo(1),
                            onSkip: _skipFromWelcome,
                          ),
                        1 => _AboutYouStep(
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
                        2 => _YourCareStep(
                            facilities: _facilities,
                            facilityId: _facilityId,
                            dependents: _dependents,
                            onFacilityChanged: (v) => setState(() => _facilityId = v),
                            onAddDependent: _addDependent,
                            onRemoveDependent: (d) => setState(() => _dependents.remove(d)),
                            saving: _saving,
                            onContinue: _continueFromCare,
                            onSkip: () => _goTo(3),
                          ),
                        _ => _MediLinkStep(
                            fullName: context.watch<AuthProvider>().currentUser?.fullName ?? '',
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
    final initial =
        _dob ?? _tryParseDob(_dobController.text.trim()) ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Your date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: PT.teal),
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

  Future<void> _addDependent() async {
    final added = await showPModal<_NewDependent>(
      context: context,
      title: 'Someone you care for',
      builder: (ctx) => _AddDependentForm(onDone: (d) => Navigator.pop(ctx, d)),
    );
    if (added != null && mounted) setState(() => _dependents.add(added));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Wizard chrome
// ═══════════════════════════════════════════════════════════════════════

class _WizardBar extends StatelessWidget {
  const _WizardBar({required this.step, required this.canGoBack, required this.onBack});

  final int step;
  final bool canGoBack;
  final VoidCallback onBack;

  static const _labels = ['Welcome', 'About you', 'Your care', 'All set'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canGoBack)
                Material(
                  color: PT.white,
                  borderRadius: BorderRadius.circular(PT.rButton),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PT.rButton),
                    onTap: onBack,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: PT.line),
                        borderRadius: BorderRadius.circular(PT.rButton),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: PT.ink),
                    ),
                  ),
                )
              else
                const SizedBox(width: 38, height: 38),
              const Spacer(),
              Text('Step ${step + 1} of 4 · ${_labels[step]}', style: PT.rowSub()),
            ],
          ),
          const SizedBox(height: 14),
          PProgress((step + 1) / 4, height: 6),
        ],
      ),
    );
  }
}

class _StepHead extends StatelessWidget {
  const _StepHead({required this.eyebrow, required this.title, required this.body});

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: PT.eyebrow()),
          const SizedBox(height: 7),
          Text(title, style: PT.h1().copyWith(fontSize: 27)),
          const SizedBox(height: 8),
          Text(body, style: PT.sub()),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Step 1 — Welcome
// ═══════════════════════════════════════════════════════════════════════

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.firstName, required this.onNext, required this.onSkip});

  final String firstName;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: PT.hero,
            borderRadius: BorderRadius.circular(PT.rHero),
            boxShadow: PT.heroShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PChip('Your account is ready'),
              const SizedBox(height: 12),
              Text('Welcome, $firstName.', style: PT.h2().copyWith(fontSize: 29)),
              const SizedBox(height: 10),
              Text(
                'AfiCare keeps your health information in one place, so the people treating you '
                'can see what matters — and nothing else without your say-so.',
                style: PT.body().copyWith(color: Colors.white.withOpacity(.88)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Three short steps', style: PT.h3()),
        const SizedBox(height: 10),
        const _PointRow(
          icon: Icons.person_outline,
          title: 'A little about you',
          body: 'Your date of birth, blood type and anything you\'re allergic to.',
        ),
        const _PointRow(
          icon: Icons.local_hospital_outlined,
          title: 'Where you get care',
          body: 'Your usual facility, and anyone whose health you look after.',
        ),
        const _PointRow(
          icon: Icons.qr_code_2_outlined,
          title: 'Your MediLink ID',
          body: 'The code that links your care together wherever you go.',
        ),
        const SizedBox(height: 22),
        PButton('Let\'s get started', expand: true, onPressed: onNext),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: onSkip,
            child: Text('I\'ll do this later', style: PT.body().copyWith(color: PT.muted)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'You can change any of this at any time.',
            textAlign: TextAlign.center,
            style: PT.rowSub(),
          ),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PT.calloutBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: PT.teal),
          ),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Step 2 — About you
// ═══════════════════════════════════════════════════════════════════════

class _AboutYouStep extends StatelessWidget {
  const _AboutYouStep({
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHead(
          eyebrow: 'Step one',
          title: 'A little about you',
          body: 'This is what a clinician checks first. It takes a minute, and it can genuinely '
              'change the care you get in an emergency.',
        ),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PField(
                label: 'Date of birth',
                child: TextField(
                  controller: dobController,
                  readOnly: true,
                  onTap: onPickDob,
                  decoration: pInput(hint: 'DD/MM/YYYY').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: PT.muted),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PFormGrid([
                PField(
                  label: 'Sex',
                  child: DropdownButtonFormField<String>(
                    value: gender,
                    isExpanded: true,
                    decoration: pInput(),
                    hint: Text('Prefer not to say', style: PT.sub()),
                    items: const [
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: onGenderChanged,
                  ),
                ),
                PField(
                  label: 'Blood type',
                  child: DropdownButtonFormField<String>(
                    value: bloodType,
                    isExpanded: true,
                    decoration: pInput(),
                    hint: Text('If you know it', style: PT.sub()),
                    items: const [
                      DropdownMenuItem(value: 'O+', child: Text('O+')),
                      DropdownMenuItem(value: 'O-', child: Text('O−')),
                      DropdownMenuItem(value: 'A+', child: Text('A+')),
                      DropdownMenuItem(value: 'A-', child: Text('A−')),
                      DropdownMenuItem(value: 'B+', child: Text('B+')),
                      DropdownMenuItem(value: 'B-', child: Text('B−')),
                      DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                      DropdownMenuItem(value: 'AB-', child: Text('AB−')),
                    ],
                    onChanged: onBloodTypeChanged,
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PCardTitle('Anything you react badly to?'),
              Text(
                'Medicines, foods, anything. This is the one thing worth getting right — it stops '
                'you being given something that could harm you.',
                style: PT.rowSub(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: allergyController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onAddAllergy(),
                      decoration: pInput(hint: 'e.g. Penicillin'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PButton('Add', kind: PButtonKind.alt, onPressed: onAddAllergy),
                ],
              ),
              if (allergies.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in allergies)
                      InputChip(
                        label: Text(a, style: PT.badge().copyWith(color: PT.badgeRedFg)),
                        backgroundColor: PT.badgeRedBg,
                        side: BorderSide.none,
                        deleteIconColor: PT.badgeRedFg,
                        onDeleted: () => onRemoveAllergy(a),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text('Nothing added yet — that\'s fine if you don\'t have any.', style: PT.rowSub()),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PCardTitle('Who should we call?'),
              Text(
                'One person we can reach if something happens and you can\'t speak for yourself.',
                style: PT.rowSub(),
              ),
              const SizedBox(height: 14),
              PField(
                label: 'Their name',
                child: TextField(
                  controller: emergencyNameController,
                  decoration: pInput(hint: 'e.g. Mary Achieng'),
                ),
              ),
              const SizedBox(height: 12),
              PField(
                label: 'Their phone number',
                child: TextField(
                  controller: emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: pInput(hint: '+254 712 345 678'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PButton(saving ? 'Saving…' : 'Continue', expand: true, onPressed: saving ? null : onContinue),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Step 3 — Your care
// ═══════════════════════════════════════════════════════════════════════

class _YourCareStep extends StatelessWidget {
  const _YourCareStep({
    required this.facilities,
    required this.facilityId,
    required this.dependents,
    required this.onFacilityChanged,
    required this.onAddDependent,
    required this.onRemoveDependent,
    required this.saving,
    required this.onContinue,
    required this.onSkip,
  });

  final List<FacilityModel> facilities;
  final String? facilityId;
  final List<_NewDependent> dependents;
  final ValueChanged<String?> onFacilityChanged;
  final VoidCallback onAddDependent;
  final ValueChanged<_NewDependent> onRemoveDependent;
  final bool saving;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHead(
          eyebrow: 'Step two',
          title: 'Your care',
          body: 'Where you usually go, and anyone whose health you help look after.',
        ),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PCardTitle('Where do you usually go?'),
              Text(
                'We\'ll show their appointments and results first. You can still be seen anywhere.',
                style: PT.rowSub(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: facilityId,
                isExpanded: true,
                decoration: pInput(),
                hint: Text(
                  facilities.isEmpty ? 'Loading facilities…' : 'Choose a facility',
                  style: PT.sub(),
                ),
                items: [
                  for (final f in facilities)
                    DropdownMenuItem(
                      value: f.id,
                      child: Text(f.name, overflow: TextOverflow.ellipsis, style: PT.body()),
                    ),
                ],
                onChanged: facilities.isEmpty ? null : onFacilityChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PCardTitle('Do you look after anyone?'),
              Text(
                'A child, a parent, anyone whose care you help manage. They get their own record, '
                'kept separate from yours, and you can switch between them at any time.',
                style: PT.rowSub(),
              ),
              const SizedBox(height: 14),
              if (dependents.isEmpty)
                Text('Nobody added yet.', style: PT.rowSub())
              else
                for (final d in dependents)
                  PRow(
                    leading: PAvatar(initials: _initials(d.name), size: 38, isDependent: true),
                    title: d.name,
                    subtitle: _describe(d),
                    trailing: [
                      IconButton(
                        onPressed: () => onRemoveDependent(d),
                        icon: const Icon(Icons.close_rounded, size: 18, color: PT.muted),
                        tooltip: 'Remove ${d.name}',
                      ),
                    ],
                  ),
              const SizedBox(height: 12),
              PButton('+ Add someone', kind: PButtonKind.alt, onPressed: onAddDependent),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PButton(saving ? 'Saving…' : 'Continue', expand: true, onPressed: saving ? null : onContinue),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: onSkip,
            child: Text('Skip for now', style: PT.body().copyWith(color: PT.muted)),
          ),
        ),
      ],
    );
  }

  static String _describe(_NewDependent d) {
    final rel = d.relationship.isEmpty
        ? 'Family'
        : '${d.relationship[0].toUpperCase()}${d.relationship.substring(1)}';
    if (d.dob == null) return rel;
    return '$rel · ${_ageFrom(d.dob!)}';
  }

  static String _ageFrom(DateTime dob) {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    if (years < 1) {
      final months = ((now.difference(dob).inDays) / 30.44).floor();
      return '$months month${months == 1 ? '' : 's'}';
    }
    return '$years year${years == 1 ? '' : 's'}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Collects a dependant's name, relationship and date of birth — the
/// three things the profile switcher needs to label them properly.
class _AddDependentForm extends StatefulWidget {
  const _AddDependentForm({required this.onDone});

  final ValueChanged<_NewDependent> onDone;

  @override
  State<_AddDependentForm> createState() => _AddDependentFormState();
}

class _AddDependentFormState extends State<_AddDependentForm> {
  final _nameCtrl = TextEditingController();
  String _relationship = 'child';
  DateTime? _dob;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Their date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: PT.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'They get their own record with its own MediLink ID. Nothing of theirs mixes with yours.',
          style: PT.sub(),
        ),
        const SizedBox(height: 16),
        PField(
          label: 'Their full name',
          child: TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: pInput(hint: 'e.g. Amani Nyarangi'),
          ),
        ),
        const SizedBox(height: 14),
        PField(
          label: 'Who are they to you?',
          child: DropdownButtonFormField<String>(
            value: _relationship,
            isExpanded: true,
            decoration: pInput(),
            items: const [
              DropdownMenuItem(value: 'child', child: Text('My child')),
              DropdownMenuItem(value: 'parent', child: Text('My parent')),
              DropdownMenuItem(value: 'other', child: Text('Someone else I care for')),
            ],
            onChanged: (v) => setState(() => _relationship = v ?? 'child'),
          ),
        ),
        const SizedBox(height: 14),
        PField(
          label: 'Their date of birth',
          child: Material(
            color: PT.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickDob,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: PT.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 17, color: PT.muted),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _dob == null ? 'Choose a date' : DateFormat('d MMMM yyyy').format(_dob!),
                        style: _dob == null ? PT.sub() : PT.body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        PButton(
          'Add them',
          expand: true,
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              pToast(context, 'Please enter their name');
              return;
            }
            widget.onDone(_NewDependent(name: name, relationship: _relationship, dob: _dob));
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Step 4 — MediLink ID
// ═══════════════════════════════════════════════════════════════════════

class _MediLinkStep extends StatelessWidget {
  const _MediLinkStep({
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHead(
          eyebrow: 'All set',
          title: 'This is your MediLink ID',
          body: 'Show this at any AfiCare facility. Scanning it lets them ask for access — nothing '
              'is shared until you agree.',
        ),
        PCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PT.white,
                  border: Border.all(color: PT.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: medilinkId,
                  version: QrVersions.auto,
                  size: 168,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: PT.navy),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: PT.navy,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(fullName, style: PT.h3()),
              const SizedBox(height: 4),
              Text(medilinkId, style: PT.body().copyWith(letterSpacing: 1.5, color: PT.teal)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PCallout(
          title: 'You decide who sees what',
          body: 'Your records are only shared when you approve it, and you can take that back at '
              'any time from Share Records.',
        ),
        const SizedBox(height: 20),
        PButton('Go to my health space', expand: true, onPressed: onFinish),
      ],
    );
  }
}
