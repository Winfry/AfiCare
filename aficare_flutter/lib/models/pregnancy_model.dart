/// One pregnancy: when it started, when the baby is due, and, once it is
/// over, how it ended. Stored in `pregnancies` (migration 041). A person
/// has at most one ongoing pregnancy; past ones are kept, so a second
/// pregnancy's visits never mix with the first's.
///
/// Dates are calendar days. Pregnancy is counted from the first day of
/// the last period (LMP), as clinics do: the due date is LMP + 280 days
/// (40 weeks). When the due date came from a scan instead, the dating
/// start is worked back from it.
class Pregnancy {
  const Pregnancy({
    required this.id,
    required this.patientId,
    this.lmpDate,
    required this.dueDate,
    this.dueDateSource = 'lmp',
    this.status = 'ongoing',
    this.outcome,
    this.endedOn,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final DateTime? lmpDate;
  final DateTime dueDate;

  /// Where the due date came from: 'lmp', 'scan' or 'clinician'.
  final String dueDateSource;

  /// 'ongoing' or 'ended'.
  final String status;

  /// How it ended (see [outcomes]); null while ongoing.
  final String? outcome;
  final DateTime? endedOn;
  final DateTime? createdAt;

  static const gestationDays = 280;

  /// How a pregnancy ended, in words chosen to be gentle. 'not_said' is
  /// always accepted: nobody has to explain a loss to an app.
  static const outcomes = <String, String>{
    'birth': 'Baby born',
    'loss': 'Pregnancy loss',
    'other': 'Other',
    'not_said': "I'd rather not say",
  };

  static const dueDateSources = <String, String>{
    'lmp': 'From the first day of your last period',
    'scan': 'From a scan',
    'clinician': 'From your doctor or midwife',
  };

  /// The WHO's eight antenatal contacts, used in Kenya: around these
  /// weeks of pregnancy.
  static const ancContactWeeks = [12, 20, 26, 30, 34, 36, 38, 40];

  bool get isOngoing => status == 'ongoing';

  static DateTime dueDateFromLmp(DateTime lmp) => _addDays(_day(lmp), gestationDays);

  /// The day pregnancy is counted from: the LMP, or the due date less 40
  /// weeks when only the due date is known.
  DateTime get datingStart => lmpDate != null ? _day(lmpDate!) : _addDays(_day(dueDate), -gestationDays);

  /// Days since [datingStart] on [today]: 0 on the first day.
  int daysPregnantOn(DateTime today) => daysBetween(datingStart, today);

  /// Completed weeks on [today], as a clinic would say "24 weeks".
  int weeksOn(DateTime today) {
    final d = daysPregnantOn(today);
    return d < 0 ? 0 : d ~/ 7;
  }

  /// Days past the completed weeks: "24 weeks and 3 days".
  int extraDaysOn(DateTime today) {
    final d = daysPregnantOn(today);
    return d < 0 ? 0 : d % 7;
  }

  /// 'first' (to week 12), 'second' (13 to 27) or 'third' (28 on), the
  /// same split as anc_visits.trimester.
  String trimesterOn(DateTime today) => trimesterForWeeks(weeksOn(today));

  static String trimesterForWeeks(int weeks) {
    if (weeks <= 12) return 'first';
    if (weeks <= 27) return 'second';
    return 'third';
  }

  static String trimesterName(String trimester) => switch (trimester) {
        'first' => 'first trimester',
        'second' => 'second trimester',
        _ => 'third trimester',
      };

  /// Days from [today] to the due date: negative once it has passed.
  int daysToDueOn(DateTime today) => daysBetween(_day(today), dueDate);

  /// How far along, 0 to 1, for a progress bar.
  double progressOn(DateTime today) => (daysPregnantOn(today) / gestationDays).clamp(0.0, 1.0);

  /// The recommended contacts still ahead after [visitsDone] visits.
  static int contactsToGo(int visitsDone) =>
      (ancContactWeeks.length - visitsDone).clamp(0, ancContactWeeks.length);

  /// The first recommended contact week after [weeks], or null past 40.
  static int? nextContactWeekAfter(int weeks) {
    for (final w in ancContactWeeks) {
      if (w > weeks) return w;
    }
    return null;
  }

  /// Why a first-day-of-last-period date can't be used, or null when it
  /// can: it must be in the past, and no more than 44 weeks ago (a
  /// pregnancy can run to 42 weeks; a little slack for late entry).
  static String? checkLmp(DateTime lmp, DateTime today) {
    final days = daysBetween(_day(lmp), _day(today));
    if (days < 0) return "That date is in the future. Choose the day your last period started.";
    if (days > 44 * 7) return 'That is more than 44 weeks ago. Please check the date.';
    return null;
  }

  /// Why a due date can't be used, or null when it can: within the next
  /// 42 weeks, or up to four weeks past (babies come late).
  static String? checkDueDate(DateTime due, DateTime today) {
    final days = daysBetween(_day(today), _day(due));
    if (days < -28) return 'That due date passed more than four weeks ago. Please check the date.';
    if (days > 42 * 7) return 'That is more than 42 weeks away. Please check the date.';
    return null;
  }

  factory Pregnancy.fromJson(Map<String, dynamic> json) {
    return Pregnancy(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      lmpDate: _date(json['lmp_date']),
      dueDate: _date(json['due_date']) ?? DateTime.now(),
      dueDateSource: json['due_date_source'] as String? ?? 'lmp',
      status: json['status'] as String? ?? 'ongoing',
      outcome: json['outcome'] as String?,
      endedOn: _date(json['ended_on']),
      createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'] as String),
    );
  }

  /// The columns the app writes. id and created_at are the database's.
  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'lmp_date': dateOnly(lmpDate),
      'due_date': dateOnly(dueDate),
      'due_date_source': dueDateSource,
      'status': status,
      'outcome': outcome,
      'ended_on': dateOnly(endedOn),
    };
  }

  static String? dateOnly(DateTime? d) =>
      d == null ? null : '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final d = DateTime.tryParse(v);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  // Via UTC so a daylight-saving change can never make it off by one.
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
