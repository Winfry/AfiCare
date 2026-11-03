// ================================================================
// AfiCare MediLink — how each reading from a visit compares with the
// usual range, in words a patient can read.
//
// This replaced a "health score": the share of one visit's readings
// that were in range, shown as "Excellent" from 80 up. An oxygen level
// of 85% beside four normal readings scored 80, "Excellent". Readings
// from one visit say nothing about overall health, so nothing here adds
// them up into a grade: each reading is described on its own, and the
// most serious one leads.
//
// Ranges are for adults, at rest:
//   Temperature   36.1-37.2 °C usual; up to 38 a low fever; above 38 a
//                 fever; below 35 dangerously low
//   Blood pressure below 130/85 usual; 130-139 or 85-89 raised; 140/90
//                 or above high; 180/120 or above very high (ESH/ISH
//                 2020, and Kenya's hypertension guidelines use 140/90)
//   Heart rate    60-100 a minute usual; above 120 very high
//   Oxygen        95% and above usual; 90-94 low; below 90 very low
//   BMI           18.5-24.9 usual
// ================================================================

import 'consultation_model.dart';

enum ReadingLevel {
  usual,

  /// Below the usual range, but not a worry on its own.
  low,

  /// Worth mentioning to a clinician.
  watch,

  /// Needs attention.
  high,
}

class VitalReading {
  const VitalReading({required this.name, required this.value, required this.status, required this.level});

  final String name;
  final String value;

  /// "Normal", "Raised", "Fever"…
  final String status;
  final ReadingLevel level;

  bool get isUsual => level == ReadingLevel.usual;
}

class VitalReadings {
  VitalReadings._();

  /// Each reading [v] holds, in a fixed order.
  static List<VitalReading> of(VitalSigns v) {
    final bmi = bmiOf(v);
    return [
      if (v.temperature != null)
        _reading('Temperature', '${v.temperature!.toStringAsFixed(1)} °C', temperature(v.temperature!)),
      if (v.systolicBP != null && v.diastolicBP != null)
        _reading('Blood pressure', '${v.systolicBP}/${v.diastolicBP} mmHg', bloodPressure(v.systolicBP!, v.diastolicBP!)),
      if (v.pulseRate != null) _reading('Heart rate', '${v.pulseRate} a minute', heartRate(v.pulseRate!)),
      if (v.oxygenSaturation != null)
        _reading('Oxygen (SpO₂)', '${_num(v.oxygenSaturation!)}%', oxygen(v.oxygenSaturation!)),
      if (bmi != null) _reading('BMI', bmi.toStringAsFixed(1), bmiStatus(bmi)),
    ];
  }

  static VitalReading _reading(String name, String value, (String, ReadingLevel) s) =>
      VitalReading(name: name, value: value, status: s.$1, level: s.$2);

  /// The readings outside the usual range, most serious first.
  static List<VitalReading> unusual(VitalSigns v) {
    final out = of(v).where((r) => !r.isUsual).toList();
    final order = [ReadingLevel.high, ReadingLevel.watch, ReadingLevel.low];
    return [for (final l in order) ...out.where((r) => r.level == l)];
  }

  static (String, ReadingLevel) temperature(double t) {
    if (t < 35) return ('Very low', ReadingLevel.high);
    if (t < 36.1) return ('Low', ReadingLevel.low);
    if (t <= 37.2) return ('Normal', ReadingLevel.usual);
    if (t <= 38.0) return ('Low fever', ReadingLevel.watch);
    return ('Fever', ReadingLevel.high);
  }

  static (String, ReadingLevel) bloodPressure(int sys, int dia) {
    if (sys >= 180 || dia >= 120) return ('Very high', ReadingLevel.high);
    if (sys >= 140 || dia >= 90) return ('High', ReadingLevel.high);
    if (sys >= 130 || dia >= 85) return ('Raised', ReadingLevel.watch);
    if (sys < 90 || dia < 60) return ('Low', ReadingLevel.low);
    return ('Normal', ReadingLevel.usual);
  }

  static (String, ReadingLevel) heartRate(int hr) {
    if (hr > 120) return ('Very high', ReadingLevel.high);
    if (hr > 100) return ('High', ReadingLevel.watch);
    if (hr < 60) return ('Low', ReadingLevel.low);
    return ('Normal', ReadingLevel.usual);
  }

  static (String, ReadingLevel) oxygen(double s) {
    if (s < 90) return ('Very low', ReadingLevel.high);
    if (s < 95) return ('Low', ReadingLevel.watch);
    return ('Normal', ReadingLevel.usual);
  }

  static (String, ReadingLevel) bmiStatus(double bmi) {
    if (bmi < 18.5) return ('Underweight', ReadingLevel.low);
    if (bmi < 25) return ('Normal', ReadingLevel.usual);
    if (bmi < 30) return ('Overweight', ReadingLevel.watch);
    return ('Obese', ReadingLevel.watch);
  }

  /// Weight (kg) over height squared. Height may be stored in metres or
  /// centimetres; anything over 3 is taken as centimetres.
  static double? bmiOf(VitalSigns v) {
    final w = v.weight;
    var h = v.height;
    if (w == null || h == null || h <= 0) return null;
    if (h > 3) h = h / 100;
    return w / (h * h);
  }

  /// "3 days ago", "2 months ago", "over a year ago"; null for today.
  static String? howLongAgo(DateTime when, DateTime now) {
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    if (days <= 0) return null;
    if (days == 1) return 'yesterday';
    if (days < 14) return '$days days ago';
    if (days < 60) return '${days ~/ 7} weeks ago';
    if (days < 365) return '${days ~/ 30} months ago';
    return days < 730 ? 'over a year ago' : 'over ${days ~/ 365} years ago';
  }

  /// Readings this old are flagged as possibly out of date.
  static const staleAfterDays = 180;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
