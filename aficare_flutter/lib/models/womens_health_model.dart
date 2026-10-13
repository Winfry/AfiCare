/// A patient's women's-health record: where she is in life (pregnant,
/// trying, …), her cycle, and her cervical and breast screening dates.
///
/// Stored in `users.metadata['maternal_health']`, the same place the old
/// full dashboard saved it, so anything recorded there carries over. Keys
/// this model does not know about are kept and written back untouched.
class WomensHealthRecord {
  const WomensHealthRecord({
    this.lifeStage = 'not_pregnant',
    this.checklist = const {},
    this.periodPain,
    this.cycleLength = defaultCycleLength,
    this.periodLength = defaultPeriodLength,
    this.lastPeriodStart,
    this.savedNextPeriod,
    this.lastCervicalScreening,
    this.lastMammogram,
    this.extra = const {},
  });

  static const defaultCycleLength = 28;
  static const defaultPeriodLength = 5;

  /// Accepted when editing; anything outside is almost certainly a typo.
  static const minCycleLength = 15;
  static const maxCycleLength = 60;
  static const minPeriodLength = 1;
  static const maxPeriodLength = 14;

  /// The usual adult range. Outside it is worth mentioning to a doctor.
  static const typicalCycleMin = 21;
  static const typicalCycleMax = 35;

  /// One of [lifeStages]' keys.
  final String lifeStage;

  /// Preconception checklist, keyed by [preconceptionItems]' keys.
  final Map<String, bool> checklist;

  /// Usual period pain, 1 (barely) to 10 (worst imaginable). Null when the
  /// patient has never said.
  final int? periodPain;

  final int cycleLength;
  final int periodLength;

  /// First day of the most recent period, when logged on the new page.
  final DateTime? lastPeriodStart;

  /// A next-period date typed straight in on the old dashboard. Only used
  /// when there is no [lastPeriodStart] to predict from.
  final DateTime? savedNextPeriod;

  final DateTime? lastCervicalScreening;
  final DateTime? lastMammogram;

  /// Keys from the stored map this model does not manage.
  final Map<String, dynamic> extra;

  static const lifeStages = <String, String>{
    'not_pregnant': 'Not pregnant',
    'trying': 'Trying to conceive',
    'pregnant': 'Pregnant',
    'postpartum': 'Recently had a baby',
    'breastfeeding': 'Breastfeeding',
  };

  /// Getting ready for pregnancy. Keys match the old dashboard's.
  static const preconceptionItems = <String, (String, String)>{
    'folic_acid': ('Taking folic acid every day', '400 micrograms, ideally from a month before trying'),
    'healthy_weight': ('Working towards a healthy weight', 'Your clinic can check your BMI with you'),
    'exercise': ('Moving most days', 'Walking counts: about 30 minutes a day'),
    'nutrition': ('Eating a varied diet', 'Iron-rich foods like beans, greens and liver help'),
    'no_smoking': ('No smoking or alcohol', 'Both affect fertility and an early pregnancy'),
    'vaccinations': ('Vaccinations up to date', 'Ask about tetanus and rubella before pregnancy'),
  };

  static const _knownKeys = {
    'pregnancy_status',
    'checklist',
    'menstrual_pain',
    'cycle_length',
    'period_duration',
    'last_period_start',
    'next_period',
    'last_pap_smear',
    'last_mammogram',
  };

  factory WomensHealthRecord.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final stage = j['pregnancy_status'] as String?;
    final rawChecklist = j['checklist'];
    final pain = (j['menstrual_pain'] as num?)?.round();
    return WomensHealthRecord(
      lifeStage: lifeStages.containsKey(stage) ? stage! : 'not_pregnant',
      checklist: {
        if (rawChecklist is Map)
          for (final e in rawChecklist.entries)
            if (e.value is bool) e.key.toString(): e.value as bool,
      },
      periodPain: pain?.clamp(1, 10),
      cycleLength: _intIn(j['cycle_length'], minCycleLength, maxCycleLength) ?? defaultCycleLength,
      periodLength: _intIn(j['period_duration'], minPeriodLength, maxPeriodLength) ?? defaultPeriodLength,
      lastPeriodStart: _date(j['last_period_start']),
      savedNextPeriod: _date(j['next_period']),
      lastCervicalScreening: _date(j['last_pap_smear']),
      lastMammogram: _date(j['last_mammogram']),
      extra: {
        for (final e in j.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() {
    final next = expectedNextPeriod(DateTime.now());
    return {
      ...extra,
      'pregnancy_status': lifeStage,
      'checklist': Map<String, bool>.from(checklist),
      'menstrual_pain': periodPain,
      'cycle_length': cycleLength,
      'period_duration': periodLength,
      'last_period_start': _dateOnly(lastPeriodStart),
      // Kept up to date for anything still reading the old field.
      'next_period': _dateOnly(next),
      'last_pap_smear': _dateOnly(lastCervicalScreening),
      'last_mammogram': _dateOnly(lastMammogram),
    };
  }

  WomensHealthRecord copyWith({
    String? lifeStage,
    Map<String, bool>? checklist,
    int? periodPain,
    int? cycleLength,
    int? periodLength,
    DateTime? lastPeriodStart,
    DateTime? lastCervicalScreening,
    DateTime? lastMammogram,
    bool clearCervicalScreening = false,
    bool clearMammogram = false,
  }) {
    return WomensHealthRecord(
      lifeStage: lifeStage ?? this.lifeStage,
      checklist: checklist ?? this.checklist,
      periodPain: periodPain ?? this.periodPain,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      // A newly logged period replaces any hand-typed prediction.
      savedNextPeriod: lastPeriodStart != null ? null : savedNextPeriod,
      lastCervicalScreening: clearCervicalScreening ? null : (lastCervicalScreening ?? this.lastCervicalScreening),
      lastMammogram: clearMammogram ? null : (lastMammogram ?? this.lastMammogram),
      extra: extra,
    );
  }

  // ── Cycle ────────────────────────────────────────────────────────────

  /// When the next period is expected: one cycle after the last logged
  /// start, or the date saved on the old dashboard. Null when neither.
  DateTime? expectedNextPeriod(DateTime today) {
    if (lastPeriodStart != null) {
      final s = _day(lastPeriodStart!);
      return DateTime(s.year, s.month, s.day + cycleLength);
    }
    return savedNextPeriod == null ? null : _day(savedNextPeriod!);
  }

  /// Days from [today] to the expected next period: negative when late.
  int? daysUntilNextPeriod(DateTime today) {
    final next = expectedNextPeriod(today);
    if (next == null) return null;
    return _daysBetween(_day(today), next);
  }

  /// True when the period is currently expected to be happening: within
  /// [periodLength] days of the last logged start.
  bool onPeriod(DateTime today) {
    if (lastPeriodStart == null) return false;
    final d = _daysBetween(_day(lastPeriodStart!), _day(today));
    return d >= 0 && d < periodLength;
  }

  bool get cycleOutsideTypicalRange => cycleLength < typicalCycleMin || cycleLength > typicalCycleMax;

  int get preconceptionDone =>
      preconceptionItems.keys.where((k) => checklist[k] ?? false).length;

  // ── Screenings ───────────────────────────────────────────────────────

  ScreeningStatus cervicalStatus(DateTime today, {int? age}) =>
      ScreeningStatus.evaluate(Screening.cervical, lastCervicalScreening, today, age: age);

  ScreeningStatus breastStatus(DateTime today, {int? age}) =>
      ScreeningStatus.evaluate(Screening.breast, lastMammogram, today, age: age);

  // ── helpers ──────────────────────────────────────────────────────────

  static int? _intIn(Object? v, int min, int max) {
    final n = (v as num?)?.round();
    if (n == null || n < min || n > max) return null;
    return n;
  }

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static String? _dateOnly(DateTime? d) => d?.toIso8601String().split('T').first;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  // Via UTC so a daylight-saving change can never make it off by one.
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// The two routine screenings, with the usual schedule.
enum Screening {
  /// Pap smear or VIA, every 3 years from 25.
  cervical(intervalMonths: 36, startAge: 25),

  /// Mammogram, every 2 years from 40.
  breast(intervalMonths: 24, startAge: 40);

  const Screening({required this.intervalMonths, required this.startAge});

  final int intervalMonths;
  final int startAge;
}

enum ScreeningState {
  /// Under the usual starting age, with nothing recorded.
  notYet,
  notRecorded,
  upToDate,

  /// Due within the next three months.
  dueSoon,
  overdue,
}

class ScreeningStatus {
  const ScreeningStatus(this.state, {this.dueDate});

  final ScreeningState state;

  /// When the next one is due. Null when nothing is recorded.
  final DateTime? dueDate;

  static ScreeningStatus evaluate(Screening s, DateTime? last, DateTime today, {int? age}) {
    if (last == null) {
      final tooYoung = age != null && age < s.startAge;
      return ScreeningStatus(tooYoung ? ScreeningState.notYet : ScreeningState.notRecorded);
    }
    final due = addMonths(last, s.intervalMonths);
    final t = DateTime(today.year, today.month, today.day);
    if (!due.isAfter(t)) return ScreeningStatus(ScreeningState.overdue, dueDate: due);
    if (!due.isAfter(addMonths(t, 3))) return ScreeningStatus(ScreeningState.dueSoon, dueDate: due);
    return ScreeningStatus(ScreeningState.upToDate, dueDate: due);
  }

  /// Calendar months, keeping the day where it exists (31 Jan + 1 month
  /// is 28/29 Feb, not 3 March).
  static DateTime addMonths(DateTime d, int months) {
    final m = d.month - 1 + months;
    final year = d.year + (m >= 0 ? m ~/ 12 : (m - 11) ~/ 12);
    final month = m % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
  }
}
