/// How long a course of medicine runs.
///
/// Doctors write it many ways: "5 days", "x7 days", "2 weeks", "1 month",
/// and the shorthand "5/7" (5 days), "2/52" (2 weeks), "3/12" (3 months).
/// "Ongoing", "continue", "lifelong" or text we can't read means it runs
/// until someone stops it.
class MedicineCourse {
  MedicineCourse._();

  /// Days in a course written as [text], or null when it has no end.
  static int? daysIn(String? text) {
    final f = (text ?? '').toLowerCase().trim();
    if (f.isEmpty) return null;
    if (RegExp(r'(ongoing|continu|lifelong|life long|indefinite|long[ -]?term|until)').hasMatch(f)) {
      return null;
    }

    // Shorthand: 5/7 = days, 2/52 = weeks, 3/12 = months.
    final slash = RegExp(r'(\d+)\s*/\s*(7|52|12)\b').firstMatch(f);
    if (slash != null) {
      final n = int.parse(slash.group(1)!);
      return switch (slash.group(2)) {
        '7' => n,
        '52' => n * 7,
        _ => n * 30,
      };
    }

    final unit = RegExp(r'(\d+)\s*(?:x\s*)?(days?|d\b|weeks?|wks?|w\b|months?|mo\b)').firstMatch(f) ??
        RegExp(r'x\s*(\d+)\s*(days?|weeks?|months?)').firstMatch(f);
    if (unit != null) {
      final n = int.parse(unit.group(1)!);
      final u = unit.group(2)!;
      if (u.startsWith('w')) return n * 7;
      if (u.startsWith('m')) return n * 30;
      return n;
    }
    return null;
  }

  /// The last day (a date, no time) a course started on [start] has doses,
  /// from its written [duration] or its [expiresAt], whichever comes first.
  /// Null when it has no end.
  static DateTime? lastDay({required DateTime start, String? duration, DateTime? expiresAt}) {
    final days = daysIn(duration);
    final s = _date(start.toLocal());
    final byDuration = days == null || days < 1 ? null : s.add(Duration(days: days - 1));
    final byExpiry = expiresAt == null ? null : _date(expiresAt.toLocal());
    if (byDuration == null) return byExpiry;
    if (byExpiry == null) return byDuration;
    return byDuration.isBefore(byExpiry) ? byDuration : byExpiry;
  }

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
}
