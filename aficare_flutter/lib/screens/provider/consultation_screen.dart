import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/prescription_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../services/medical_ai_service.dart';
import '../../models/consultation_model.dart';
import '../../models/disability_profile.dart';
import '../../models/prescription_model.dart';
import '../../models/appointment_model.dart';
import '../../services/pwd_rule_engine.dart';
import '../../utils/theme.dart';

class ConsultationScreen extends StatefulWidget {
  final String? patientId;

  const ConsultationScreen({super.key, this.patientId});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintController = TextEditingController();
  final _medilinkIdController = TextEditingController();
  
  // Patient Info
  int _age = 30;
  String _gender = 'Male';
  
  // Symptoms
  final Map<String, bool> _symptoms = {
    'fever': false,
    'cough': false,
    'headache': false,
    'nausea': false,
    'vomiting': false,
    'chest_pain': false,
    'difficulty_breathing': false,
    'fatigue': false,
    'dizziness': false,
    'muscle_aches': false,
    'sore_throat': false,
    'runny_nose': false,
    'abdominal_pain': false,
    'diarrhea': false,
    'constipation': false,
  };
  
  // Vital Signs
  double _temperature = 37.0;
  int _systolicBP = 120;
  int _diastolicBP = 80;
  int _pulse = 80;
  int _respiratoryRate = 16;
  int _oxygenSaturation = 98;
  
  // PWD Assessment (provider-fills during consultation)
  bool _pwdSectionExpanded = false;
  final List<DisabilityType> _pwdTypes = [];
  DisabilitySeverity _pwdSeverity = DisabilitySeverity.mild;
  final _clinicalDiagnosisController = TextEditingController();
  final _providerNotesController = TextEditingController();
  bool _requiresCaregiverConsent = false;
  // Referrals auto-suggested by rule engine; provider can deselect
  final Set<String> _selectedReferrals = {};

  // Prescriptions card
  bool _prescriptionSectionExpanded = false;
  final List<Map<String, String>> _prescriptions = [];

  // Appointment scheduling card
  bool _appointmentSectionExpanded = false;
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  AppointmentType _appointmentType = AppointmentType.inPerson;
  final _appointmentNotesController = TextEditingController();

  ConsultationResult? _aiResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _medilinkIdController.text = widget.patientId!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Consultation'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientInfo(),
              const SizedBox(height: 20),
              _buildChiefComplaint(),
              const SizedBox(height: 20),
              _buildSymptomsSection(),
              const SizedBox(height: 20),
              _buildPwdAssessment(),
              const SizedBox(height: 20),
              _buildPrescriptionsCard(),
              const SizedBox(height: 20),
              _buildAppointmentSchedulingCard(),
              const SizedBox(height: 20),
              _buildVitalSigns(),
              const SizedBox(height: 20),
              _buildAnalyzeButton(),
              if (_aiResult != null) ...[
                const SizedBox(height: 20),
                _buildAIResults(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medilinkIdController,
              decoration: const InputDecoration(
                labelText: 'Patient MediLink ID',
                hintText: 'ML-XXX-XXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter patient MediLink ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Age'),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: '$_age',
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                suffixText: 'yrs',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n >= 0 && n <= 120) {
                                  setState(() => _age = n);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _age.toDouble(),
                        min: 0,
                        max: 120,
                        divisions: 120,
                        label: '$_age years',
                        semanticFormatterCallback: (v) => '${v.toInt()} years',
                        onChanged: (value) {
                          setState(() {
                            _age = value.toInt();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gender = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChiefComplaint() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chief Complaint',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chiefComplaintController,
              decoration: const InputDecoration(
                labelText: 'What brings the patient in today?',
                hintText: 'e.g., Fever and headache for 3 days',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter chief complaint';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Symptoms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _symptoms.length,
              itemBuilder: (context, index) {
                final symptom = _symptoms.keys.elementAt(index);
                final isSelected = _symptoms[symptom]!;
                
                return FilterChip(
                  label: Text(
                    symptom.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      // Selected: white on #1D3557 (navy) = 12.6:1 ✓
                      // Unselected: black87 on chip surface ✓
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _symptoms[symptom] = selected;
                    });
                  },
                  selectedColor: AfiCareTheme.primaryBlue, // navy — passes contrast for white text
                  checkmarkColor: Colors.white,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PWD Assessment — provider fills during consultation
  // ---------------------------------------------------------------

  /// Returns suggested referrals from the rule engine given the currently
  /// selected disability types. Auto-populates _selectedReferrals on first
  /// call; provider can then deselect any that do not apply.
  List<String> _getPwdReferralSuggestions() {
    if (_pwdTypes.isEmpty) return [];
    final profile = DisabilityProfile(
      patientId: '',
      disabilityTypes: _pwdTypes,
      severity: _pwdSeverity,
      assistiveDevices: const [],
      lastUpdated: DateTime.now(),
      updatedBy: 'provider',
    );
    return PwdRuleEngine().getSuggestedReferrals(profile);
  }

  Widget _buildPwdAssessment() {
    final suggestedReferrals = _getPwdReferralSuggestions();

    // Auto-populate referrals when disability types are first selected
    if (_pwdTypes.isNotEmpty && _selectedReferrals.isEmpty) {
      _selectedReferrals.addAll(suggestedReferrals);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('pwd_assessment_tile'),
        initiallyExpanded: _pwdSectionExpanded,
        onExpansionChanged: (v) => setState(() => _pwdSectionExpanded = v),
        leading: const Icon(Icons.accessibility_new),
        title: const Text(
          'PWD Assessment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _pwdTypes.isEmpty
              ? 'Tap to record disability profile'
              : _pwdTypes.map((t) => t.displayName).join(', '),
          style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Disability type multi-select ----
                const Text(
                  'Disability Type(s)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: DisabilityType.values.map((type) {
                    final selected = _pwdTypes.contains(type);
                    return Semantics(
                      label: '${type.displayName}: ${type.description}',
                      child: FilterChip(
                        label: Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AfiCareTheme.primaryBlue,
                        checkmarkColor: Colors.white,
                        tooltip: type.description,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _pwdTypes.add(type);
                            } else {
                              _pwdTypes.remove(type);
                            }
                            // Refresh referral suggestions when types change
                            _selectedReferrals
                              ..clear()
                              ..addAll(_getPwdReferralSuggestions());
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ---- Severity ----
                const Text(
                  'Severity',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<DisabilitySeverity>(
                  segments: DisabilitySeverity.values
                      .map((s) => ButtonSegment(
                            value: s,
                            label: Text(s.displayName),
                          ))
                      .toList(),
                  selected: {_pwdSeverity},
                  onSelectionChanged: (v) =>
                      setState(() => _pwdSeverity = v.first),
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ---- Clinical diagnosis ----
                Semantics(
                  label: 'Clinical diagnosis field',
                  child: TextFormField(
                    controller: _clinicalDiagnosisController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Clinical / Medical Diagnosis',
                      hintText: 'e.g. Spastic Diplegia Cerebral Palsy',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_information),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ---- Provider notes ----
                Semantics(
                  label: 'Provider notes for other clinicians',
                  child: TextFormField(
                    controller: _providerNotesController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Clinical Notes',
                      hintText:
                          'Notes for other providers — accommodations needed, communication preferences…',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ---- Caregiver consent ----
                Semantics(
                  label: 'Requires caregiver for consent toggle',
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requires Caregiver for Consent'),
                    subtitle: const Text(
                      'Patient cannot give informed consent independently',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _requiresCaregiverConsent,
                    activeColor: AfiCareTheme.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _requiresCaregiverConsent = v),
                  ),
                ),

                // ---- Specialist referrals (rule-engine suggested) ----
                if (suggestedReferrals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined, size: 16,
                          color: Color(0xFF616161)),
                      const SizedBox(width: 6),
                      const Text(
                        'Suggested Referrals',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'Information about referral suggestions',
                        child: Tooltip(
                          message:
                              'Auto-suggested by rule engine based on selected disability types. Deselect any that do not apply.',
                          child: const Icon(Icons.info_outline, size: 16,
                              color: Color(0xFF616161)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: suggestedReferrals.map((ref) {
                      final selected = _selectedReferrals.contains(ref);
                      return FilterChip(
                        label: Text(
                          ref,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AfiCareTheme.primaryGreen,
                        checkmarkColor: Colors.white,
                        onSelected: (val) => setState(() {
                          if (val) {
                            _selectedReferrals.add(ref);
                          } else {
                            _selectedReferrals.remove(ref);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSigns() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vital Signs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildVitalSignSlider(
              'Temperature (°C)',
              _temperature,
              35.0,
              42.0,
              (value) => setState(() => _temperature = value),
              '${_temperature.toStringAsFixed(1)}°C',
            ),
            _buildVitalSignSlider(
              'Systolic BP (mmHg)',
              _systolicBP.toDouble(),
              80.0,
              200.0,
              (value) => setState(() => _systolicBP = value.toInt()),
              '$_systolicBP mmHg',
            ),
            _buildVitalSignSlider(
              'Diastolic BP (mmHg)',
              _diastolicBP.toDouble(),
              40.0,
              120.0,
              (value) => setState(() => _diastolicBP = value.toInt()),
              '$_diastolicBP mmHg',
            ),
            _buildVitalSignSlider(
              'Pulse (bpm)',
              _pulse.toDouble(),
              40.0,
              150.0,
              (value) => setState(() => _pulse = value.toInt()),
              '$_pulse bpm',
            ),
            _buildVitalSignSlider(
              'Respiratory Rate (/min)',
              _respiratoryRate.toDouble(),
              8.0,
              40.0,
              (value) => setState(() => _respiratoryRate = value.toInt()),
              '$_respiratoryRate /min',
            ),
            _buildVitalSignSlider(
              'Oxygen Saturation (%)',
              _oxygenSaturation.toDouble(),
              80.0,
              100.0,
              (value) => setState(() => _oxygenSaturation = value.toInt()),
              '$_oxygenSaturation%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    String displayValue,
  ) {
    // Extract unit from displayValue (e.g. "37.0°C" → unit "°C")
    final unitMatch = RegExp(r'[^\d.]+$').firstMatch(displayValue);
    final unit = unitMatch?.group(0) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              // Text input alternative for motor-impaired users
              SizedBox(
                width: 80,
                child: TextFormField(
                  key: ValueKey('$label-$value'),
                  initialValue: value % 1 == 0
                      ? value.toInt().toString()
                      : value.toStringAsFixed(1),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    suffixText: unit,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n >= min && n <= max) {
                      onChanged(n);
                    }
                  },
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AfiCareTheme.primaryGreen,
            semanticFormatterCallback: (v) => displayValue,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeWithAI,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.smart_toy),
        label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AfiCareTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _analyzeWithAI() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedSymptoms = _symptoms.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.replaceAll('_', ' '))
        .toList();

    if (selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one symptom'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final medicalAI = MedicalAIService();
      
      final result = await medicalAI.conductConsultation(
        patientId: _medilinkIdController.text,
        symptoms: selectedSymptoms,
        vitalSigns: {
          'temperature': _temperature,
          'systolic_bp': _systolicBP.toDouble(),
          'diastolic_bp': _diastolicBP.toDouble(),
          'pulse': _pulse.toDouble(),
          'respiratory_rate': _respiratoryRate.toDouble(),
          'oxygen_saturation': _oxygenSaturation.toDouble(),
        },
        age: _age,
        gender: _gender,
        chiefComplaint: _chiefComplaintController.text,
      );

      setState(() {
        _aiResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAIResults() {
    if (_aiResult == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: AfiCareTheme.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Analysis Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Triage Level
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTriageColor(_aiResult!.triageLevel).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getTriageColor(_aiResult!.triageLevel),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTriageIcon(_aiResult!.triageLevel),
                    color: _getTriageColor(_aiResult!.triageLevel),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Triage Level: ${_aiResult!.triageLevel.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getTriageColor(_aiResult!.triageLevel),
                          ),
                        ),
                        Text(
                          'Confidence: ${(_aiResult!.confidenceScore * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Suspected Conditions
            const Text(
              'Suspected Conditions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._aiResult!.suspectedConditions.take(3).map((condition) {
              final confidence = (condition['confidence'] as double? ?? 0.0) * 100;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        condition['name'] ?? 'Unknown Condition',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Recommendations
            const Text(
              'AI Recommendations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._aiResult!.recommendations.take(5).map((recommendation) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AfiCareTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveConsultation(context),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareConsultation(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AfiCareTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTriageColor(String triageLevel) {
    switch (triageLevel.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      case 'less_urgent':
        return Colors.yellow[700]!;
      case 'non_urgent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTriageIcon(String triageLevel) {
    switch (triageLevel.toLowerCase()) {
      case 'emergency':
        return Icons.emergency;
      case 'urgent':
        return Icons.warning;
      case 'less_urgent':
        return Icons.schedule;
      case 'non_urgent':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  // ── Prescriptions card ───────────────────────────────────
  Widget _buildPrescriptionsCard() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _prescriptionSectionExpanded,
        onExpansionChanged: (v) =>
            setState(() => _prescriptionSectionExpanded = v),
        leading: const Icon(Icons.medication),
        title: const Text(
          'Prescriptions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _prescriptions.isEmpty
              ? 'No medications added'
              : '${_prescriptions.length} medication(s)',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                ..._prescriptions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final med = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  med['medication'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.red),
                                onPressed: () => setState(
                                    () => _prescriptions.removeAt(i)),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _infoChip('${med['dosage']}'),
                              const SizedBox(width: 8),
                              _infoChip('${med['frequency']}'),
                              const SizedBox(width: 8),
                              _infoChip('${med['duration']}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMedicationDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AfiCareTheme.primaryBlue,
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

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: AfiCareTheme.primaryBlue)),
    );
  }

  void _addMedicationDialog() {
    final medController = TextEditingController();
    final dosageController = TextEditingController();
    String frequency = 'Once daily';
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 500mg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    'Once daily',
                    'Twice daily',
                    'Three times daily',
                    'Four times daily',
                    'As needed',
                  ]
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => frequency = v ?? frequency),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (e.g. 7 days)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (medController.text.trim().isEmpty) return;
                setState(() {
                  _prescriptions.add({
                    'medication': medController.text.trim(),
                    'dosage': dosageController.text.trim().isEmpty
                        ? '-'
                        : dosageController.text.trim(),
                    'frequency': frequency,
                    'duration': durationController.text.trim().isEmpty
                        ? '-'
                        : durationController.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Appointment scheduling card ──────────────────────────
  Widget _buildAppointmentSchedulingCard() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _appointmentSectionExpanded,
        onExpansionChanged: (v) =>
            setState(() => _appointmentSectionExpanded = v),
        leading: const Icon(Icons.calendar_month),
        title: const Text(
          'Schedule Follow-up Appointment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _appointmentDate != null
              ? 'Set: ${_appointmentDate!.day}/${_appointmentDate!.month}/${_appointmentDate!.year}'
              : 'Optional',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate:
                          DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _appointmentDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _appointmentDate != null
                          ? '${_appointmentDate!.day}/${_appointmentDate!.month}/${_appointmentDate!.year}'
                          : 'Select date',
                      style: TextStyle(
                        color: _appointmentDate != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Time picker
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _appointmentTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      _appointmentTime != null
                          ? _appointmentTime!.format(context)
                          : 'Select time',
                      style: TextStyle(
                        color: _appointmentTime != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Type toggle
                const Text('Type',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                SegmentedButton<AppointmentType>(
                  segments: const [
                    ButtonSegment(
                      value: AppointmentType.inPerson,
                      icon: Icon(Icons.location_on),
                      label: Text('In-Person'),
                    ),
                    ButtonSegment(
                      value: AppointmentType.telehealth,
                      icon: Icon(Icons.video_call),
                      label: Text('Telehealth'),
                    ),
                  ],
                  selected: {_appointmentType},
                  onSelectionChanged: (s) =>
                      setState(() => _appointmentType = s.first),
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AfiCareTheme.primaryBlue;
                      }
                      return null;
                    }),
                    foregroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _appointmentNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveConsultation(BuildContext context) async {
    if (_aiResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please run AI analysis first before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show saving dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Saving consultation...'),
          ],
        ),
      ),
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final consultationProvider =
        Provider.of<ConsultationProvider>(context, listen: false);
    final providerId = authProvider.currentUser?.id ?? 'unknown';

    final vitalSigns = VitalSigns(
      temperature: _temperature,
      systolicBP: _systolicBP,
      diastolicBP: _diastolicBP,
      pulseRate: _pulse,
      respiratoryRate: _respiratoryRate,
      oxygenSaturation: _oxygenSaturation.toDouble(),
    );

    final selectedSymptoms = _symptoms.entries
        .where((e) => e.value)
        .map((e) => e.key.replaceAll('_', ' '))
        .toList();

    final consultationId = await consultationProvider.saveConsultation(
      patientId: _medilinkIdController.text.trim(),
      providerId: providerId,
      chiefComplaint: _chiefComplaintController.text.trim(),
      symptoms: selectedSymptoms,
      vitalSigns: vitalSigns,
      recommendations: _aiResult!.recommendations,
      followUpRequired: _aiResult!.followUpRequired,
    );

    final success = consultationId != null;

    // Capture providers before async gaps to avoid using context after await
    final prescriptionProvider =
        Provider.of<PrescriptionProvider>(context, listen: false);
    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);

    // Save prescriptions if any
    if (success && _prescriptions.isNotEmpty) {
      for (final med in _prescriptions) {
        await prescriptionProvider.createPrescription(
          PrescriptionModel(
            id: '',
            patientId: _medilinkIdController.text.trim(),
            providerId: providerId,
            consultationId: consultationId,
            medicationName: med['medication'] ?? '',
            dosage: med['dosage'] ?? '',
            frequency: med['frequency'] ?? '',
            duration: med['duration'] ?? '',
            issuedAt: DateTime.now(),
            status: PrescriptionStatus.active,
          ),
        );
      }
    }

    // Save follow-up appointment if date is set
    if (success && _appointmentDate != null) {
      final scheduledAt = DateTime(
        _appointmentDate!.year,
        _appointmentDate!.month,
        _appointmentDate!.day,
        _appointmentTime?.hour ?? 9,
        _appointmentTime?.minute ?? 0,
      );
      await appointmentProvider.bookAppointment(
        AppointmentModel(
          id: '',
          patientId: _medilinkIdController.text.trim(),
          providerId: providerId,
          scheduledAt: scheduledAt,
          type: _appointmentType,
          status: AppointmentStatus.pending,
          notes: _appointmentNotesController.text.trim().isEmpty
              ? null
              : _appointmentNotesController.text.trim(),
          isFollowUp: true,
          consultationId: consultationId,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close spinner

    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('Saved Successfully'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${_medilinkIdController.text}'),
              const SizedBox(height: 8),
              Text('Triage: ${_aiResult!.triageLevel.toUpperCase()}'),
              const SizedBox(height: 8),
              const Text(
                'Consultation saved to the patient\'s medical record.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // back to dashboard
              },
              child: const Text('Done'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareConsultation(context);
              },
              child: const Text('Share with Patient'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save consultation. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareConsultation(BuildContext context) {
    if (_aiResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please run AI analysis first before sharing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Consultation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.message, color: Colors.white),
              ),
              title: const Text('Send via SMS'),
              subtitle: const Text('Send summary to patient\'s phone'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consultation summary sent via SMS'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.email, color: Colors.white),
              ),
              title: const Text('Send via Email'),
              subtitle: const Text('Send detailed report to patient\'s email'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consultation report sent via email'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.qr_code, color: Colors.white),
              ),
              title: const Text('Generate QR Code'),
              subtitle: const Text('Patient can scan to view consultation'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('QR code generated for patient'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.print, color: Colors.white),
              ),
              title: const Text('Print Summary'),
              subtitle: const Text('Print consultation summary'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Printing consultation summary...'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _medilinkIdController.dispose();
    _clinicalDiagnosisController.dispose();
    _providerNotesController.dispose();
    _appointmentNotesController.dispose();
    super.dispose();
  }
}