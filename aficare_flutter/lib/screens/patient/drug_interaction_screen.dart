import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../models/drug_interaction_model.dart';

class DrugInteractionScreen extends StatefulWidget {
  final List<String> currentMedications;
  const DrugInteractionScreen({super.key, this.currentMedications = const []});

  @override
  State<DrugInteractionScreen> createState() => _DrugInteractionScreenState();
}

class _DrugInteractionScreenState extends State<DrugInteractionScreen> {
  final _newMedCtrl = TextEditingController();
  List<String> _selectedMeds = [];
  List<DrugInteraction> _interactions = [];
  bool _hasChecked = false;

  static const _commonMeds = [
    'Paracetamol', 'Amoxicillin', 'Metformin', 'Amlodipine',
    'Omeprazole', 'Lisinopril', 'Atorvastatin', 'Ibuprofen',
    'Warfarin', 'Aspirin', 'Fluoxetine', 'Salbutamol',
    'Ciprofloxacin', 'Metoprolol', 'Levothyroxine',
    'Spironolactone', 'Enalapril', 'Clopidogrel',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMeds = List.from(widget.currentMedications);
  }

  @override
  void dispose() {
    _newMedCtrl.dispose();
    super.dispose();
  }

  void _checkInteractions() {
    final interactions = DrugInteractionService.checkInteractions(_selectedMeds);
    setState(() {
      _interactions = interactions;
      _hasChecked = true;
    });
  }

  void _addMedication(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _selectedMeds.contains(trimmed)) return;
    setState(() {
      _selectedMeds.add(trimmed);
      _newMedCtrl.clear();
      _hasChecked = false;
    });
    _checkInteractions();
  }

  void _removeMedication(String name) {
    setState(() {
      _selectedMeds.remove(name);
      _hasChecked = false;
    });
    _checkInteractions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/patient'),
            ),
            title: const Text('Drug Interaction Checker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newMedCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type medication name...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle_rounded, color: AppColors.canopy),
                              onPressed: () => _addMedication(_newMedCtrl.text),
                            ),
                          ),
                          onSubmitted: _addMedication,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick add common Kenya medications
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _commonMeds.take(8).map((med) {
                      final isSelected = _selectedMeds.contains(med);
                      return GestureDetector(
                        onTap: () => isSelected ? _removeMedication(med) : _addMedication(med),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.canopy.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppColors.canopy : AppColors.borderSubtle),
                          ),
                          child: Text(med, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.canopy : Colors.grey.shade700)),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_selectedMeds.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedMeds.map((med) => Chip(
                        label: Text(med, style: const TextStyle(fontSize: 13)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteIconColor: Colors.red,
                        onDeleted: () => _removeMedication(med),
                        backgroundColor: AppColors.canopy.withOpacity(0.08),
                        side: BorderSide(color: AppColors.canopy.withOpacity(0.2)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _checkInteractions,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text('Check ${_selectedMeds.length} Medications'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],

                  if (_hasChecked) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          _interactions.isEmpty ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: _interactions.isEmpty ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _interactions.isEmpty
                              ? 'No interactions found'
                              : '${_interactions.length} interaction${_interactions.length > 1 ? 's' : ''} found',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _interactions.isEmpty ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_interactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('No known interactions between these medications. Always confirm with your pharmacist or doctor.',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      )
                    else
                      ...(_interactions.map((i) => _interactionCard(i))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactionCard(DrugInteraction interaction) {
    final severityColor = _severityColor(interaction.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: severityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(interaction.severity.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: severityColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${interaction.drug1} + ${interaction.drug2}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(interaction.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          if (interaction.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFF57F17), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(interaction.recommendation,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'severe': return const Color(0xFFC62828);
      case 'moderate': return const Color(0xFFF57F17);
      case 'mild': return const Color(0xFFF9A825);
      default: return Colors.grey;
    }
  }
}
