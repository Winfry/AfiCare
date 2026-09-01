import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/disability_profile.dart';
import 'package:aficare_flutter/services/pwd_rule_engine.dart';

DisabilityProfile profile({
  List<DisabilityType> types = const [DisabilityType.visual],
  DisabilitySeverity severity = DisabilitySeverity.moderate,
  List<String> devices = const [],
  bool caregiverConsent = false,
}) {
  return DisabilityProfile(
    patientId: 'p1',
    disabilityTypes: types,
    severity: severity,
    assistiveDevices: devices,
    lastUpdated: DateTime.now(),
    updatedBy: 'patient',
    requiresCaregiverForConsent: caregiverConsent,
  );
}

void main() {
  const engine = PwdRuleEngine();

  group('PwdRuleEngine.getRecommendations', () {
    test('returns empty for an empty profile', () {
      expect(engine.getRecommendations(profile(types: [])), isEmpty);
    });

    test('visual profile produces visual rules sorted critical-first', () {
      final recs = engine.getRecommendations(
        profile(severity: DisabilitySeverity.severe),
      );
      expect(recs, isNotEmpty);
      expect(recs.every((r) => r.triggerType == DisabilityType.visual), isTrue);
      final priorities = recs.map((r) => r.priority).toList();
      expect(priorities, orderedEquals([
        ...priorities.where((p) => p == RecommendationPriority.critical),
        ...priorities.where((p) => p == RecommendationPriority.high),
        ...priorities.where((p) => p == RecommendationPriority.medium),
        ...priorities.where((p) => p == RecommendationPriority.low),
      ]));
    });

    test('mild severity drops medium and low rules', () {
      final mild = engine.getRecommendations(
        profile(severity: DisabilitySeverity.mild),
      );
      expect(
        mild.every(
          (r) =>
              r.priority == RecommendationPriority.critical ||
              r.priority == RecommendationPriority.high,
        ),
        isTrue,
      );
      expect(mild.any((r) => r.id == 'visual_orientation_mobility'), isFalse);
    });

    test('wheelchair user gets a critical pressure-sore assessment', () {
      final recs = engine.getRecommendations(
        profile(
          types: const [DisabilityType.mobility],
          severity: DisabilitySeverity.severe,
          devices: const ['Wheelchair'],
        ),
      );
      final sore =
          recs.firstWhere((r) => r.id == 'mobility_pressure_sore');
      expect(sore.priority, RecommendationPriority.critical);
    });

    test('catheter user gets a critical UTI screening', () {
      final recs = engine.getRecommendations(
        profile(
          types: const [DisabilityType.mobility],
          severity: DisabilitySeverity.moderate,
          devices: const ['Catheter'],
        ),
      );
      expect(recs.any((r) => r.id == 'mobility_uti_screening'), isTrue);
      expect(
        recs.firstWhere((r) => r.id == 'mobility_uti_screening').priority,
        RecommendationPriority.critical,
      );
    });

    test('severe mental health adds suicide-risk screening', () {
      final recs = engine.getRecommendations(
        profile(
          types: const [DisabilityType.mentalHealth],
          severity: DisabilitySeverity.severe,
        ),
      );
      expect(recs.any((r) => r.id == 'mental_suicide_risk'), isTrue);
    });

    test('caregiver consent required marks a critical alert', () {
      final recs = engine.getRecommendations(
        profile(
          types: const [DisabilityType.cognitive],
          severity: DisabilitySeverity.moderate,
          caregiverConsent: true,
        ),
      );
      final rec =
          recs.firstWhere((r) => r.id == 'cognitive_caregiver_required');
      expect(rec.priority, RecommendationPriority.critical);
      expect(rec.category, RecommendationCategory.caregiverAlert);
    });

    test('recommendations are de-duplicated by id', () {
      final recs = engine.getRecommendations(
        profile(
          types: const [DisabilityType.multiple],
          severity: DisabilitySeverity.severe,
        ),
      );
      final ids = recs.map((r) => r.id).toSet();
      expect(ids.length, recs.length);
    });
  });

  group('PwdRuleEngine.getProviderNotes', () {
    test('returns only provider note and caregiver alert categories', () {
      final notes = engine.getProviderNotes(
        profile(
          types: const [
            DisabilityType.visual,
            DisabilityType.cognitive,
          ],
          severity: DisabilitySeverity.severe,
        ),
      );
      expect(notes, isNotEmpty);
      for (final n in notes) {
        expect(
          n.category == RecommendationCategory.providerNote ||
              n.category == RecommendationCategory.caregiverAlert,
          isTrue,
        );
      }
    });
  });

  group('PwdRuleEngine.getSuggestedReferrals', () {
    test('returns unique referral titles', () {
      final referrals = engine.getSuggestedReferrals(
        profile(
          types: const [DisabilityType.mobility],
          severity: DisabilitySeverity.moderate,
        ),
      );
      expect(referrals, contains('Physiotherapy Referral'));
      final unique = referrals.toSet();
      expect(unique.length, referrals.length);
    });
  });
}
