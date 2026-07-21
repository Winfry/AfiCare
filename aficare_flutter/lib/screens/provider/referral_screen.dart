import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class ReferralScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const ReferralScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _toFacilityController = TextEditingController();
  final _toDeptController = TextEditingController();
  final _toSpecialistController = TextEditingController();

  String _urgency = 'routine';
  bool _isSubmitting = false;

  final List<String> _kenyanFacilities = [
    'Kenyatta National Hospital',
    'Moi Teaching & Referral Hospital',
    'Aga Khan University Hospital',
    'Nairobi Hospital',
    'MP Shah Hospital',
    'KNH - MTRH Collaborative Center',
    'Coast General Teaching & Referral Hospital',
    'Kisumu County Referral Hospital',
    'Mathari National Teaching & Referral Hospital',
    'Gertrude\'s Children\'s Hospital',
    'Mater Misericordiae Hospital',
    'St. Mary\'s Mission Hospital',
    'Nyeri County Referral Hospital',
    'Embu Teaching & Referral Hospital',
    'Kakamega County Referral Hospital',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _toFacilityController.dispose();
    _toDeptController.dispose();
    _toSpecialistController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id ?? '';
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('referrals').insert({
        'patient_id': widget.patientId,
        'from_provider_id': providerId,
        'to_facility': _toFacilityController.text.trim(),
        'to_department': _toDeptController.text.trim().isEmpty
            ? null : _toDeptController.text.trim(),
        'to_specialist': _toSpecialistController.text.trim().isEmpty
            ? null : _toSpecialistController.text.trim(),
        'reason': _reasonController.text.trim(),
        'clinical_notes': _notesController.text.trim().isEmpty
            ? null : _notesController.text.trim(),
        'urgency': _urgency,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral submitted successfully'),
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
        title: Text('Refer: ${widget.patientName}'),
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
              _section('Receiving Facility',
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return [];
                    return _kenyanFacilities.where((f) =>
                      f.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                    _toFacilityController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search or type facility name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required' : null,
                      onFieldSubmitted: (_) => onSubmit(),
                    );
                  },
                  onSelected: (v) => _toFacilityController.text = v,
                ),
              ),
              const SizedBox(height: 16),
              _section('Department (optional)',
                TextFormField(
                  controller: _toDeptController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cardiology, Pediatrics',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section('Specialist (optional)',
                TextFormField(
                  controller: _toSpecialistController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Dr. Smith - Cardiologist',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section('Reason for Referral',
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    hintText: 'Clinical reason for referral',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              _section('Clinical Notes (optional)',
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Additional clinical information',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              _section('Urgency',
                Row(
                  children: [
                    _urgencyChip('Routine', 'routine', Colors.green),
                    const SizedBox(width: 8),
                    _urgencyChip('Urgent', 'urgent', Colors.orange),
                    const SizedBox(width: 8),
                    _urgencyChip('Emergency', 'emergency', Colors.red),
                  ],
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
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Referral'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryBlue,
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

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _urgencyChip(String label, String value, Color color) {
    final selected = _urgency == value;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : color,
        )),
        selected: selected,
        selectedColor: color,
        backgroundColor: color.withOpacity(0.1),
        onSelected: (_) => setState(() => _urgency = value),
      ),
    );
  }
}
