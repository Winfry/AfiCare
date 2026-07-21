import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class RadiologyOrderScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? medilinkId;
  final String? age;
  final String? gender;
  final String? bloodType;

  const RadiologyOrderScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.medilinkId,
    this.age,
    this.gender,
    this.bloodType,
  });

  @override
  State<RadiologyOrderScreen> createState() => _RadiologyOrderScreenState();
}

class _RadiologyOrderScreenState extends State<RadiologyOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bodyPartController = TextEditingController();
  final _indicationController = TextEditingController();

  String? _selectedStudyType;
  String _priority = 'routine';
  bool _isSubmitting = false;

  final List<String> _studyTypes = [
    'X-ray', 'CT', 'Ultrasound', 'MRI', 'PET-CT', 'Mammography', 'Other',
  ];

  final List<String> _bodyPartSuggestions = [
    'Chest', 'Abdomen', 'Head', 'Pelvis',
    'Knee', 'Lumbar Spine', 'Shoulder', 'Hand',
  ];

  @override
  void dispose() {
    _bodyPartController.dispose();
    _indicationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a study type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id ?? '';
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('radiology_orders').insert({
        'patient_id': widget.patientId,
        'provider_id': providerId,
        'study_type': _selectedStudyType,
        'body_part': _bodyPartController.text.trim(),
        'clinical_indication': _indicationController.text.trim(),
        'priority': _priority,
        'status': 'ordered',
        'ordered_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Radiology order submitted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Radiology Order'),
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
              // Patient banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AfiCareTheme.primaryBlue, Color(0xFF2D4A7A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.patientName.isNotEmpty
                            ? widget.patientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AfiCareTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.patientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (widget.medilinkId != null) widget.medilinkId,
                              if (widget.age != null) widget.age,
                              if (widget.gender != null) widget.gender,
                              if (widget.bloodType != null) 'BT: ${widget.bloodType}',
                            ].where((s) => s != null).join('  •  '),
                            style: TextStyle(
                                fontSize: 11, color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Study Type
              _label('Study Type *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedStudyType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select study type',
                  prefixIcon: Icon(Icons.medical_services),
                ),
                items: _studyTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t),
                )).toList(),
                onChanged: (v) => setState(() => _selectedStudyType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Body Part
              _label('Body Part *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyPartController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Chest, Abdomen',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.accessibility_new),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: _bodyPartSuggestions.map((part) => ActionChip(
                  label: Text(part, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _bodyPartController.text = part,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Clinical Indication
              _label('Clinical Indication *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _indicationController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Persistent cough 3 weeks, rule out pneumonia',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_add),
                ),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Priority
              _label('Priority'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _priorityChip('Routine', 'routine', Colors.green),
                  const SizedBox(width: 8),
                  _priorityChip('Urgent', 'urgent', Colors.orange),
                  const SizedBox(width: 8),
                  _priorityChip('STAT', 'stat', Colors.red),
                ],
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting
                      ? 'Submitting...'
                      : 'Submit Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child:               TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draft saved')),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
  }

  Widget _priorityChip(String label, String value, Color color) {
    final selected = _priority == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(label, style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ),
        selected: selected,
        selectedColor: color,
        backgroundColor: color.withOpacity(0.1),
        onSelected: (_) => setState(() => _priority = value),
      ),
    );
  }
}
