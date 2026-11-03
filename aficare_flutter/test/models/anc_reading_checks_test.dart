import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/anc_reading_checks.dart';
import 'package:aficare_flutter/models/anc_visit_model.dart';

List<String> keys({
  int weeks = 30,
  int? sys,
  int? dia,
  double? hb,
  int? fhr,
  double? fundal,
  double? weight,
  DateTime? date,
  AncVisit? previous,
  List<String> signs = const [],
}) =>
    AncReadingChecks.check(
      weeks: weeks,
      systolic: sys,
      diastolic: dia,
      hb: hb,
      babyHeartRate: fhr,
      fundalHeight: fundal,
      weight: weight,
      date: date,
      previous: previous,
      dangerSigns: signs,
    ).map((a) => a.key).toList();

AncVisit visit(
  String id,
  DateTime date, {
  int weeks = 30,
  int? sys,
  int? dia,
  double? hb,
  int? fhr,
  double? fundal,
  double? weight,
  List<String> signs = const [],
}) =>
    AncVisit(
      id: id,
      patientId: 'u1',
      pregnancyId: 'p1',
      visitNumber: 1,
      gestationalWeeks: weeks,
      trimester: 'third',
      visitDate: date,
      systolicBP: sys,
      diastolicBP: dia,
      hemoglobin: hb,
      fetalHeartRate: fhr,
      fundalHeight: fundal,
      weight: weight,
      dangerSigns: signs,
    );

void main() {
  group('blood pressure', () {
    test('normal says nothing; 140/90 is high; 160/110 is an emergency', () {
      expect(keys(sys: 139, dia: 89), isEmpty);
      expect(keys(sys: 140, dia: 80), ['bp_high']);
      expect(keys(sys: 120, dia: 90), ['bp_high'], reason: 'the bottom number alone counts');
      expect(keys(sys: 159, dia: 109), ['bp_high']);
      expect(keys(sys: 160, dia: 80), ['bp_severe']);
      expect(keys(sys: 120, dia: 110), ['bp_severe'], reason: 'the bottom number alone counts');
      expect(keys(sys: 200, dia: 130), ['bp_severe']);
    });

    test('only one number says nothing', () {
      expect(keys(sys: 170), isEmpty);
      expect(keys(dia: 115), isEmpty);
    });

    test('Akinyi, 160/110, feeling fine: go to a hospital today, with a call button', () {
      final a = AncReadingChecks.check(weeks: 32, systolic: 160, diastolic: 110).single;
      expect(a.level, AncLevel.urgent);
      expect(a.offerEmergencyCall, isTrue);
      expect(a.badge, 'Very high BP');
      expect(a.body, contains('160/110'));
      expect(a.body, contains('even if you feel well'));
      expect(a.body, contains('Go to a hospital today'));
      expect(a.body, contains('999'));
    });

    test('high blood pressure with a headache or blurred vision: go now', () {
      for (final sign in AncReadingChecks.preEclampsiaSigns) {
        final alerts = AncReadingChecks.check(weeks: 32, systolic: 145, diastolic: 92, dangerSigns: [sign]);
        expect(alerts.map((a) => a.key), ['bp_with_signs'], reason: sign);
        expect(alerts.single.level, AncLevel.urgent);
        expect(alerts.single.title, 'Go to a hospital now');
      }
      final both = AncReadingChecks.check(
          weeks: 32, systolic: 165, diastolic: 112, dangerSigns: ['Severe headache', 'Blurred vision']).single;
      expect(both.body, contains('a severe headache and blurred vision'));
      expect(both.badge, 'Very high BP');
    });

    test('high blood pressure with an unrelated sign keeps both warnings', () {
      expect(keys(sys: 145, dia: 92, signs: ['Fever > 38°C']), ['signs_noted', 'bp_high']);
    });

    test('pre-eclampsia is mentioned only from 20 weeks', () {
      final early = AncReadingChecks.check(weeks: 16, systolic: 145, diastolic: 92).single;
      final later = AncReadingChecks.check(weeks: 24, systolic: 145, diastolic: 92).single;
      expect(early.body, isNot(contains('pre-eclampsia')));
      expect(later.body, contains('pre-eclampsia'));
      expect(later.level, AncLevel.soon);
      expect(later.body, contains('within a day or two'));
    });
  });

  group('Hb', () {
    test('11 and above says nothing; below 11 is low; below 7 is severe', () {
      expect(keys(hb: 11), isEmpty);
      expect(keys(hb: 12.5), isEmpty);
      expect(keys(hb: 10.9), ['hb_low']);
      expect(keys(hb: 7), ['hb_low']);
      expect(keys(hb: 6.9), ['hb_severe']);
    });

    test('severe anaemia is urgent and mentions bleeding at birth', () {
      final a = AncReadingChecks.check(weeks: 30, hb: 6.8).single;
      expect(a.level, AncLevel.urgent);
      expect(a.body, contains('6.8'));
      expect(a.body, contains('bleeding at birth'));
    });

    test('low Hb is explained with treatment and local foods', () {
      final a = AncReadingChecks.check(weeks: 30, hb: 9.5).single;
      expect(a.level, AncLevel.soon);
      expect(a.body, contains('iron'));
      expect(a.body, contains('sukuma wiki'));
    });
  });

  group("baby's heart rate", () {
    test('110 to 160 says nothing', () {
      expect(keys(weeks: 24, fhr: 110), isEmpty);
      expect(keys(weeks: 24, fhr: 140), isEmpty);
      expect(keys(weeks: 24, fhr: 160), isEmpty);
    });

    test('a little outside is "contact your clinic today"; far outside is urgent', () {
      expect(keys(weeks: 24, fhr: 109), ['fhr_outside']);
      expect(keys(weeks: 24, fhr: 100), ['fhr_outside']);
      expect(keys(weeks: 24, fhr: 161), ['fhr_outside']);
      expect(keys(weeks: 24, fhr: 180), ['fhr_outside']);
      expect(keys(weeks: 24, fhr: 99), ['fhr_far']);
      expect(keys(weeks: 24, fhr: 181), ['fhr_far']);
    });

    test('not judged before 20 weeks, when faster rates are normal', () {
      expect(keys(weeks: 12, fhr: 175), isEmpty);
      expect(keys(weeks: 19, fhr: 95), isEmpty);
    });

    test('says which way', () {
      expect(AncReadingChecks.check(weeks: 30, babyHeartRate: 105).single.body, contains('slower'));
      expect(AncReadingChecks.check(weeks: 30, babyHeartRate: 170).single.body, contains('faster'));
    });
  });

  group('fundal height', () {
    test('within 3 cm of the weeks says nothing; further is worth asking about', () {
      expect(keys(weeks: 30, fundal: 27), isEmpty);
      expect(keys(weeks: 30, fundal: 33), isEmpty);
      expect(keys(weeks: 30, fundal: 26.5), ['fundal_gap']);
      expect(keys(weeks: 30, fundal: 34), ['fundal_gap']);
    });

    test('only from 24 to 40 weeks', () {
      expect(keys(weeks: 20, fundal: 14), isEmpty);
      expect(keys(weeks: 41, fundal: 34), isEmpty);
    });

    test('a gentle note, never an emergency', () {
      final a = AncReadingChecks.check(weeks: 30, fundalHeight: 25).single;
      expect(a.level, AncLevel.ask);
      expect(a.offerEmergencyCall, isFalse);
      expect(a.title, contains('smaller'));
      expect(a.body, contains('often nothing'));
    });
  });

  group('weight', () {
    final twoWeeksAgo = DateTime(2026, 10, 20);
    final today = DateTime(2026, 11, 3);
    final before = visit('v1', twoWeeksAgo, weight: 60);

    test('usual gain says nothing; 1 kg a week or more is noted', () {
      expect(keys(weight: 61.8, date: today, previous: before), isEmpty);
      expect(keys(weight: 62, date: today, previous: before), ['weight_fast']);
    });

    test('with swelling it means a check today', () {
      final a = AncReadingChecks.check(
        weeks: 30,
        weight: 63,
        date: today,
        previous: before,
        dangerSigns: ['Swelling of face/hands'],
      ).firstWhere((a) => a.key == 'weight_fast');
      expect(a.level, AncLevel.soon);
      expect(a.body, contains('3 kg in about 2 weeks'));
      expect(a.body, contains('pre-eclampsia'));
    });

    test('without an earlier weight there is nothing to compare', () {
      expect(keys(weight: 80, date: today), isEmpty);
      expect(keys(weight: 80, date: today, previous: visit('v0', twoWeeksAgo)), isEmpty);
    });
  });

  group('danger signs on their own', () {
    test('are urgent, named, and offer a call', () {
      final a = AncReadingChecks.check(weeks: 30, dangerSigns: ['Vaginal bleeding', 'Reduced fetal movement']).single;
      expect(a.key, 'signs_noted');
      expect(a.level, AncLevel.urgent);
      expect(a.body, contains('vaginal bleeding and your baby moving less'));
    });
  });

  test('several worries come most urgent first', () {
    final alerts = AncReadingChecks.check(weeks: 30, systolic: 145, diastolic: 92, hb: 6.5, fundalHeight: 24);
    expect(alerts.map((a) => a.key), ['hb_severe', 'bp_high', 'fundal_gap']);
  });

  test('every urgent alert offers a call and says 999; nothing else does', () {
    final all = [
      ...AncReadingChecks.check(weeks: 30, systolic: 170, diastolic: 115),
      ...AncReadingChecks.check(weeks: 30, systolic: 145, diastolic: 95, dangerSigns: ['Blurred vision']),
      ...AncReadingChecks.check(weeks: 30, hb: 6),
      ...AncReadingChecks.check(weeks: 30, babyHeartRate: 90),
      ...AncReadingChecks.check(weeks: 30, dangerSigns: ['Fever > 38°C']),
      ...AncReadingChecks.check(weeks: 30, systolic: 145, diastolic: 95, hb: 9, fundalHeight: 20, babyHeartRate: 105),
    ];
    for (final a in all) {
      expect(a.offerEmergencyCall, a.level == AncLevel.urgent, reason: a.key);
      expect(a.title, isNotEmpty);
      expect(a.later, isNotEmpty);
    }
    for (final a in all.where((a) => a.level == AncLevel.urgent)) {
      expect(a.body, contains('999'), reason: a.key);
    }
  });

  group('standing (the reminder at the top of the page)', () {
    final oct1 = DateTime(2026, 10, 1);
    final oct15 = DateTime(2026, 10, 15);

    List<String> standing(List<AncVisit> visits) =>
        AncReadingChecks.standing(visits).map((s) => '${s.alert.key}@${s.visit.id}').toList();

    test('a newer normal reading clears an older worrying one', () {
      expect(
        standing([visit('old', oct1, sys: 165, dia: 112), visit('new', oct15, sys: 118, dia: 76)]),
        isEmpty,
      );
    });

    test('a newer visit that did not measure it does not clear it', () {
      expect(
        standing([visit('old', oct1, sys: 165, dia: 112, hb: 9), visit('new', oct15, weight: 70)]),
        ['bp_severe@old', 'hb_low@old'],
      );
    });

    test('each kind of reading is judged on its own latest value', () {
      expect(
        standing([visit('old', oct1, sys: 150, dia: 95, hb: 12), visit('new', oct15, hb: 10)]),
        ['bp_high@old', 'hb_low@new'],
      );
    });

    test('danger signs count only from the latest visit', () {
      expect(standing([visit('old', oct1, signs: ['Severe headache']), visit('new', oct15)]), isEmpty);
      expect(standing([visit('old', oct1), visit('new', oct15, signs: ['Severe headache'])]), ['signs_noted@new']);
    });

    test('later wording allows that it may already have been seen to', () {
      final s = AncReadingChecks.standing([visit('v', oct1, sys: 165, dia: 112)]).single;
      expect(s.alert.later, contains('If you have not been checked since'));
    });

    test('no visits, nothing standing', () => expect(AncReadingChecks.standing(const []), isEmpty));
  });
}
