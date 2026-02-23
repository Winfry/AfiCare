// ================================================================
// AfiCare MediLink — PWD Profile & Recommendations Tab
//
// Patient self-reports their disability profile here.
// Provider fields (clinicalDiagnosis, providerNotes) are filled
// via the consultation screen's PWD Assessment section.
// ================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/disability_profile.dart';
import '../../services/pwd_rule_engine.dart';
import '../../utils/theme.dart';

class PwdTab extends StatefulWidget {
  final String patientId;

  const PwdTab({super.key, required this.patientId});

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

  final _engine = const PwdRuleEngine();
  static SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _profile = DisabilityProfile.empty(widget.patientId);
    _loadProfile();
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
          _profile = DisabilityProfile.fromMap(data as Map<String, dynamic>);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recommendations = _hasPwdCondition && !_profile.isEmpty
        ? _engine.getRecommendations(_profile)
        : <PwdRecommendation>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
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
          if (recommendations.isNotEmpty) ...[
            _buildRecommendationsSection(recommendations),
            const SizedBox(height: 24),
          ],
          _buildCaregiverSection(),
          const SizedBox(height: 24),
          _buildProviderNoteCard(),
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
        gradient: LinearGradient(
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
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
            duration: const Duration(milliseconds: 200),
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
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                      duration: const Duration(milliseconds: 150),
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
                            duration: const Duration(milliseconds: 150),
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
                                    : Colors.grey.shade400,
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
                                    color: Colors.grey.shade700,
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
                      duration: const Duration(milliseconds: 150),
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
                                    color: Colors.grey.shade700,
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
          duration: const Duration(milliseconds: 150),
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
                      : Colors.grey.shade600),
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
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
  // Recommendations from rule engine
  // ----------------------------------------------------------------

  Widget _buildRecommendationsSection(
      List<PwdRecommendation> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: AfiCareTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text(
              'Recommended for You',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AfiCareTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${recommendations.length} items',
                style: TextStyle(
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
          'Based on your profile. Share this list with your provider.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        ...recommendations
            .where((r) => r.category != RecommendationCategory.providerNote)
            .map((r) => _buildRecommendationCard(r)),
      ],
    );
  }

  Widget _buildRecommendationCard(PwdRecommendation rec) {
    final color  = _priorityColor(rec.priority);
    final label  = _priorityLabel(rec.priority);
    final icon   = _categoryIcon(rec.category);

    return Semantics(
      label: '${label}: ${rec.title}. ${rec.description}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rec.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rec.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (rec.actionLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        rec.actionLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(RecommendationPriority p) => switch (p) {
        RecommendationPriority.critical => Colors.red.shade700,
        RecommendationPriority.high     => Colors.orange.shade700,
        RecommendationPriority.medium   => Colors.amber.shade700,
        RecommendationPriority.low      => Colors.green.shade700,
      };

  String _priorityLabel(RecommendationPriority p) => switch (p) {
        RecommendationPriority.critical => 'CRITICAL',
        RecommendationPriority.high     => 'HIGH',
        RecommendationPriority.medium   => 'MEDIUM',
        RecommendationPriority.low      => 'LOW',
      };

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
  // Caregiver section
  // ----------------------------------------------------------------

  Widget _buildCaregiverSection() {
    final caregiver = _profile.caregiver;

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
                Text(
                  'Caregiver / Guardian Access',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A designated caregiver can view selected parts of your '
              'medical record using a private access code.',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            if (caregiver != null && caregiver.isActive) ...[
              _buildActiveCaregiverCard(caregiver),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCaregiverDialog(),
                icon: Icon(caregiver != null
                    ? Icons.edit
                    : Icons.person_add),
                label: Text(caregiver != null
                    ? 'Change Caregiver'
                    : 'Add Caregiver'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AfiCareTheme.primaryBlue),
                  foregroundColor: AfiCareTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCaregiverCard(CaregiverDesignation c) {
    final codeValid = c.codeIsValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.15),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AfiCareTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${c.relationship} · ${c.phone}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Permissions
          Text(
            'Can access:',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.permissions
                .map((p) => Chip(
                      label: Text(p,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.blue.shade100,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          // Access code row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Code',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (codeValid) ...[
                      Text(
                        c.accessCode!,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AfiCareTheme.primaryBlue,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Expires ${_formatExpiry(c.codeExpiry!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ] else
                      Text(
                        'No active code',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _generateCaregiverCode,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(codeValid ? 'Refresh' : 'Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AfiCareTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime expiry) {
    final diff = expiry.difference(DateTime.now());
    if (diff.inHours >= 1) return 'in ${diff.inHours}h';
    return 'in ${diff.inMinutes}m';
  }

  void _generateCaregiverCode() {
    if (_profile.caregiver == null) return;
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random();
    final code  = List.generate(6, (_) => chars[rng.nextInt(chars.length)])
        .join();
    final expiry = DateTime.now().add(const Duration(hours: 24));

    setState(() {
      _profile = _profile.copyWith(
        caregiver: _profile.caregiver!.copyWith(
          accessCode: code,
          codeExpiry: expiry,
        ),
        lastUpdated: DateTime.now(),
        updatedBy: 'patient',
      );
    });

    // Persist code to Supabase so the caregiver can use it from any device
    _sb.from('disability_profiles').upsert(
      _profile.toMap(),
      onConflict: 'patient_id',
    ).then((_) {}).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Caregiver code $code generated — valid 24 hours'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // Add / edit caregiver dialog
  // ----------------------------------------------------------------

  void _showCaregiverDialog() {
    final nameController = TextEditingController(
        text: _profile.caregiver?.name ?? '');
    final phoneController = TextEditingController(
        text: _profile.caregiver?.phone ?? '');
    String relationship =
        _profile.caregiver?.relationship ?? kCaregiverRelationships.first;
    List<String> permissions =
        List.from(_profile.caregiver?.permissions ?? ['Emergency contacts', 'Current medications', 'Known allergies']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Caregiver Details',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Caregiver full name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '+254...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: relationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: kCaregiverRelationships
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModal(() => relationship = v);
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'What can this caregiver access?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...kCaregiverPermissions.map((perm) {
                  final checked = permissions.contains(perm);
                  return CheckboxListTile(
                    title: Text(perm, style: const TextStyle(fontSize: 14)),
                    value: checked,
                    activeColor: AfiCareTheme.primaryBlue,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      setModal(() {
                        v! ? permissions.add(perm) : permissions.remove(perm);
                      });
                    },
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty) return;
                      final newCaregiver = CaregiverDesignation(
                        name:         nameController.text.trim(),
                        phone:        phoneController.text.trim(),
                        relationship: relationship,
                        permissions:  permissions,
                        designatedAt: DateTime.now(),
                        isActive:     true,
                      );
                      setState(() {
                        _profile = _profile.copyWith(
                          caregiver:   newCaregiver,
                          lastUpdated: DateTime.now(),
                          updatedBy:   'patient',
                        );
                      });
                      Navigator.pop(ctx);
                      // Persist caregiver designation to Supabase
                      _sb.from('disability_profiles').upsert(
                        _profile.toMap(),
                        onConflict: 'patient_id',
                      ).then((_) {}).catchError((_) {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${nameController.text.trim()} added as caregiver'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AfiCareTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Caregiver'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
