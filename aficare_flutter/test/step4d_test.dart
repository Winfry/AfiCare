import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/utils/medicine_course.dart';

/// Step 4d: weak spots — figures that flattered, failures that looked empty.
void main() {
  group('how long a course runs', () {
    test('the ways doctors write it', () {
      expect(MedicineCourse.daysIn('5 days'), 5);
      expect(MedicineCourse.daysIn('x7 days'), 7);
      expect(MedicineCourse.daysIn('5/7'), 5);
      expect(MedicineCourse.daysIn('2/52'), 14);
      expect(MedicineCourse.daysIn('3/12'), 90);
      expect(MedicineCourse.daysIn('2 weeks'), 14);
      expect(MedicineCourse.daysIn('1 month'), 30);
      expect(MedicineCourse.daysIn('10d'), 10);
    });

    test('no end: ongoing, lifelong, blank or unreadable', () {
      for (final t in ['ongoing', 'Continue', 'lifelong', '', null, 'as directed']) {
        expect(MedicineCourse.daysIn(t), isNull, reason: '$t');
      }
    });

    test('the last day is the earlier of the written length and the expiry', () {
      final start = DateTime(2026, 11, 1, 15);
      expect(MedicineCourse.lastDay(start: start, duration: '5/7'), DateTime(2026, 11, 5));
      expect(
        MedicineCourse.lastDay(start: start, duration: '30 days', expiresAt: DateTime(2026, 11, 3, 10)),
        DateTime(2026, 11, 3),
      );
      expect(MedicineCourse.lastDay(start: start, duration: 'ongoing'), isNull);
    });
  });
}
