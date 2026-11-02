import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/disability_profile.dart';
import 'package:aficare_flutter/models/pwd_patient_guidance.dart';
import 'package:aficare_flutter/services/pwd_rule_engine.dart';

DisabilityProfile profile({
  List<DisabilityType> types = const [DisabilityType.visual],
  DisabilitySeverity severity = DisabilitySeverity.severe,
  List<String> devices = const [],
  bool caregiverConsent = false,
}) =>
    DisabilityProfile(
      patientId: 'p1',
      disabilityTypes: types,
      severity: severity,
      assistiveDevices: devices,
      lastUpdated: DateTime(2026, 11, 1),
      updatedBy: 'patient',
      requiresCaregiverForConsent: caregiverConsent,
    );

/// Every profile shape the engine can see: each disability type alone and
/// all together, each severity, with and without the devices and the
/// caregiver flag that change its rules.
Iterable<DisabilityProfile> everyProfile() sync* {
  final typeSets = [
    for (final t in DisabilityType.values) [t],
    DisabilityType.values,
  ];
  for (final types in typeSets) {
    for (final severity in DisabilitySeverity.values) {
      for (final devices in [const <String>[], const ['Wheelchair', 'Catheter']]) {
        for (final consent in [false, true]) {
          yield profile(types: types, severity: severity, devices: devices, caregiverConsent: consent);
        }
      }
    }
  }
}

List<String> titles(DisabilityProfile p) => PwdPatientGuidance.tipsFor(p).map((t) => t.title).toList();

void main() {
  const engine = PwdRuleEngine();

  test('every suggestion the engine can make has patient wording, except the ones left out on purpose', () {
    final missing = <String>{};
    for (final p in everyProfile()) {
      for (final rec in engine.getRecommendations(p)) {
        if (rec.category == RecommendationCategory.providerNote) continue;
        if (PwdPatientGuidance.notForPatients.contains(rec.id)) continue;
        if (!PwdPatientGuidance.hasWordsFor(rec.id)) missing.add(rec.id);
      }
    }
    expect(missing, isEmpty, reason: 'add these to pwd_patient_guidance.dart');
  });

  test('no patient card ever uses clinician language', () {
    final banned = RegExp(
      r'suicide|columbia|document|provider|educate|'
      r'\bthe patient\b|patient has|patients with|\brefer to\b|\bassess|\bscreen (using|urine)|'
      r'PHQ|GAD|eGFR|creatinine|fundus|intraocular|cerumen|otitis|decubitus|ischial|sacrum|'
      r'prophylactic|contracture|spasticity|dysphagia|aspiration|\bAAC\b|\bSLT\b|mmHg|< ?\d',
      caseSensitive: false,
    );
    final badges = RegExp(r'\b(CRITICAL|HIGH|MEDIUM|LOW)\b');

    // The guard does catch the clinician wording it is meant to keep out.
    final james = engine.getRecommendations(
        profile(types: [DisabilityType.mentalHealth, DisabilityType.cognitive], caregiverConsent: true));
    final suicide = james.firstWhere((r) => r.id == 'mental_suicide_risk');
    expect(banned.hasMatch(suicide.title), isTrue);
    expect(banned.hasMatch(suicide.description), isTrue);
    expect(badges.hasMatch('CRITICAL'), isTrue);
    expect(banned.hasMatch(james.firstWhere((r) => r.id == 'cognitive_caregiver_required').description), isTrue);
    for (final p in everyProfile()) {
      for (final tip in PwdPatientGuidance.tipsFor(p)) {
        for (final text in [tip.title, tip.body, tip.ask]) {
          expect(banned.hasMatch(text), isFalse, reason: '${tip.id}: "$text"');
          expect(badges.hasMatch(text), isFalse, reason: '${tip.id}: "$text"');
        }
        expect(tip.title, isNotEmpty);
        expect(tip.body, isNotEmpty);
        expect(tip.ask, isNotEmpty);
      }
    }
  });

  test('notes for the clinician never reach the patient', () {
    for (final p in everyProfile()) {
      final ids = PwdPatientGuidance.tipsFor(p).map((t) => t.id);
      expect(ids.where((id) => id.endsWith('_provider_note')), isEmpty);
    }
  });

  group('mental health (James, severe)', () {
    final james = profile(types: [DisabilityType.mentalHealth], severity: DisabilitySeverity.severe);

    test('the engine still gives his doctor the suicide-risk screening', () {
      expect(engine.getRecommendations(james).map((r) => r.id), contains('mental_suicide_risk'));
    });

    test('he gets support lines instead of a label', () {
      expect(PwdPatientGuidance.tipsFor(james).map((t) => t.id), isNot(contains('mental_suicide_risk')));
      expect(PwdPatientGuidance.offersSupportLines(james), isTrue);
    });

    test('his cards speak to him', () {
      expect(titles(james), containsAll(['Keep taking your medicines', 'Regular check-ins', 'Sleep']));
    });

    test('support is offered at every severity, and only for mental health', () {
      for (final s in DisabilitySeverity.values) {
        expect(PwdPatientGuidance.offersSupportLines(profile(types: [DisabilityType.mentalHealth], severity: s)), isTrue);
      }
      expect(PwdPatientGuidance.offersSupportLines(profile(types: [DisabilityType.hearing])), isFalse);
      expect(PwdPatientGuidance.offersSupportLines(profile(types: [DisabilityType.multiple])), isFalse);
    });
  });

  group('caregiver (Daniel)', () {
    test('when his care team says a guardian must be there, it says so kindly', () {
      final tip = PwdPatientGuidance.tipsFor(profile(types: [DisabilityType.cognitive], caregiverConsent: true))
          .firstWhere((t) => t.id == 'cognitive_caregiver_required');
      expect(tip.title, 'Bring your carer or guardian');
      expect(tip.ask, 'Bring them to your appointments.');
    });

    test('otherwise it is an offer, not a requirement', () {
      final tip = PwdPatientGuidance.tipsFor(profile(types: [DisabilityType.cognitive]))
          .firstWhere((t) => t.id == 'cognitive_caregiver_required');
      expect(tip.title, 'Help with health decisions');
    });
  });

  test('the engine still decides what applies: mild drops the less urgent ones', () {
    final mild = titles(profile(types: [DisabilityType.visual], severity: DisabilitySeverity.mild));
    expect(mild, contains('Yearly eye pressure check'));
    expect(mild, isNot(contains('Vitamin A')), reason: 'medium priority');
    expect(mild, isNot(contains('Getting around safely')), reason: 'low priority');
    final severe = titles(profile(types: [DisabilityType.visual], severity: DisabilitySeverity.severe));
    expect(severe, containsAll(['Vitamin A', 'Getting around safely']));
  });

  test('the engine still decides the order: the most important comes first', () {
    final tips = PwdPatientGuidance.tipsFor(profile(types: [DisabilityType.mobility], devices: ['Wheelchair']));
    expect(tips.first.id, 'mobility_pressure_sore');
    expect(tips.first.ask, contains('cushion for your wheelchair'));
  });

  test('a catheter user is told the signs of infection', () {
    final tips = PwdPatientGuidance.tipsFor(profile(types: [DisabilityType.mobility], devices: ['Catheter']));
    final uti = tips.firstWhere((t) => t.id == 'mobility_uti_screening');
    expect(uti.body, contains('fever'));
  });

  test('the same advice is not repeated for two conditions', () {
    final t = titles(profile(types: [DisabilityType.visual, DisabilityType.chronicIllness]));
    expect(t.where((x) => x == 'Blood pressure checks'), hasLength(1));
    expect(t.where((x) => x.contains('back of the eye') || x == 'Eye check for diabetes'), hasLength(1));
    final both = titles(profile(types: [DisabilityType.hearing, DisabilityType.speech]));
    expect(both.where((x) => x == 'How you are feeling'), hasLength(1));
  });

  test('an empty profile has no suggestions and no support box', () {
    final empty = profile(types: const []);
    expect(PwdPatientGuidance.tipsFor(empty), isEmpty);
    expect(PwdPatientGuidance.offersSupportLines(empty), isFalse);
  });
}
