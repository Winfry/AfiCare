/// Reads the "how often" text a doctor writes on a prescription.
///
/// Doctors write it many ways: "Twice daily", "BD", "1 tab TDS",
/// "every 8 hours", "q6h", "PRN", "nocte". This turns any of them into
/// a number of doses a day, and the clock times those doses fall at.
class DoseFrequency {
  DoseFrequency._();

  /// The most doses a day we schedule (every 4 hours).
  static const maxPerDay = 6;

  /// Doses a day for [text]: 0 when it is not a fixed daily dose
  /// ("as needed", "stat", "weekly", "every other day"), so no daily
  /// doses get ticked off for it. Text we can't read counts as once a
  /// day, as before.
  static int perDay(String? text) {
    final f = ' ${(text ?? '').toLowerCase().replaceAll(RegExp(r'[.,;:/()\-]'), ' ')} '
        .replaceAll(RegExp(r'\s+'), ' ');
    bool has(String pattern) => RegExp(pattern).hasMatch(f);

    // Not every day.
    if (has(r' (prn|sos|stat|when (needed|required)|as (needed|required)|if needed) ')) return 0;
    if (has(r'(week|month|fortnight|alternate|other day|every \d+ days|eod )')) return 0;

    // "every 8 hours", "8 hourly", "q8h", "every 8 hrs"; for a range
    // like "every 4-6 hours" the longer gap counts.
    final hours = RegExp(r'(?:every (\d+)(?: (?:to |or )?(\d+))? ?(?:hours?|hrs?|h)\b|(\d+) ?hourly|q ?(\d+) ?h\b)')
        .firstMatch(f);
    if (hours != null) {
      final n = int.parse(hours.group(2) ?? hours.group(1) ?? hours.group(3) ?? hours.group(4)!);
      if (n > 24) return 0;
      if (n >= 1) return (24 / n).floor().clamp(1, maxPerDay);
    }

    // Latin / medical shorthand.
    if (has(r' (qds|qid|q i d|q d s) ')) return 4;
    if (has(r' (tds|tid|t i d|t d s) ')) return 3;
    if (has(r' (bd|bid|b i d|b d) ')) return 2;
    if (has(r' morning ') && has(r' (evening|night|bedtime) ')) return 2;
    if (has(r' (od|qd|o d|mane|nocte|hs|daily at night|at night|at bedtime|in the morning) ')) return 1;

    // Words: "twice daily", "three times a day", "x3 daily".
    const words = {'once': 1, 'one': 1, 'twice': 2, 'two': 2, 'three': 3, 'thrice': 3, 'four': 4, 'five': 5, 'six': 6};
    for (final e in words.entries) {
      if (e.key == 'once' || e.key == 'twice' || e.key == 'thrice') {
        if (has(' ${e.key} ')) return e.value;
      } else if (has(' ${e.key} times? ')) {
        return e.value;
      }
    }
    final times = RegExp(r'(?:(\d+) ?(?:x|times?)\b|\bx ?(\d+)\b)').firstMatch(f);
    if (times != null) {
      final n = int.parse(times.group(1) ?? times.group(2)!);
      if (n >= 1) return n.clamp(1, maxPerDay);
    }

    return 1;
  }

  /// Clock hours for [perDay] doses, spread over the day.
  static List<int> hours(int perDay) {
    switch (perDay) {
      case <= 0:
        return const [];
      case 1:
        return const [8];
      case 2:
        return const [8, 20];
      case 3:
        return const [8, 14, 20];
      case 4:
        return const [7, 12, 17, 22];
      case 5:
        return const [6, 10, 14, 18, 22];
      default:
        return const [6, 10, 14, 18, 22, 2];
    }
  }

  /// Plain words for the patient: "TDS" → "TDS (3 times a day)".
  /// Text already in plain words is left alone.
  static String explain(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return t;
    final n = perDay(t);
    final plain = switch (n) {
      0 => null,
      1 => 'once a day',
      2 => 'twice a day',
      _ => '$n times a day',
    };
    final lower = t.toLowerCase();
    final alreadyPlain = RegExp(r'(once|twice|thrice|times|daily|a day|per day|needed|required)').hasMatch(lower);
    if (plain == null) {
      return RegExp(r'\b(prn|sos)\b').hasMatch(lower) && !alreadyPlain ? '$t (when needed)' : t;
    }
    return alreadyPlain ? t : '$t ($plain)';
  }
}
