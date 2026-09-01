import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/services/drug_knowledge_service.dart';

void main() {
  final fakeData = <String, String>{
    'assets/knowledge_base/formulary_ke.json': jsonEncode({
      'medications': [
        {
          'generic_name': 'Ibuprofen',
          'brand_names': ['Brufen', 'Advil'],
          'category': 'NSAID',
          'contraindications': ['asthma'],
        },
        {
          'generic_name': 'Warfarin',
          'brand_names': ['Coumadin'],
          'category': 'anticoagulant',
          'contraindications': [],
        },
      ],
    }),
    'assets/knowledge_base/interactions.json': jsonEncode({
      'interactions': [
        {
          'drug_a': 'ibuprofen',
          'drug_b': 'warfarin',
          'severity': 'major',
          'effect': 'Increased bleeding risk',
          'mechanism': 'Platelet inhibition',
          'management': 'Monitor INR',
        },
      ],
    }),
    'assets/knowledge_base/dosages.json': jsonEncode({
      'categories': {
        'ibuprofen': [
          {'indication': 'pain', 'dose': '400mg'},
        ],
      },
    }),
  };

  void mockAssets() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) {
        return null;
      }
      final key = utf8.decode(
          message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
      final content = fakeData[key];
      if (content == null) {
        return null;
      }
      return ByteData.sublistView(utf8.encode(content));
    });
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockAssets();
  });

  setUp(() => mockAssets());

  group('DrugKnowledgeService.load', () {
    test('loads medications and datasets', () async {
      await DrugKnowledgeService().load();
      expect(DrugKnowledgeService().medications, hasLength(2));
    });

    test('searchMedications matches generic and brand names', () async {
      final service = DrugKnowledgeService();
      await service.load();

      expect(service.searchMedications('ibu'), hasLength(1));
      expect(service.searchMedications('brufen'), hasLength(1));
      expect(service.searchMedications('nope'), isEmpty);
      expect(service.searchMedications(''), isEmpty);
    });

    test('checkInteractions flags a known pair', () async {
      final service = DrugKnowledgeService();
      await service.load();

      final hits = service.checkInteractions(['Ibuprofen', 'Warfarin']);
      expect(hits, hasLength(1));
      expect(hits.single['severity'], 'major');
      expect(hits.single['effect'], 'Increased bleeding risk');

      expect(
        service.checkInteractions(['Ibuprofen']),
        isEmpty,
        reason: 'needs at least two drugs',
      );
    });

    test('checkAllergies matches a contraindicated drug', () async {
      final service = DrugKnowledgeService();
      await service.load();

      final hits = service.checkAllergies(['Ibuprofen'], ['asthma']);
      expect(hits, hasLength(1));
      expect(hits.single['medication'], 'Ibuprofen');

      expect(service.checkAllergies(['Warfarin'], ['asthma']), isEmpty);
    });

    test('getDosages returns matching entries', () async {
      final service = DrugKnowledgeService();
      await service.load();

      expect(service.getDosages('Ibuprofen'), hasLength(1));
      expect(service.getDosages('pain'), hasLength(1));
      expect(service.getDosages('nonexistent'), isEmpty);
    });

    test('findMedication resolves generic and brand names', () async {
      final service = DrugKnowledgeService();
      await service.load();

      expect(service.findMedication('ibuprofen')!['generic_name'], 'Ibuprofen');
      expect(service.findMedication('Advil')!['generic_name'], 'Ibuprofen');
      expect(service.findMedication('Missing'), isNull);
    });
  });
}
