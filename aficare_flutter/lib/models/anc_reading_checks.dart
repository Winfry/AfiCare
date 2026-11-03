// ================================================================
// AfiCare MediLink — checks on the readings from an antenatal visit
//
// A pregnant woman adds what her clinic measured (or what she measured
// at home). Some readings mean she needs care soon, or straight away,
// even when she feels well. This file decides which, in one place, so
// the visit form, the message after saving, the visit list and the
// reminder at the top of the page always agree.
//
// Thresholds:
//   Blood pressure   140/90 or above is high in pregnancy; 160/110 or
//                    above is severe and needs care the same day
//                    (WHO, and Kenya's maternal guidelines). High blood
//                    pressure with a severe headache, blurred vision,
//                    upper tummy pain, fits, breathlessness or swelling
//                    of the face and hands can mean severe
//                    pre-eclampsia: go now.
//   Hb (g/dL)        below 11 is anaemia in pregnancy; below 7 is severe
//                    (WHO).
//   Baby's heart     110 to 160 a minute is the usual range from mid
//                    pregnancy; checked from 20 weeks, as earlier rates
//                    run higher.
//   Fundal height    from 24 to 40 weeks the bump in cm is usually
//                    within 2 to 3 cm of the number of weeks.
//   Weight           gaining 1 kg or more a week between visits is
//                    faster than usual; with swelling it can be a sign of
//                    pre-eclampsia.
// ================================================================

import 'anc_visit_model.dart';

enum AncLevel {
  /// Worth asking the clinic about.
  ask,

  /// Get checked soon: within a day or two, or today when stated.
  soon,

  /// Get care today, or now.
  urgent,
}

/// One thing a visit's readings call for.
class AncAlert {
  const AncAlert({
    required this.key,
    required this.level,
    required this.badge,
    required this.title,
    required this.body,
    required this.later,
  });

  /// Stable name, e.g. 'bp_severe'.
  final String key;
  final AncLevel level;

  /// Short label for the visit list: "Very high BP".
  final String badge;

  final String title;

  /// What it means and what to do, right after the reading is entered.
  final String body;

  /// What to do when seeing it again later, at the top of the page:
  /// the reading may be days old and may already have been acted on.
  final String later;

  /// Whether to offer a call to 999 / 112 beside it.
  bool get offerEmergencyCall => level == AncLevel.urgent;
}

class AncReadingChecks {
  AncReadingChecks._();

  static const bpHighSystolic = 140;
  static const bpHighDiastolic = 90;
  static const bpSevereSystolic = 160;
  static const bpSevereDiastolic = 110;
  static const hbLow = 11.0;
  static const hbSevere = 7.0;
  static const fhrLow = 110;
  static const fhrHigh = 160;
  static const fhrFarLow = 100;
  static const fhrFarHigh = 180;
  static const fhrFromWeeks = 20;
  static const fundalFromWeeks = 24;
  static const fundalToWeeks = 40;
  static const fundalGapCm = 3.0;
  static const fastGainKgPerWeek = 1.0;

  /// Danger signs that, with high blood pressure, can mean severe
  /// pre-eclampsia.
  static const preEclampsiaSigns = [
    'Severe headache',
    'Blurred vision',
    'Severe abdominal pain',
    'Swelling of face/hands',
    'Convulsions/seizures',
    'Difficulty breathing',
  ];

  static const _bpSigns =
      'a severe headache, blurred vision, pain high in your tummy or under your ribs, fits, or trouble breathing';

  /// Everything a visit's readings call for, most urgent first.
  ///
  /// [weeks] is how far along she was at the visit. [previous] is her
  /// visit before this one in the same pregnancy, if any (for weight).
  static List<AncAlert> check({
    required int weeks,
    int? systolic,
    int? diastolic,
    double? hb,
    int? babyHeartRate,
    double? fundalHeight,
    double? weight,
    DateTime? date,
    AncVisit? previous,
    List<String> dangerSigns = const [],
  }) {
    final alerts = <AncAlert>[
      ..._bloodPressure(systolic, diastolic, weeks, dangerSigns),
      if (_hb(hb) case final a?) a,
      if (_babyHeart(babyHeartRate, weeks) case final a?) a,
      if (_fundal(fundalHeight, weeks) case final a?) a,
      if (_weight(weight, date, previous, dangerSigns) case final a?) a,
      if (_signs(dangerSigns, systolic, diastolic) case final a?) a,
    ];
    return _mostUrgentFirst(alerts, (a) => a.level);
  }

  /// [check] for a saved visit.
  static List<AncAlert> forVisit(AncVisit visit, {AncVisit? previous}) => check(
        weeks: visit.gestationalWeeks,
        systolic: visit.systolicBP,
        diastolic: visit.diastolicBP,
        hb: visit.hemoglobin,
        babyHeartRate: visit.fetalHeartRate,
        fundalHeight: visit.fundalHeight,
        weight: visit.weight,
        date: visit.visitDate,
        previous: previous,
        dangerSigns: visit.dangerSigns,
      );

  /// The visit before [visit] in [visits] (any order), by date.
  static AncVisit? previousOf(AncVisit visit, List<AncVisit> visits) {
    AncVisit? best;
    for (final v in visits) {
      if (identical(v, visit) || (v.id.isNotEmpty && v.id == visit.id)) continue;
      if (!v.visitDate.isBefore(visit.visitDate)) continue;
      if (best == null || v.visitDate.isAfter(best.visitDate)) best = v;
    }
    return best;
  }

  /// What still needs attention across a pregnancy's [visits]: for each
  /// kind of reading, the latest visit that measured it, if that reading
  /// is a worry. A newer, normal reading clears an older worrying one.
  /// Danger signs and weight count only from the latest visit.
  static List<({AncAlert alert, AncVisit visit})> standing(List<AncVisit> visits) {
    if (visits.isEmpty) return const [];
    final newestFirst = [...visits]..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    final out = <({AncAlert alert, AncVisit visit})>[];
    final seenKinds = <String>{};

    void consider(AncVisit v, String kind) {
      if (!seenKinds.add(kind)) return;
      for (final a in forVisit(v, previous: previousOf(v, visits))) {
        if (_kindOf(a.key) == kind) out.add((alert: a, visit: v));
      }
    }

    // In a fixed order, so equally urgent reminders always line up the
    // same way: blood pressure, Hb, baby's heart, bump.
    final measured = <String, bool Function(AncVisit)>{
      'bp': (v) => v.systolicBP != null && v.diastolicBP != null,
      'hb': (v) => v.hemoglobin != null,
      'fhr': (v) => v.fetalHeartRate != null,
      'fundal': (v) => v.fundalHeight != null,
    };
    for (final MapEntry(key: kind, value: has) in measured.entries) {
      for (final v in newestFirst) {
        if (has(v)) {
          consider(v, kind);
          break;
        }
      }
    }
    consider(newestFirst.first, 'weight');
    consider(newestFirst.first, 'signs');

    return _mostUrgentFirst(out, (s) => s.alert.level);
  }

  static String _kindOf(String key) => key.split('_').first;

  /// Most urgent first; equally urgent ones keep their order (blood
  /// pressure, Hb, baby's heart, bump, weight, signs).
  static List<T> _mostUrgentFirst<T>(List<T> items, AncLevel Function(T) level) {
    final indexed = [for (final (i, x) in items.indexed) (i, x)];
    indexed.sort((a, b) {
      final byLevel = level(b.$2).index.compareTo(level(a.$2).index);
      return byLevel != 0 ? byLevel : a.$1.compareTo(b.$1);
    });
    return [for (final (_, x) in indexed) x];
  }

  // ── Blood pressure ──────────────────────────────────────────────

  static List<AncAlert> _bloodPressure(int? sys, int? dia, int weeks, List<String> signs) {
    if (sys == null || dia == null) return const [];
    final reading = '$sys/$dia';
    final severe = sys >= bpSevereSystolic || dia >= bpSevereDiastolic;
    final high = severe || sys >= bpHighSystolic || dia >= bpHighDiastolic;
    if (!high) return const [];

    final withSigns = signs.where(preEclampsiaSigns.contains).toList();
    if (withSigns.isNotEmpty) {
      return [
        AncAlert(
          key: 'bp_with_signs',
          level: AncLevel.urgent,
          badge: severe ? 'Very high BP' : 'High BP',
          title: 'Go to a hospital now',
          body: 'High blood pressure ($reading) together with ${_list(withSigns)} can mean severe '
              'pre-eclampsia, which is an emergency for you and your baby. Go to a hospital now, or call '
              '999 or 112. Do not wait to see if it gets better.',
          later: 'Your blood pressure was $reading with ${_list(withSigns)}. If you have not been seen '
              'for this, go to a hospital now.',
        ),
      ];
    }

    if (severe) {
      return [
        AncAlert(
          key: 'bp_severe',
          level: AncLevel.urgent,
          badge: 'Very high BP',
          title: 'Your blood pressure is dangerously high',
          body: '$reading is dangerously high for pregnancy, even if you feel well. Go to a hospital '
              'today. Go now, or call 999 or 112, if you have $_bpSigns. If your clinic took this '
              'reading and has already treated you, follow the plan they gave you.',
          later: 'Your blood pressure was $reading, which is dangerously high for pregnancy. If you have '
              'not been checked since, get care today.',
        ),
      ];
    }

    return [
      AncAlert(
        key: 'bp_high',
        level: AncLevel.soon,
        badge: 'High BP',
        title: 'Your blood pressure is high for pregnancy',
        body: '$reading is high for pregnancy.'
            '${weeks >= 20 ? ' After 20 weeks it can be an early sign of pre-eclampsia.' : ''} '
            'Have it checked again at a clinic within a day or two. Get care today if you have $_bpSigns, '
            'or if your face or hands swell.',
        later: 'Your blood pressure was $reading, which is high for pregnancy. If it has not been '
            'checked again since, have it checked within a day or two.',
      ),
    ];
  }

  // ── Hb (anaemia) ────────────────────────────────────────────────

  static AncAlert? _hb(double? hb) {
    if (hb == null) return null;
    final value = _num(hb);
    if (hb < hbSevere) {
      return AncAlert(
        key: 'hb_severe',
        level: AncLevel.urgent,
        badge: 'Very low Hb',
        title: 'Your blood level (Hb) is very low',
        body: 'An Hb of $value is severe anaemia. It can make you very tired and breathless, and it makes '
            'bleeding at birth much more dangerous. It needs treatment soon: get care today. Go now, or '
            'call 999 or 112, if you are breathless while resting, have chest pain or feel faint.',
        later: 'Your Hb was $value, which is severe anaemia. If you have not been treated for it yet, '
            'get care today.',
      );
    }
    if (hb < hbLow) {
      return AncAlert(
        key: 'hb_low',
        level: AncLevel.soon,
        badge: 'Low Hb',
        title: 'Your blood level (Hb) is low',
        body: 'An Hb of $value is anaemia, which is common in pregnancy and can be treated, usually with '
            'iron and folic acid tablets. Foods like beans, green vegetables such as managu and sukuma '
            'wiki, liver, meat and omena help too. Talk to your clinic about it soon, and sooner if you '
            'feel very tired, dizzy or short of breath.',
        later: 'Your Hb was $value, which is low. If you have not talked to your clinic about it yet, '
            'do so soon.',
      );
    }
    return null;
  }

  // ── Baby's heart rate ───────────────────────────────────────────

  static AncAlert? _babyHeart(int? rate, int weeks) {
    if (rate == null || weeks < fhrFromWeeks) return null;
    if (rate >= fhrLow && rate <= fhrHigh) return null;
    final far = rate < fhrFarLow || rate > fhrFarHigh;
    final side = rate < fhrLow ? 'slower' : 'faster';
    if (far) {
      return AncAlert(
        key: 'fhr_far',
        level: AncLevel.urgent,
        badge: "Baby's heart rate",
        title: "Your baby's heart rate is far from the usual range",
        body: "$rate a minute is much $side than the usual 110 to 160. If it was not checked again and "
            'found normal at the clinic, go to a hospital today. Go now, or call 999 or 112, if your '
            'baby is moving less than usual.',
        later: "Your baby's heart rate was $rate a minute. If it was not checked again since, get it "
            'checked today.',
      );
    }
    return AncAlert(
      key: 'fhr_outside',
      level: AncLevel.soon,
      badge: "Baby's heart rate",
      title: "Your baby's heart rate is outside the usual range",
      body: "$rate a minute is a little $side than the usual 110 to 160. It is often normal again when "
          'checked a second time, for example after the baby has moved. If your clinic did not check it '
          'again, contact them today. Go to a hospital now if your baby is moving less than usual.',
      later: "Your baby's heart rate was $rate a minute. If it was not checked again since, contact "
          'your clinic.',
    );
  }

  // ── Fundal height ───────────────────────────────────────────────

  static AncAlert? _fundal(double? cm, int weeks) {
    if (cm == null || weeks < fundalFromWeeks || weeks > fundalToWeeks) return null;
    final gap = cm - weeks;
    if (gap.abs() <= fundalGapCm) return null;
    final value = _num(cm);
    final way = gap > 0 ? 'bigger' : 'smaller';
    return AncAlert(
      key: 'fundal_gap',
      level: AncLevel.ask,
      badge: 'Bump size',
      title: 'Your bump measured $way than usual',
      body: 'From 24 weeks, the bump in centimetres is usually close to the number of weeks (about '
          '$weeks cm at $weeks weeks). Yours was $value cm. This is often nothing, such as the baby\'s '
          'position or your dates being a little out, but ask your clinic whether a scan is needed to '
          'check how your baby is growing.',
      later: 'Your bump measured $value cm at $weeks weeks. Ask your clinic whether a scan is needed '
          'to check how your baby is growing.',
    );
  }

  // ── Weight ──────────────────────────────────────────────────────

  static AncAlert? _weight(double? weight, DateTime? date, AncVisit? previous, List<String> signs) {
    final before = previous?.weight;
    if (weight == null || date == null || before == null || previous == null) return null;
    final days = date.difference(previous.visitDate).inDays;
    if (days < 1) return null;
    final gain = weight - before;
    final weeksBetween = days < 7 ? 1.0 : days / 7;
    if (gain / weeksBetween < fastGainKgPerWeek) return null;

    final kg = _num(double.parse(gain.toStringAsFixed(1)));
    final span = days < 7 ? 'less than a week' : days < 14 ? 'about a week' : 'about ${(days / 7).round()} weeks';
    final swelling = signs.contains('Swelling of face/hands');
    if (swelling) {
      return AncAlert(
        key: 'weight_fast',
        level: AncLevel.soon,
        badge: 'Fast weight gain',
        title: 'You gained weight quickly, with swelling',
        body: 'You put on $kg kg in $span, and you noted swelling of your face or hands. Together these '
            'can be a sign of pre-eclampsia. Get your blood pressure and urine checked at a clinic today.',
        later: 'You put on $kg kg in $span, with swelling. If you have not been checked since, get your '
            'blood pressure and urine checked today.',
      );
    }
    return AncAlert(
      key: 'weight_fast',
      level: AncLevel.ask,
      badge: 'Fast weight gain',
      title: 'You gained weight faster than usual',
      body: 'You put on $kg kg in $span. Mention it at your next visit, and get checked sooner if your '
          'face or hands swell.',
      later: 'You put on $kg kg in $span. Mention it at your next visit.',
    );
  }

  // ── Danger signs (on their own) ─────────────────────────────────

  static AncAlert? _signs(List<String> signs, int? sys, int? dia) {
    if (signs.isEmpty) return null;
    // With high blood pressure the signs are already part of the
    // strongest blood pressure warning.
    final bpHigh = sys != null && dia != null && (sys >= bpHighSystolic || dia >= bpHighDiastolic);
    if (bpHigh && signs.any(preEclampsiaSigns.contains)) return null;
    return AncAlert(
      key: 'signs_noted',
      level: AncLevel.urgent,
      badge: 'Danger signs',
      title: 'You noted danger signs',
      body: 'You noted: ${_list(signs)}. If you have not been seen for ${signs.length == 1 ? 'this' : 'these'} '
          'yet, get care today. Go now, or call 999 or 112, if it is severe.',
      later: 'You noted: ${_list(signs)}. If you have not been seen for '
          '${signs.length == 1 ? 'this' : 'these'} yet, get care today.',
    );
  }

  // ────────────────────────────────────────────────────────────────

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// "a, b and c", lower-cased for use mid-sentence.
  static String _list(List<String> items) {
    final words = [for (final i in items) _sentenceCase(i)];
    if (words.length == 1) return words.single;
    return '${words.sublist(0, words.length - 1).join(', ')} and ${words.last}';
  }

  static String _sentenceCase(String sign) => switch (sign) {
        'Severe headache' => 'a severe headache',
        'Severe abdominal pain' => 'severe pain in your tummy',
        'Fever > 38°C' => 'a fever over 38°C',
        'Swelling of face/hands' => 'swelling of the face or hands',
        'Convulsions/seizures' => 'fits',
        'Feeling faint/unconscious' => 'feeling faint',
        'Foul-smelling vaginal discharge' => 'foul-smelling vaginal discharge',
        'Reduced fetal movement' => 'your baby moving less',
        _ => sign.toLowerCase(),
      };
}
