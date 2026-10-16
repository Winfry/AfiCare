import 'package:flutter/material.dart';
import '../../models/drug_interaction_model.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

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

  static const _commonMeds = [
    'Paracetamol', 'Amoxicillin', 'Metformin', 'Amlodipine',
    'Omeprazole', 'Lisinopril', 'Atorvastatin', 'Ibuprofen',
  ];

  /// A spread of severities from the known list, shown as examples so the
  /// page is useful before anything has been typed.
  static const _examplePairs = [
    ('Warfarin', 'Ibuprofen'),
    ('Metformin', 'Alcohol'),
    ('Ciprofloxacin', 'Calcium'),
    ('Amlodipine', 'Grapefruit'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMeds = List.from(widget.currentMedications);
    _interactions = _find(_selectedMeds);
  }

  @override
  void dispose() {
    _newMedCtrl.dispose();
    super.dispose();
  }

  void _checkInteractions() => setState(() => _interactions = _find(_selectedMeds));

  static List<DrugInteraction> _find(List<String> meds) => DrugInteractionService.checkInteractions(meds)
    ..sort((a, b) => _rank(a.severity).compareTo(_rank(b.severity)));

  static int _rank(String severity) => switch (severity) {
        'severe' => 0,
        'moderate' => 1,
        'mild' => 2,
        _ => 3,
      };

  void _addMedication(String name) {
    final trimmed = name.trim();
    _newMedCtrl.clear();
    if (trimmed.isEmpty || _isSelected(trimmed)) return;
    _selectedMeds.add(trimmed);
    _checkInteractions();
  }

  void _removeMedication(String name) {
    _selectedMeds.removeWhere((m) => m.toLowerCase() == name.toLowerCase());
    _checkInteractions();
  }

  bool _isSelected(String name) => _selectedMeds.any((m) => m.toLowerCase() == name.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return PSliverPage(
      eyebrow: 'Before you take it',
      title: 'Medicine checker',
      subtitle: "A quick reference for common interactions. It doesn't replace your pharmacist.",
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PCallout(
                tone: PTone.warn,
                title: 'Use this as a prompt, not an answer',
                body: 'If anything here worries you, speak to a pharmacist or your doctor '
                    'before changing what you take.',
              ),
              const SizedBox(height: 29),
              const PHeading('Your medicines'),
              _MedicinesCard(
                controller: _newMedCtrl,
                commonMeds: _commonMeds,
                selected: _selectedMeds,
                isSelected: _isSelected,
                onAdd: _addMedication,
                onRemove: _removeMedication,
              ),
              const SizedBox(height: 29),
              PHeading(
                'What we found',
                action: _selectedMeds.length < 2
                    ? null
                    : _interactions.isEmpty
                        ? const PBadge('Nothing in our list', tone: PTone.gray)
                        : PBadge('${_interactions.length} to look at', tone: PTone.warn),
              ),
              _ResultsCard(medCount: _selectedMeds.length, interactions: _interactions),
              const SizedBox(height: 29),
              const PHeading('Common pairs to watch'),
              PCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    for (final pair in _examplePairs)
                      for (final i in DrugInteractionService.checkInteractions([pair.$1, pair.$2]))
                        _InteractionRow(i, showAdvice: false),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Your medicines
// ═══════════════════════════════════════════════════════════════════════

class _MedicinesCard extends StatelessWidget {
  const _MedicinesCard({
    required this.controller,
    required this.commonMeds,
    required this.selected,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> commonMeds;
  final List<String> selected;
  final bool Function(String) isSelected;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add everything you take, including things bought without a prescription.', style: PT.sub()),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: pInput(hint: 'Type a medicine, e.g. Warfarin'),
                  onSubmitted: onAdd,
                ),
              ),
              const SizedBox(width: 8),
              PButton('Add', kind: PButtonKind.alt, onPressed: () => onAdd(controller.text)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Common in Kenya', style: PT.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final med in commonMeds)
                _MedPill(
                  label: med,
                  selected: isSelected(med),
                  onTap: () => isSelected(med) ? onRemove(med) : onAdd(med),
                ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Comparing', style: PT.label()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final m in selected) PRemovableBadge(m, onRemove: () => onRemove(m))],
            ),
          ],
        ],
      ),
    );
  }
}

class _MedPill extends StatelessWidget {
  const _MedPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? PT.badgeBlueBg : PT.white,
        borderRadius: BorderRadius.circular(PT.rPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PT.rPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? PT.teal : PT.line, width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(PT.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[const Icon(Icons.check_rounded, size: 14, color: PT.teal), const SizedBox(width: 4)],
                Text(label, style: PT.label().copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? PT.navy : PT.ink,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// What we found
// ═══════════════════════════════════════════════════════════════════════

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.medCount, required this.interactions});

  final int medCount;
  final List<DrugInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          if (medCount < 2)
            PRow(
              leading: const PSoftIcon(Icons.compare_arrows_rounded),
              title: medCount == 0 ? 'Add your medicines to compare them' : 'Add one more to compare',
              subtitle: 'Results appear here as soon as there are two.',
            )
          else if (interactions.isEmpty)
            // Deliberately not "no interactions": the list behind this is
            // short, and silence from it is not a sign that a mix is safe.
            PRow(
              leading: const PSoftIcon(Icons.search_off_rounded),
              title: 'Nothing found in our list',
              subtitle: 'This checker only knows ${DrugInteractionService.knownInteractions.length} '
                  "common pairs, so this doesn't mean they're safe together. "
                  'Your pharmacist can check them properly.',
            )
          else
            for (final i in interactions) _InteractionRow(i, showAdvice: true),
        ],
      ),
    );
  }
}

class _InteractionRow extends StatelessWidget {
  const _InteractionRow(this.interaction, {required this.showAdvice});

  final DrugInteraction interaction;
  final bool showAdvice;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (interaction.severity) {
      'severe' => ('Avoid', PTone.red),
      'moderate' => ('Caution', PTone.warn),
      'mild' => ('Low risk', PTone.blue),
      _ => (interaction.severity, PTone.gray),
    };
    final advice = interaction.recommendation;

    return PRow(
      leading: const PSoftIcon(Icons.medication_outlined),
      title: '${interaction.drug1} + ${interaction.drug2}',
      subtitle: interaction.description,
      trailing: [PBadge(label, tone: tone)],
      below: !showAdvice || advice.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 53),
              child: Text(advice, style: PT.rowSub().copyWith(color: PT.ink, fontWeight: FontWeight.w600)),
            ),
    );
  }
}
