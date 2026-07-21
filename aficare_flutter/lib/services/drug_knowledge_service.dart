import 'dart:convert';
import 'package:flutter/services.dart';

class DrugKnowledgeService {
  static final DrugKnowledgeService _instance = DrugKnowledgeService._();
  factory DrugKnowledgeService() => _instance;
  DrugKnowledgeService._();

  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _interactions = [];
  final Map<String, List<Map<String, dynamic>>> _dosages = {};

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;

    final formularyStr = await rootBundle.loadString('assets/knowledge_base/formulary_ke.json');
    final interactionsStr = await rootBundle.loadString('assets/knowledge_base/interactions.json');
    final dosagesStr = await rootBundle.loadString('assets/knowledge_base/dosages.json');

    final formulary = jsonDecode(formularyStr) as Map<String, dynamic>;
    _medications = List<Map<String, dynamic>>.from(formulary['medications'] ?? []);

    final interactions = jsonDecode(interactionsStr) as Map<String, dynamic>;
    _interactions = List<Map<String, dynamic>>.from(interactions['interactions'] ?? []);

    final dosages = jsonDecode(dosagesStr) as Map<String, dynamic>;
    final categories = dosages['categories'] as Map<String, dynamic>? ?? {};
    for (final entry in categories.entries) {
      _dosages[entry.key] = List<Map<String, dynamic>>.from(entry.value as List);
    }

    _loaded = true;
  }

  List<Map<String, dynamic>> get medications => _medications;

  List<Map<String, dynamic>> searchMedications(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _medications.where((m) {
      final name = (m['generic_name'] as String? ?? '').toLowerCase();
      final brands = (m['brand_names'] as List? ?? []).cast<String>();
      if (name.contains(q)) return true;
      for (final b in brands) {
        if (b.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> checkInteractions(List<String> drugNames) {
    if (drugNames.length < 2) return [];
    final results = <Map<String, dynamic>>[];
    final lowerNames = drugNames.map((n) => n.toLowerCase()).toList();

    for (final interaction in _interactions) {
      final drugA = (interaction['drug_a'] as String? ?? '').toLowerCase();
      final drugB = (interaction['drug_b'] as String? ?? '').toLowerCase();
      if (lowerNames.contains(drugA) && lowerNames.contains(drugB)) {
        results.add({
          'drug_a': interaction['drug_a'],
          'drug_b': interaction['drug_b'],
          'severity': interaction['severity'] ?? 'unknown',
          'effect': interaction['effect'] ?? '',
          'mechanism': interaction['mechanism'] ?? '',
          'management': interaction['management'] ?? '',
        });
      }
    }
    return results;
  }

  List<Map<String, dynamic>> checkAllergies(
    List<String> drugNames,
    List<String> patientAllergies,
  ) {
    if (drugNames.isEmpty || patientAllergies.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    final lowerAllergies = patientAllergies.map((a) => a.toLowerCase()).toList();

    for (final med in _medications) {
      final name = (med['generic_name'] as String? ?? '').toLowerCase();
      if (!drugNames.any((d) => d.toLowerCase() == name)) continue;

      final category = (med['category'] as String? ?? '').toLowerCase();
      final contraindications = (med['contraindications'] as List? ?? []).cast<String>();

      for (final allergy in lowerAllergies) {
        bool conflict = false;
        String? detail;

        if (category.contains(allergy)) {
          conflict = true;
          detail = '$name belongs to $category category';
        }
        for (final ci in contraindications) {
          if (ci.toLowerCase().contains(allergy)) {
            conflict = true;
            detail = '$name is contraindicated for $allergy';
            break;
          }
        }

        if (conflict) {
          results.add({
            'medication': med['generic_name'],
            'allergy': allergy,
            'detail': detail,
          });
        }
      }
    }
    return results;
  }

  List<Map<String, dynamic>> getDosages(String medicationName) {
    final name = medicationName.toLowerCase();
    for (final entry in _dosages.entries) {
      if (entry.key.toLowerCase() == name) {
        return entry.value;
      }
      for (final dose in entry.value) {
        final indication = (dose['indication'] as String? ?? '').toLowerCase();
        if (indication.contains(name)) {
          return [dose];
        }
      }
    }
    return [];
  }

  Map<String, dynamic>? findMedication(String name) {
    final q = name.toLowerCase();
    for (final m in _medications) {
      if ((m['generic_name'] as String? ?? '').toLowerCase() == q) return m;
      final brands = (m['brand_names'] as List? ?? []).cast<String>();
      for (final b in brands) {
        if (b.toLowerCase() == q) return m;
      }
    }
    return null;
  }
}
