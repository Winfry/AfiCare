// ================================================================
// AfiCare MediLink — PWD Profile & Recommendations Tab
//
// Patient self-reports their disability profile here.
// Provider fields (clinicalDiagnosis, providerNotes) are filled
// via the consultation screen's PWD Assessment section.
// ================================================================

import 'package:flutter/material.dart';
import '../../theme/patient_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/caregiver_model.dart';
import '../../models/disability_profile.dart';
import '../../models/pwd_patient_guidance.dart';
import '../../services/caregiver_service.dart';
import '../../services/pwd_rule_engine.dart';
import '../../utils/theme.dart';
import 'widgets/crisis_lines.dart';
import 'widgets/patient_ui.dart';

class PwdTab extends StatefulWidget {
  final String patientId;

  /// False on a dependant's profile. Caregiver access shares the account
  /// holder's own record, so it is not offered there.
  final bool isOwnRecord;

  /// For tests.
  final CaregiverService? caregiverService;

  const PwdTab({super.key, required this.patientId, this.isOwnRecord = true, this.caregiverService});

  /// The real caregiver sharing page.
  static const caregiverRoute = '/patient/caregiver-portal';

  @override
  State<PwdTab> createState() => _PwdTabState();
}

class _PwdTabState extends State<PwdTab> {
  // ---- Profile state ----
  bool _hasPwdCondition = false;
  late DisabilityProfile _profile;

  // ---- UI state ----
  bool _isSaving = false;
  bool _isLoading = true;

  // ---- Caregiver access (the account holder's real grants) ----
  late final CaregiverService _caregivers = widget.caregiverService ?? CaregiverService();
  List<CaregiverAccess>? _grants;
  bool _grantsLoading = false;
  bool _grantsFailed = false;

  static SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _profile = DisabilityProfile.empty(widget.patientId);
    _loadProfile();
    if (widget.isOwnRecord) _loadGrants(first: true);
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _sb
          .from('disability_profiles')
          .select()
          .eq('patient_id', widget.patientId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _profile = DisabilityProfile.fromMap(data);
          _hasPwdCondition = !_profile.isEmpty;
        });
      }
    } catch (_) {
      // Profile not yet created — use the empty default
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  // Save
  // ----------------------------------------------------------------

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await _sb.from('disability_profiles').upsert(
        _profile.toMap(),
        onConflict: 'patient_id',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accessibility profile saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Normally its own page in the patient shell (from More), where the
    // design's page head replaces the green banner. Rendered anywhere else
    // it keeps the banner, as it then has no head of its own.
    final inShell = PatientShellScope.inShell(context);

    if (_isLoading) {
      return inShell ? const PLoadingPage() : const Center(child: CircularProgressIndicator());
    }

    // The patient's own wording of the engine's suggestions: the
    // clinician wording (priority badges, "document risk level") belongs
    // on the consultation screen, not here.
    final active = _hasPwdCondition && !_profile.isEmpty;
    final tips = active ? PwdPatientGuidance.tipsFor(_profile) : <PwdPatientTip>[];
    final offerSupport = active && PwdPatientGuidance.offersSupportLines(_profile);

    final sections = <Widget>[
          _buildToggleCard(),
          if (_hasPwdCondition) ...[
            const SizedBox(height: 16),
            _buildDisabilityTypeSelector(),
            const SizedBox(height: 16),
            _buildSeveritySelector(),
            const SizedBox(height: 16),
            _buildOnsetSection(),
            const SizedBox(height: 16),
            _buildAssistiveDevices(),
            const SizedBox(height: 16),
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
          if (offerSupport) ...[
            _buildSupportCard(),
            const SizedBox(height: 16),
          ],
          if (tips.isNotEmpty) ...[
            _buildTipsSection(tips),
            const SizedBox(height: 24),
          ],
          if (widget.isOwnRecord) ...[
            _buildCaregiverSection(),
            const SizedBox(height: 24),
          ],
          _buildProviderNoteCard(),
    ];

    if (inShell) {
      return PDetailScaffold(
        eyebrow: 'Care that fits you',
        title: 'PWD / disability support',
        subtitle: 'Tell facilities what you need, so they can be ready before you arrive. '
            'Your information is private and protected.',
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          ...sections,
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Header
  // ----------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AfiCareTheme.primaryGreen,
            AfiCareTheme.primaryGreenDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.accessibility_new, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Accessibility Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your profile helps healthcare providers prepare '
            'the right support before you arrive. '
            'Your information is private and protected.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Toggle: do you have a disability/condition?
  // ----------------------------------------------------------------

  Widget _buildToggleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you live with a disability or chronic condition?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Sharing this helps us provide better, more prepared care.',
              style: TextStyle(fontSize: 13, color: PT.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildToggleOption('Yes', true),
                const SizedBox(width: 12),
                _buildToggleOption('No / Prefer not to say', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, bool value) {
    final isSelected = _hasPwdCondition == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          onTap: () => setState(() => _hasPwdCondition = value),
          child: AnimatedContainer(
            duration: PT.motion(context, const Duration(milliseconds: 200)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AfiCareTheme.primaryGreen
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AfiCareTheme.primaryGreen
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Disability type multi-selector
  // ----------------------------------------------------------------

  Widget _buildDisabilityTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What type of disability or condition?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select all that apply.',
              style: TextStyle(fontSize: 13, color: PT.muted),
            ),
            const SizedBox(height: 16),
            ...DisabilityType.values.map((type) {
              final isSelected =
                  _profile.disabilityTypes.contains(type);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  checked: isSelected,
                  label: '${type.displayName}: ${type.description}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final updated = List<DisabilityType>.from(
                          _profile.disabilityTypes);
                      if (isSelected) {
                        updated.remove(type);
                      } else {
                        updated.add(type);
                      }
                      setState(() {
                        _profile = _profile.copyWith(
                          disabilityTypes: updated,
                          lastUpdated: DateTime.now(),
                          updatedBy: 'patient',
                        );
                      });
                    },
                    child: AnimatedContainer(
                      duration: PT.motion(context, const Duration(milliseconds: 150)),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AfiCareTheme.primaryBlue.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AfiCareTheme.primaryBlue
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: PT.motion(context, const Duration(milliseconds: 150)),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AfiCareTheme.primaryBlue
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? AfiCareTheme.primaryBlue
                                    : PT.muted,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isSelected
                                        ? AfiCareTheme.primaryBlue
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PT.muted,
                                  ),
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
            }),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Severity selector
  // ----------------------------------------------------------------

  Widget _buildSeveritySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much does it affect your daily life?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...DisabilitySeverity.values.map((severity) {
              final isSelected = _profile.severity == severity;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  selected: isSelected,
                  label:
                      '${severity.displayName}: ${severity.description}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _profile = _profile.copyWith(
                        severity: severity,
                        lastUpdated: DateTime.now(),
                        updatedBy: 'patient',
                      );
                    }),
                    child: AnimatedContainer(
                      duration: PT.motion(context, const Duration(milliseconds: 150)),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _severityColor(severity).withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _severityColor(severity)
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<DisabilitySeverity>(
                            value: severity,
                            groupValue: _profile.severity,
                            activeColor: _severityColor(severity),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _profile = _profile.copyWith(
                                    severity: v,
                                    lastUpdated: DateTime.now(),
                                    updatedBy: 'patient',
                                  );
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  severity.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isSelected
                                        ? _severityColor(severity)
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  severity.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PT.muted,
                                  ),
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
            }),
          ],
        ),
      ),
    );
  }

  Color _severityColor(DisabilitySeverity s) => switch (s) {
        DisabilitySeverity.mild     => Colors.green.shade700,
        DisabilitySeverity.moderate => Colors.orange.shade700,
        DisabilitySeverity.severe   => Colors.red.shade700,
      };

  // ----------------------------------------------------------------
  // Onset section
  // ----------------------------------------------------------------

  Widget _buildOnsetSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'When did this start?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOnsetOption(
                    label: 'Born with it',
                    icon: Icons.child_care,
                    value: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOnsetOption(
                    label: 'Developed later',
                    icon: Icons.calendar_today,
                    value: false,
                  ),
                ),
              ],
            ),
            if (!_profile.isCongenital) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickOnsetDate,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _profile.onsetDate != null
                      ? 'Approx. ${_profile.onsetDate!.year}'
                      : 'Select approximate year',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOnsetOption({
    required String label,
    required IconData icon,
    required bool value,
  }) {
    final isSelected = _profile.isCongenital == value;
    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() {
          _profile = _profile.copyWith(
            isCongenital: value,
            onsetDate: value ? null : _profile.onsetDate,
            lastUpdated: DateTime.now(),
            updatedBy: 'patient',
          );
        }),
        child: AnimatedContainer(
          duration: PT.motion(context, const Duration(milliseconds: 150)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AfiCareTheme.primaryGreen.withOpacity(0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AfiCareTheme.primaryGreen
                  : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AfiCareTheme.primaryGreen
                      : PT.muted),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AfiCareTheme.primaryGreen
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOnsetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _profile.onsetDate ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'When did your condition start?',
      fieldLabelText: 'Onset date (approximate)',
    );
    if (picked != null) {
      setState(() {
        _profile = _profile.copyWith(
          onsetDate: picked,
          lastUpdated: DateTime.now(),
          updatedBy: 'patient',
        );
      });
    }
  }

  // ----------------------------------------------------------------
  // Assistive devices
  // ----------------------------------------------------------------

  Widget _buildAssistiveDevices() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you use any assistive devices?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select all that apply.',
              style: TextStyle(fontSize: 13, color: PT.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAssistiveDevices.map((device) {
                final isSelected =
                    _profile.assistiveDevices.contains(device);
                return Semantics(
                  checked: isSelected,
                  label: device,
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(device),
                    selectedColor: AfiCareTheme.primaryBlue,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (selected) {
                      final updated = List<String>.from(
                          _profile.assistiveDevices);
                      selected
                          ? updated.add(device)
                          : updated.remove(device);
                      setState(() {
                        _profile = _profile.copyWith(
                          assistiveDevices: updated,
                          lastUpdated: DateTime.now(),
                          updatedBy: 'patient',
                        );
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Save button
  // ----------------------------------------------------------------

  Widget _buildSaveButton() {
    final hasTypes = _profile.disabilityTypes.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (hasTypes && !_isSaving) ? _saveProfile : null,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AfiCareTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Support, for anyone who records a mental health condition
  // ----------------------------------------------------------------

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AfiCareTheme.primaryGreen.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: AfiCareTheme.primaryGreen, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You don't have to carry this alone",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If things ever feel too heavy, or you have thoughts of hurting '
            'yourself, talk to someone today: a person you trust, your '
            'clinic, or one of these lines. Tap a number to call.',
            style: TextStyle(fontSize: 13, color: PT.ink),
          ),
          const SizedBox(height: 6),
          const CrisisLines(),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Suggestions, in the patient's own words
  // ----------------------------------------------------------------

  Widget _buildTipsSection(List<PwdPatientTip> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: AfiCareTheme.primaryGreen),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Things to ask your clinic about',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AfiCareTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${tips.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AfiCareTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Based on what you've told us. These are ideas to talk through "
          "with your clinic, not a diagnosis. Your clinic will say what's "
          'right for you.',
          style: TextStyle(fontSize: 13, color: PT.muted),
        ),
        const SizedBox(height: 12),
        ...tips.map(_buildTipCard),
      ],
    );
  }

  Widget _buildTipCard(PwdPatientTip tip) {
    return Semantics(
      container: true,
      label: '${tip.title}. ${tip.body} ${tip.ask}',
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AfiCareTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_categoryIcon(tip.category), color: AfiCareTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.body,
                      style: TextStyle(fontSize: 13, color: PT.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: AfiCareTheme.primaryGreen),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tip.ask,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AfiCareTheme.primaryGreenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(RecommendationCategory c) => switch (c) {
        RecommendationCategory.healthCheck    => Icons.medical_services,
        RecommendationCategory.labTest        => Icons.science,
        RecommendationCategory.medication     => Icons.medication,
        RecommendationCategory.referral       => Icons.person_add,
        RecommendationCategory.lifestyle      => Icons.self_improvement,
        RecommendationCategory.providerNote   => Icons.note_alt,
        RecommendationCategory.caregiverAlert => Icons.people,
      };

  // ----------------------------------------------------------------
  // Caregiver access
  //
  // The real thing lives on the "Share with a caregiver" page (codes
  // made and checked in the database, migration 036). This used to be a
  // separate copy whose 6-letter code was made up on the phone and could
  // not be entered anywhere; now it shows who really can see the record
  // and links to that page.
  // ----------------------------------------------------------------

  /// [first] is the call from initState, before the first build.
  Future<void> _loadGrants({bool first = false}) async {
    void start() {
      _grantsLoading = true;
      _grantsFailed = false;
    }

    first ? start() : setState(start);
    try {
      final grants = await _caregivers.myGrants();
      if (mounted) setState(() => _grants = grants);
    } on CaregiverException {
      if (mounted) setState(() => _grantsFailed = true);
    } finally {
      if (mounted) setState(() => _grantsLoading = false);
    }
  }

  Future<void> _openCaregiverPage() async {
    await context.push(PwdTab.caregiverRoute);
    if (mounted) _loadGrants();
  }

  Widget _buildCaregiverSection() {
    final now = DateTime.now();
    final live = (_grants ?? const <CaregiverAccess>[]).where((g) => g.isLiveAt(now)).toList();
    final oldNote = _profile.caregiver;
    final oldName = oldNote?.name.trim() ?? '';
    final oldNoteStillMatters = oldNote != null &&
        oldNote.isActive &&
        oldName.isNotEmpty &&
        !live.any((g) => (g.caregiverName ?? '').trim().toLowerCase() == oldName.toLowerCase());

    final Widget status;
    if (_grantsLoading && _grants == null) {
      status = Text('Checking who you share with…', style: TextStyle(fontSize: 13, color: PT.muted));
    } else if (_grantsFailed) {
      status = Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't check who you share with.",
              style: TextStyle(fontSize: 13, color: PT.ink),
            ),
          ),
          TextButton(onPressed: () => _loadGrants(), child: const Text('Try again')),
        ],
      );
    } else if (live.isEmpty) {
      status = Text(
        'No one has caregiver access right now.',
        style: TextStyle(fontSize: 13, color: PT.ink),
      );
    } else {
      status = Column(children: [for (final g in live) _buildGrantRow(g, now)]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: AfiCareTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Caregiver access',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Someone you trust, such as family, a friend or a carer, can '
              'follow part of your care from their own AfiCare account. They '
              'can look, not change anything, and you can stop it at any time.',
              style: TextStyle(fontSize: 13, color: PT.muted),
            ),
            const SizedBox(height: 14),
            status,
            if (oldNoteStillMatters) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'You noted $oldName as your caregiver on this page before. '
                  "That didn't give them access to anything. To share with "
                  '$oldName, make a code for them and they enter it in their '
                  'own AfiCare account.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C00)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openCaregiverPage,
                icon: Icon(live.isEmpty ? Icons.person_add : Icons.manage_accounts),
                label: Text(live.isEmpty ? 'Share with a caregiver' : 'Manage caregiver access'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AfiCareTheme.primaryBlue),
                  foregroundColor: AfiCareTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrantRow(CaregiverAccess g, DateTime now) {
    final relationship = CaregiverRelationship.label(g.relationship);
    final active = g.statusAt(now) == CaregiverGrantStatus.active;
    final name = g.caregiverName?.trim();
    final who = active && name != null && name.isNotEmpty ? name : 'Code ${CaregiverAccess.formatCode(g.accessCode)}';
    final title = relationship == null ? who : '$who · $relationship';
    final detail = active
        ? 'Can see: ${CaregiverAccess.accessLevelScope(g.accessLevel)}'
        : 'Not entered yet · works until ${DateFormat('d MMM, HH:mm').format(g.codeExpiresAt!.toLocal())}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.visibility_outlined : Icons.key_rounded,
            size: 20,
            color: AfiCareTheme.primaryBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(detail, style: TextStyle(fontSize: 12, color: PT.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Provider note reminder (patient-facing)
  // ----------------------------------------------------------------

  Widget _buildProviderNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For your provider',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D4C00),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your healthcare provider can also add clinical details '
                  '(diagnosis, specialist referrals, provider notes) to this '
                  'profile during your consultation. Both sets of information '
                  'are kept together in your record.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6D4C00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
