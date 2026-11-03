import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/consultation_model.dart';
import 'package:aficare_flutter/models/vital_readings.dart';

void main() {
  group('each reading on its own', () {
    test('temperature', () {
      expect(VitalReadings.temperature(34.5), ('Very low', ReadingLevel.high));
      expect(VitalReadings.temperature(35.8), ('Low', ReadingLevel.low));
      expect(VitalReadings.temperature(36.1).$2, ReadingLevel.usual);
      expect(VitalReadings.temperature(37.2).$2, ReadingLevel.usual);
      expect(VitalReadings.temperature(37.8), ('Low fever', ReadingLevel.watch));
      expect(VitalReadings.temperature(39.5), ('Fever', ReadingLevel.high));
    });

    test('blood pressure, either number counts', () {
      expect(VitalReadings.bloodPressure(118, 76), ('Normal', ReadingLevel.usual));
      expect(VitalReadings.bloodPressure(129, 84).$2, ReadingLevel.usual);
      expect(VitalReadings.bloodPressure(130, 70), ('Raised', ReadingLevel.watch));
      expect(VitalReadings.bloodPressure(120, 85), ('Raised', ReadingLevel.watch));
      expect(VitalReadings.bloodPressure(140, 80), ('High', ReadingLevel.high));
      expect(VitalReadings.bloodPressure(125, 95), ('High', ReadingLevel.high), reason: 'was "Elevated" before');
      expect(VitalReadings.bloodPressure(185, 100), ('Very high', ReadingLevel.high));
      expect(VitalReadings.bloodPressure(150, 120), ('Very high', ReadingLevel.high));
      expect(VitalReadings.bloodPressure(85, 55), ('Low', ReadingLevel.low));
    });

    test('heart rate', () {
      expect(VitalReadings.heartRate(55), ('Low', ReadingLevel.low));
      expect(VitalReadings.heartRate(60).$2, ReadingLevel.usual);
      expect(VitalReadings.heartRate(100).$2, ReadingLevel.usual);
      expect(VitalReadings.heartRate(110), ('High', ReadingLevel.watch));
      expect(VitalReadings.heartRate(130), ('Very high', ReadingLevel.high));
    });

    test('oxygen', () {
      expect(VitalReadings.oxygen(98).$2, ReadingLevel.usual);
      expect(VitalReadings.oxygen(95).$2, ReadingLevel.usual);
      expect(VitalReadings.oxygen(93), ('Low', ReadingLevel.watch));
      expect(VitalReadings.oxygen(85), ('Very low', ReadingLevel.high));
    });

    test('BMI, with height in metres or centimetres', () {
      expect(VitalReadings.bmiOf(VitalSigns(weight: 70, height: 1.75))!.toStringAsFixed(1), '22.9');
      expect(VitalReadings.bmiOf(VitalSigns(weight: 70, height: 175))!.toStringAsFixed(1), '22.9');
      expect(VitalReadings.bmiOf(VitalSigns(weight: 70)), isNull);
      expect(VitalReadings.bmiStatus(17).$2, ReadingLevel.low);
      expect(VitalReadings.bmiStatus(22).$2, ReadingLevel.usual);
      expect(VitalReadings.bmiStatus(27).$2, ReadingLevel.watch);
    });
  });

  test('a dangerous reading is never hidden among normal ones', () {
    // The old score: four of five in range = 80 = "Excellent".
    final v = VitalSigns(temperature: 36.8, systolicBP: 118, diastolicBP: 76, pulseRate: 80, oxygenSaturation: 85);
    final unusual = VitalReadings.unusual(v);
    expect(unusual.single.name, 'Oxygen (SpO₂)');
    expect(unusual.single.status, 'Very low');
    expect(unusual.single.level, ReadingLevel.high);
  });

  test('unusual readings come most serious first', () {
    final v = VitalSigns(temperature: 35.5, systolicBP: 132, diastolicBP: 80, oxygenSaturation: 88);
    expect(VitalReadings.unusual(v).map((r) => r.name), ['Oxygen (SpO₂)', 'Blood pressure', 'Temperature']);
  });

  test('only readings that were taken are listed', () {
    expect(VitalReadings.of(VitalSigns()), isEmpty);
    expect(VitalReadings.of(VitalSigns(systolicBP: 120)), isEmpty, reason: 'half a blood pressure is not a reading');
    expect(VitalReadings.of(VitalSigns(pulseRate: 72)).single.value, '72 a minute');
  });

  test('how long ago', () {
    final now = DateTime(2026, 11, 3, 15);
    expect(VitalReadings.howLongAgo(DateTime(2026, 11, 3, 9), now), isNull);
    expect(VitalReadings.howLongAgo(DateTime(2026, 11, 2), now), 'yesterday');
    expect(VitalReadings.howLongAgo(DateTime(2026, 10, 27), now), '7 days ago');
    expect(VitalReadings.howLongAgo(DateTime(2026, 10, 1), now), '4 weeks ago');
    expect(VitalReadings.howLongAgo(DateTime(2026, 6, 1), now), '5 months ago');
    expect(VitalReadings.howLongAgo(DateTime(2025, 9, 1), now), 'over a year ago');
    expect(VitalReadings.howLongAgo(DateTime(2023, 9, 1), now), 'over 3 years ago');
  });
}
