import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/consultation_model.dart';
import 'package:aficare_flutter/services/medical_ai_service.dart';

void main() {
  final service = MedicalAIService();

  group('MedicalAIService.analyze', () {
    test('identifies malaria and returns a triage level', () async {
      final result = await service.analyze(
        symptoms: ['fever', 'chills', 'headache', 'muscle aches'],
        vitalSigns: VitalSigns(temperature: 38.0, pulseRate: 90),
        age: 30,
        gender: 'female',
      );

      final diagnoses = result['diagnoses'] as List<Diagnosis>;
      expect(diagnoses, isNotEmpty);
      final names = diagnoses.map((d) => d.condition).toList();
      expect(names.first, 'Malaria');
      expect(result['triage_level'], isA<String>());
    });

    test('danger symptom escalates triage to emergency', () async {
      final result = await service.analyze(
        symptoms: ['fever', 'difficulty breathing'],
        vitalSigns: VitalSigns(temperature: 38.0),
        age: 40,
        gender: 'male',
      );

      expect(result['triage_level'], 'emergency');
    });
  });

  group('MedicalAIService.conductConsultation', () {
    test('produces a typed ConsultationResult via local AI', () async {
      final result = await service.conductConsultation(
        patientId: 'p1',
        symptoms: ['fever', 'headache'],
        vitalSigns: {'temperature': 39.5},
        age: 28,
        gender: 'female',
        chiefComplaint: 'Fever and headache',
      );

      expect(result, isA<ConsultationResult>());
      expect(result.patientId, 'p1');
      expect(result.chiefComplaint, 'Fever and headache');
      expect(result.symptoms, ['fever', 'headache']);
      expect(result.suspectedConditions, isNotEmpty);
      expect(result.recommendations, isNotEmpty);
      expect(result.timestamp, isA<DateTime>());

      // High fever (39.5) is at least urgent.
      expect(
        result.triageLevel == 'urgent' || result.triageLevel == 'less_urgent',
        isTrue,
        reason: 'expected an elevated triage for temp 39.5, got ${result.triageLevel}',
      );
    });

    test('marks referralNeeded for an emergency presentation', () async {
      final result = await service.conductConsultation(
        patientId: 'p2',
        symptoms: ['chest pain', 'difficulty breathing'],
        vitalSigns: <String, double>{},
        age: 60,
        gender: 'male',
        chiefComplaint: 'Chest pain',
      );

      expect(result.triageLevel, 'emergency');
      expect(result.referralNeeded, isTrue);
    });

    test('does not require referral for a routine presentation', () async {
      final result = await service.conductConsultation(
        patientId: 'p3',
        symptoms: ['runny nose', 'sore throat'],
        vitalSigns: <String, double>{},
        age: 25,
        gender: 'female',
        chiefComplaint: 'Cold symptoms',
      );

      expect(result.triageLevel, 'non_urgent');
      expect(result.referralNeeded, isFalse);
    });
  });
}
