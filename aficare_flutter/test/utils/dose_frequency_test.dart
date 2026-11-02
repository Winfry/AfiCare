import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/utils/dose_frequency.dart';

void main() {
  group('DoseFrequency.perDay', () {
    const cases = {
      // The doctor's own dropdown
      'Once daily': 1,
      'Twice daily': 2,
      'Three times daily': 3,
      'Four times daily': 4,
      'As needed': 0,
      // What the patient's own "add medicine" saves
      '1 time a day': 1,
      '2 times a day': 2,
      '3 times a day': 3,
      '4 times a day': 4,
      // Shorthand typed in the prescription writer
      'OD': 1,
      'BD': 2,
      'b.d.': 2,
      'BID': 2,
      'TDS': 3,
      'tid': 3,
      't.d.s': 3,
      'QDS': 4,
      'QID': 4,
      '1 tab TDS': 3,
      '2 tabs BD': 2,
      '500mg TDS x 5 days': 3,
      'Nocte': 1,
      'mane': 1,
      'PRN': 0,
      'SOS': 0,
      'stat': 0,
      // Hours between doses
      'every 8 hours': 3,
      'Every 12 hours': 2,
      'every 6 hrs': 4,
      '8 hourly': 3,
      'q8h': 3,
      'Q6H': 4,
      'every 4 hours': 6,
      'every 4-6 hours': 4,
      'every 24 hours': 1,
      'every 48 hours': 0,
      // Words and numbers
      '1 tablet three times a day': 3,
      'Take 2 tablets twice daily': 2,
      '3x daily': 3,
      'x2 daily': 2,
      'once a day': 1,
      'morning and evening': 2,
      'at night': 1,
      // Not every day
      'Once weekly': 0,
      'every other day': 0,
      'alternate days': 0,
      'monthly': 0,
      // Unreadable or empty: once a day, as before
      'daily': 1,
      '': 1,
      'as directed': 1,
    };
    cases.forEach((text, expected) {
      test('"$text" is $expected a day', () => expect(DoseFrequency.perDay(text), expected));
    });

    test('null is once a day', () => expect(DoseFrequency.perDay(null), 1));
  });

  group('DoseFrequency.hours', () {
    test('one clock time per dose, in order, every hour real', () {
      for (var n = 0; n <= DoseFrequency.maxPerDay; n++) {
        final h = DoseFrequency.hours(n);
        expect(h.length, n);
        expect(h.toSet().length, n, reason: 'no two doses at the same time');
        expect(h.every((x) => x >= 0 && x < 24), isTrue);
      }
    });

    test('twice a day is 12 hours apart, three times 6 hours apart', () {
      expect(DoseFrequency.hours(2), [8, 20]);
      expect(DoseFrequency.hours(3), [8, 14, 20]);
    });
  });

  group('DoseFrequency.explain', () {
    test('adds plain words to shorthand', () {
      expect(DoseFrequency.explain('TDS'), 'TDS (3 times a day)');
      expect(DoseFrequency.explain('BD'), 'BD (twice a day)');
      expect(DoseFrequency.explain('OD'), 'OD (once a day)');
      expect(DoseFrequency.explain('every 8 hours'), 'every 8 hours (3 times a day)');
      expect(DoseFrequency.explain('PRN'), 'PRN (when needed)');
    });

    test('leaves plain words alone', () {
      expect(DoseFrequency.explain('Twice daily'), 'Twice daily');
      expect(DoseFrequency.explain('3 times a day'), '3 times a day');
      expect(DoseFrequency.explain('As needed'), 'As needed');
      expect(DoseFrequency.explain('Once weekly'), 'Once weekly');
      expect(DoseFrequency.explain(''), '');
    });
  });
}
