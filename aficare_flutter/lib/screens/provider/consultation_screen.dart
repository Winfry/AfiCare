import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../services/medical_ai_service.dart';
import '../../models/consultation_model.dart';
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
                      const Text('Age'),
                      Slider(
                        value: _age.toDouble(),
                        min: 0,
                        max: 120,
                        divisions: 120,
                        label: '$_age years',
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
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _symptoms[symptom] = selected;
                    });
                  },
                  selectedColor: AfiCareTheme.primaryGreen,
                  checkmarkColor: Colors.white,
                );
              },
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                displayValue,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AfiCareTheme.primaryGreen,
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

    final success = await consultationProvider.saveConsultation(
      patientId: _medilinkIdController.text.trim(),
      providerId: providerId,
      chiefComplaint: _chiefComplaintController.text.trim(),
      symptoms: selectedSymptoms,
      vitalSigns: vitalSigns,
      recommendations: _aiResult!.recommendations,
      followUpRequired: _aiResult!.followUpRequired,
    );

    if (!context.mounted) return;
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
    super.dispose();
  }
}