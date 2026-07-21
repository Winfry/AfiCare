import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/drug_knowledge_service.dart';
import '../../utils/theme.dart';

class PrescriptionWriterScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final List<String>? knownAllergies;
  const PrescriptionWriterScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.knownAllergies,
  });

  @override
  State<PrescriptionWriterScreen> createState() => _PrescriptionWriterScreenState();
}

class _PrescriptionWriterScreenState extends State<PrescriptionWriterScreen> {
  final _drugKnowledge = DrugKnowledgeService();
  final _searchController = TextEditingController();

  final List<_PrescriptionEntry> _prescribed = [];
  List<Map<String, dynamic>> _interactionWarnings = [];
  List<Map<String, dynamic>> _allergyWarnings = [];

  bool _isLoadingKnowledge = true;
  bool _isSubmitting = false;
  bool _showInteractionResults = false;

  @override
  void initState() {
    super.initState();
    _loadKnowledge();
  }

  Future<void> _loadKnowledge() async {
    await _drugKnowledge.load();
    if (mounted) setState(() => _isLoadingKnowledge = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addMedication(Map<String, dynamic> med) {
    final existing = _prescribed.where((p) =>
      p.genericName == med['generic_name']).length;

    if (existing >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication already added')),
      );
      return;
    }

    setState(() {
      _prescribed.add(_PrescriptionEntry(
        genericName: med['generic_name'] as String,
        category: med['category'] as String? ?? '',
        brandNames: (med['brand_names'] as List?)?.cast<String>() ?? [],
      ));
      _searchController.clear();
      _interactionWarnings.clear();
      _allergyWarnings.clear();
      _showInteractionResults = false;
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _prescribed.removeAt(index);
      _interactionWarnings.clear();
      _allergyWarnings.clear();
      _showInteractionResults = false;
    });
  }

  void _checkInteractions() {
    final drugNames = _prescribed.map((p) => p.genericName).toList();
    final interactions = _drugKnowledge.checkInteractions(drugNames);

    List<String> allergies = widget.knownAllergies ?? [];
    final allergyResults = _drugKnowledge.checkAllergies(drugNames, allergies);

    setState(() {
      _interactionWarnings = interactions;
      _allergyWarnings = allergyResults;
      _showInteractionResults = true;
    });
  }

  Future<void> _issuePrescriptions() async {
    if (_prescribed.isEmpty) return;

    bool anyEmpty = _prescribed.any((p) =>
      p.dosage.isEmpty || p.frequency.isEmpty || p.duration.isEmpty);

    if (anyEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in dosage, frequency, and duration for all medications'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final providerId = auth.currentUser?.id ?? '';
    final supabase = Supabase.instance.client;

    try {
      for (final entry in _prescribed) {
        await supabase.from('prescriptions').insert({
          'patient_id': widget.patientId,
          'provider_id': providerId,
          'medication_name': entry.genericName,
          'dosage': entry.dosage,
          'frequency': entry.frequency,
          'duration': entry.duration,
          'instructions': entry.instructions.isEmpty
              ? null : entry.instructions,
          'issued_at': DateTime.now().toIso8601String(),
          'status': 'active',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_prescribed.length} prescription(s) issued'),
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
        title: Text('Rx: ${widget.patientName}'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_prescribed.isNotEmpty)
            TextButton.icon(
              onPressed: _issuePrescriptions,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, color: Colors.white),
              label: Text(
                'Issue (${_prescribed.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoadingKnowledge
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Drug search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return [];
                      return _drugKnowledge.searchMedications(textEditingValue.text);
                    },
                    displayStringForOption: (med) => med['generic_name'] as String? ?? '',
                    fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search medication...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        onChanged: (_) => setState(() {}),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final med = options.elementAt(i);
                                final name = med['generic_name'] ?? '';
                                final brands = (med['brand_names'] as List?)?.join(', ') ?? '';
                                return ListTile(
                                  dense: true,
                                  title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: brands.isNotEmpty
                                      ? Text(brands, style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                                      : null,
                                  trailing: Icon(Icons.add_circle, color: AfiCareTheme.primaryGreen),
                                  onTap: () {
                                    onSelected(med);
                                    _addMedication(med);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: _addMedication,
                  ),
                ),

                // Selected medications
                Expanded(
                  child: _prescribed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medication, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('Search and add medications above',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            ...List.generate(_prescribed.length, (i) {
                              final entry = _prescribed[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.genericName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                            onPressed: () => _removeMedication(i),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _field('Dosage', entry.dosageController, 'e.g. 500mg'),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _field('Frequency', entry.frequencyController, 'e.g. TDS'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _field('Duration', entry.durationController, 'e.g. 7 days'),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _field('Route', entry.routeController, 'e.g. Oral'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _field('Instructions', entry.instructionsController, 'Optional notes'),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),

                            // Check interactions button
                            if (_prescribed.length >= 2)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _checkInteractions,
                                  icon: const Icon(Icons.warning_amber),
                                  label: const Text('Check Interactions & Allergies'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange[800],
                                    side: BorderSide(color: Colors.orange[300]!),
                                  ),
                                ),
                              ),

                            // Interaction results
                            if (_showInteractionResults) ...[
                              const SizedBox(height: 12),
                              if (_interactionWarnings.isEmpty && _allergyWarnings.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green[200]!),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('No interactions or allergy conflicts found',
                                          style: TextStyle(color: Colors.green)),
                                    ],
                                  ),
                                ),
                              ...(_interactionWarnings.map((iw) {
                                final severity = iw['severity'] as String? ?? 'unknown';
                                final color = severity == 'high' ? Colors.red
                                    : severity == 'moderate' ? Colors.orange
                                    : Colors.yellow[700]!;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: color, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${iw['drug_a']} + ${iw['drug_b']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              severity.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(iw['effect'] ?? '',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                      Text('Management: ${iw['management'] ?? ''}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                );
                              })),
                              ...(_allergyWarnings.map((aw) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${aw['medication']} — Allergy: ${aw['allergy']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red,
                                              ),
                                            ),
                                            Text('${aw['detail'] ?? ''}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })),
                            ],
                            const SizedBox(height: 80),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _PrescriptionEntry {
  final String genericName;
  final String category;
  final List<String> brandNames;
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();
  final routeController = TextEditingController();
  final instructionsController = TextEditingController();

  _PrescriptionEntry({
    required this.genericName,
    this.category = '',
    this.brandNames = const [],
  });

  String get dosage => dosageController.text.trim();
  String get frequency => frequencyController.text.trim();
  String get duration => durationController.text.trim();
  String get instructions => instructionsController.text.trim();
}
