import 'package:aficare_flutter/screens/patient/qr_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScannedCode.parse', () {
    test('recognises the patient\'s own MediLink ID, ignoring case and spaces', () {
      final code = ScannedCode.parse('  ml-nbo-1234 ', ownMedilinkId: 'ML-NBO-1234');
      expect(code.kind, ScannedKind.ownMedilinkId);
      expect(code.value, 'ML-NBO-1234');
    });

    test('recognises someone else\'s MediLink ID, including a dependant\'s', () {
      expect(ScannedCode.parse('ML-NBO-9999', ownMedilinkId: 'ML-NBO-1234').kind, ScannedKind.medilinkId);
      expect(ScannedCode.parse('ML-DEP-A1B2C3').kind, ScannedKind.medilinkId);
    });

    test('recognises a record-sharing link and pulls out its code', () {
      final code = ScannedCode.parse('https://api.aficare.example/v/K7PQ2M');
      expect(code.kind, ScannedKind.shareLink);
      expect(code.value, 'K7PQ2M');
    });

    test('anything else is not an AfiCare code', () {
      for (final raw in [
        'AFICARE:PROVIDER:PRV-NBO-1234', // the old fake format: nothing makes these
        'https://example.com/menu',
        'ML-',
        'hello',
      ]) {
        expect(ScannedCode.parse(raw).kind, ScannedKind.other, reason: raw);
      }
    });
  });
}
