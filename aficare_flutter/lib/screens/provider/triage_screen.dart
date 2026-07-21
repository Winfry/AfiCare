import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/triage_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class TriageScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const TriageScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _tempController = TextEditingController();
  final _sysBPController = TextEditingController();
  final _diaBPController = TextEditingController();
  final _hrController = TextEditingController();
  final _rrController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  TriageLevel _selectedTriage = TriageLevel.nonUrgent;
  final Set<String> _selectedSymptoms = {};
  bool _isSubmitting = false;

  final List<String> _symptomOptions = [
    'Fever', 'Cough', 'Headache', 'Abdominal pain',
    'Chest pain', 'Shortness of breath', 'Vomiting', 'Diarrhea',
    'Fatigue', 'Dizziness', 'Rash', 'Joint pain',
    'Back pain', 'Sore throat', 'Nausea', 'Bleeding',
    'Loss of consciousness', 'Seizure', 'Difficulty swallowing',
    'Eye pain', 'Ear pain', 'Swelling',
  ];

  @override
  void dispose() {
    _complaintController.dispose();
    _tempController.dispose();
    _sysBPController.dispose();
    _diaBPController.dispose();
    _hrController.dispose();
    _rrController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one symptom')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id ?? '';
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('triage_assessments').insert({
        'patient_id': widget.patientId,
        'provider_id': providerId,
        'assessed_at': DateTime.now().toIso8601String(),
        'chief_complaint': _complaintController.text.trim(),
        'symptoms': _selectedSymptoms.toList(),
        'triage_level': _triageLevelToDb(_selectedTriage),
        'temperature': _doubleOrNull(_tempController.text),
        'systolic_bp': _intOrNull(_sysBPController.text),
        'diastolic_bp': _intOrNull(_diaBPController.text),
        'heart_rate': _intOrNull(_hrController.text),
        'respiratory_rate': _intOrNull(_rrController.text),
        'oxygen_saturation': _doubleOrNull(_spo2Controller.text),
        'weight': _doubleOrNull(_weightController.text),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Triage assessment submitted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Triage: ${widget.patientName}'),
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
              _buildSection('Chief Complaint',
                TextFormField(
                  controller: _complaintController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fever and cough for 3 days',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildSection('Symptoms',
                Wrap(
                  spacing: 8, runSpacing: 4,
                  children: _symptomOptions.map((s) => FilterChip(
                    label: Text(s, style: const TextStyle(fontSize: 13)),
                    selected: _selectedSymptoms.contains(s),
                    selectedColor: AfiCareTheme.primaryBlue.withOpacity(0.2),
                    checkmarkColor: AfiCareTheme.primaryBlue,
                    onSelected: (sel) {
                      setState(() {
                        if (sel) { _selectedSymptoms.add(s); }
                        else { _selectedSymptoms.remove(s); }
                      });
                    },
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _buildSection('Triage Level',
                Row(
                  children: TriageLevel.values.map((l) {
                    final color = _triageColor(l);
                    final selected = _selectedTriage == l;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(_triageLabel(l),
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : color,
                            ),
                          ),
                          selected: selected,
                          selectedColor: color,
                          backgroundColor: color.withOpacity(0.1),
                          onSelected: (_) => setState(() => _selectedTriage = l),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _buildSection('Vital Signs',
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _vitalField('Temp (°C)', _tempController, TextInputType.numberWithOptions(decimal: true))),
                        const SizedBox(width: 8),
                        Expanded(child: _vitalField('Systolic BP', _sysBPController, TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _vitalField('Diastolic BP', _diaBPController, TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _vitalField('Heart Rate', _hrController, TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _vitalField('Resp. Rate', _rrController, TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: _vitalField('SpO2 (%)', _spo2Controller, TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _vitalField('Weight (kg)', _weightController, TextInputType.numberWithOptions(decimal: true)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSection('Notes',
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Additional notes...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Triage Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _vitalField(String label, TextEditingController ctrl, TextInputType kt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: kt,
      ),
    );
  }

  Color _triageColor(TriageLevel l) {
    switch (l) {
      case TriageLevel.emergency: return Colors.red;
      case TriageLevel.urgent: return Colors.orange;
      case TriageLevel.nonUrgent: return Colors.green;
    }
  }

  String _triageLabel(TriageLevel l) {
    switch (l) {
      case TriageLevel.emergency: return 'Emergency';
      case TriageLevel.urgent: return 'Urgent';
      case TriageLevel.nonUrgent: return 'Non-Urgent';
    }
  }

  String _triageLevelToDb(TriageLevel l) {
    switch (l) {
      case TriageLevel.emergency: return 'emergency';
      case TriageLevel.urgent: return 'urgent';
      case TriageLevel.nonUrgent: return 'non_urgent';
    }
  }

  double? _doubleOrNull(String v) {
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : double.tryParse(trimmed);
  }

  int? _intOrNull(String v) {
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }
}
