import 'package:aficare_flutter/models/anc_visit_model.dart';
import 'package:aficare_flutter/models/pregnancy_model.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';

/// A [PregnancyProvider] whose record lives in memory, for screen tests.
/// Writes succeed unless [failWrites] is set, and are recorded.
class FakePregnancyProvider extends PregnancyProvider {
  FakePregnancyProvider({List<Pregnancy> pregnancies = const [], List<AncVisit> visits = const []})
      : _list = [...pregnancies],
        _visitList = [...visits];

  final List<Pregnancy> _list;
  final List<AncVisit> _visitList;
  bool failWrites = false;
  final started = <Pregnancy>[];
  final ended = <(Pregnancy, String)>[];
  final addedVisits = <AncVisit>[];

  @override
  bool get loaded => true;

  @override
  String? get error => failWrites ? 'Could not save.' : null;

  @override
  List<Pregnancy> get pregnancies => List.unmodifiable(_list);

  @override
  Pregnancy? get current {
    for (final p in _list) {
      if (p.isOngoing) return p;
    }
    return null;
  }

  @override
  List<Pregnancy> get past => _list.where((p) => !p.isOngoing).toList();

  @override
  Pregnancy? get lastEnded => past.isEmpty ? null : past.first;

  @override
  List<AncVisit> visitsOf(Pregnancy pregnancy) => _visitList.where((v) => v.pregnancyId == pregnancy.id).toList();

  @override
  Future<void> load(String patientId) async {}

  @override
  Future<bool> start({required String patientId, DateTime? lmp, DateTime? dueDate, String dueDateSource = 'scan'}) async {
    if (failWrites) return false;
    final p = Pregnancy(
      id: 'new',
      patientId: patientId,
      lmpDate: lmp,
      dueDate: lmp != null ? Pregnancy.dueDateFromLmp(lmp) : dueDate!,
      dueDateSource: lmp != null ? 'lmp' : dueDateSource,
    );
    started.add(p);
    _list.insert(0, p);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> end(Pregnancy pregnancy, {required String outcome, required DateTime endedOn}) async {
    if (failWrites) return false;
    ended.add((pregnancy, outcome));
    final i = _list.indexWhere((p) => p.id == pregnancy.id);
    _list[i] = Pregnancy(
      id: pregnancy.id,
      patientId: pregnancy.patientId,
      lmpDate: pregnancy.lmpDate,
      dueDate: pregnancy.dueDate,
      dueDateSource: pregnancy.dueDateSource,
      status: 'ended',
      outcome: outcome,
      endedOn: endedOn,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> addVisit({
    required DateTime visitDate,
    int? systolicBP,
    int? diastolicBP,
    double? weight,
    double? hemoglobin,
    int? fetalHeartRate,
    double? fundalHeight,
    String facility = '',
    List<String> dangerSigns = const [],
    String? notes,
  }) async {
    final p = current;
    if (failWrites || p == null) return false;
    final weeks = p.weeksOn(visitDate);
    final v = AncVisit(
      id: 'v${_visitList.length + 1}',
      patientId: p.patientId,
      pregnancyId: p.id,
      visitNumber: visitsOf(p).length + 1,
      gestationalWeeks: weeks,
      trimester: Pregnancy.trimesterForWeeks(weeks),
      visitDate: visitDate,
      systolicBP: systolicBP,
      diastolicBP: diastolicBP,
      weight: weight,
      dangerSigns: dangerSigns,
      facility: facility,
    );
    addedVisits.add(v);
    _visitList.insert(0, v);
    notifyListeners();
    return true;
  }
}
