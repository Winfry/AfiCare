import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aficare_flutter/models/appointment_model.dart';
import 'package:aficare_flutter/models/care_team_member_model.dart';
import 'package:aficare_flutter/models/prescription_model.dart';
import 'package:aficare_flutter/screens/patient/patient_nav.dart';
import 'package:aficare_flutter/screens/patient/patient_search.dart';

PrescriptionModel _medicine(String name, {String frequency = 'TDS', PrescriptionStatus status = PrescriptionStatus.active}) =>
    PrescriptionModel(
      id: name,
      patientId: 'mary',
      providerId: 'kamau',
      medicationName: name,
      dosage: '500mg',
      frequency: frequency,
      duration: '5 days',
      issuedAt: DateTime(2026, 10, 1),
      status: status,
    );

AppointmentModel _appointment(String id, DateTime when, {String? reason, AppointmentStatus status = AppointmentStatus.confirmed}) =>
    AppointmentModel(
      id: id,
      patientId: 'mary',
      providerId: 'kamau',
      scheduledAt: when,
      type: AppointmentType.inPerson,
      status: status,
      chiefComplaint: reason,
    );

final _kamau = CareTeamMemberModel(
  id: 'ct1',
  patientId: 'mary',
  providerId: 'kamau',
  specialtyLabel: 'general practice',
  isPrimary: true,
  createdAt: DateTime(2026, 1, 1),
  providerName: 'Dr Kamau',
  providerRole: 'doctor',
);

void main() {
  final now = DateTime(2026, 11, 4, 9);
  final adultPages = patientSearchPages(isDependent: false, gender: 'female');

  List<PatientSearchHit> search(String q) => PatientSearch.run(
        q,
        pages: adultPages,
        medicines: [_medicine('Amoxicillin'), _medicine('Panadol', frequency: 'PRN', status: PrescriptionStatus.completed)],
        appointments: [
          _appointment('a1', DateTime(2026, 11, 12, 10), reason: 'Blood pressure review'),
          _appointment('a2', DateTime(2026, 9, 3, 14), reason: 'Cough'),
        ],
        careTeam: [_kamau],
        now: now,
      );

  List<String> titles(String q) => search(q).map((h) => h.title).toList();

  group('pages', () {
    test('the words people use find the right page', () {
      expect(titles('pills').first, 'Medications');
      expect(titles('vaccine').first, 'Vaccinations');
      expect(titles('jab').first, 'Vaccinations');
      expect(titles('alarm').first, 'Medicine reminders');
      expect(titles('pregnancy').first, 'Maternal care');
      expect(titles('period').first, "Women's health");
      expect(titles('sha'), contains('Insurance claims'));
      expect(titles('999').first, 'Emergency support');
    });

    test('a page name typed in part is found first', () {
      expect(titles('refer').first, 'Referrals');
      expect(titles('Lab').first, 'Lab results');
      expect(titles('womens').first, "Women's health");
    });

    test('every word must match', () {
      expect(titles('blood pressure'), contains('Health records'));
      expect(titles('blood pressure'), isNot(contains('Medications')));
    });

    test('each page appears once, and goes where it says', () {
      final hits = search('messages').where((h) => h.kind == PatientSearchKind.page).toList();
      expect(hits.where((h) => h.title == 'Messages'), hasLength(1));
      expect(hits.firstWhere((h) => h.title == 'Messages').route, PatientRoutes.messages);
    });

    test("a child's profile has no adult pages to find", () {
      final childPages = patientSearchPages(isDependent: true, gender: 'female');
      final labels = childPages.map((p) => p.label).toSet();
      expect(labels, isNot(contains('Mental wellbeing')));
      expect(labels, isNot(contains('Maternal care')));
      expect(labels, isNot(contains('Expenses')));
      expect(labels, contains('Vaccinations'));
    });

    test("a man's search does not offer Women's health, and a woman's not Men's health", () {
      expect(patientSearchPages(isDependent: false, gender: 'male').map((p) => p.label), isNot(contains("Women's health")));
      expect(adultPages.map((p) => p.label), isNot(contains("Men's health")));
    });

    test('nothing typed, nothing found', () {
      expect(search(''), isEmpty);
      expect(search('   '), isEmpty);
    });

    test('a word that matches nothing finds nothing', () {
      expect(search('xylophone'), isEmpty);
    });
  });

  group('her own things', () {
    test('a medicine is found by name, with how often in plain words', () {
      final hit = search('amox').single;
      expect(hit.kind, PatientSearchKind.medicine);
      expect(hit.subtitle, '500mg · TDS (3 times a day) · Taking now');
      expect(hit.route, PatientRoutes.medications);
    });

    test('a past medicine is found and marked past', () {
      final hit = search('panadol').single;
      expect(hit.subtitle, contains('Past medicine'));
    });

    test('a doctor is found by name, with the appointments they hold', () {
      final hits = search('kamau');
      expect(hits.where((h) => h.kind == PatientSearchKind.careTeam).single.title, 'Dr Kamau');
      expect(hits.where((h) => h.kind == PatientSearchKind.appointment), hasLength(2));
    });

    test('an appointment is found by reason, by month, and says if it is upcoming', () {
      final byReason = search('cough').single;
      expect(byReason.kind, PatientSearchKind.appointment);
      expect(byReason.subtitle, contains('Past'));
      final byMonth = search('november').where((h) => h.kind == PatientSearchKind.appointment).single;
      expect(byMonth.title, 'Blood pressure review');
      expect(byMonth.subtitle, contains('Upcoming'));
      expect(byMonth.subtitle, contains('Dr Kamau'));
      expect(byMonth.route, PatientRoutes.appointments);
    });

    test('pages come before her things, and her things before nothing', () {
      final hits = search('medicine');
      expect(hits.first.kind, PatientSearchKind.page);
      expect(hits.where((h) => h.kind == PatientSearchKind.medicine), hasLength(2));
    });
  });

  group('the sheet', () {
    Future<GoRouter> pump(WidgetTester tester, {String? forName}) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PatientSearchSheet(
                    pages: adultPages,
                    medicines: [_medicine('Amoxicillin')],
                    appointments: const [],
                    careTeam: [_kamau],
                    forName: forName,
                  ),
                ),
                child: const Text('open search'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/patient/medications', builder: (_, __) => const Scaffold(body: Text('Medications page'))),
        GoRoute(path: '/patient/care-team', builder: (_, __) => const Scaffold(body: Text('Care team page'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('open search'));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('before typing it offers the common pages', (tester) async {
      await pump(tester);
      expect(find.text('Go to'), findsOneWidget);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Medicine reminders'), findsOneWidget);
    });

    testWidgets('results appear as she types, grouped, and tapping one goes there', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'amo');
      await tester.pump();
      expect(find.text('Your medicines'), findsOneWidget);
      expect(find.text('Amoxicillin'), findsOneWidget);

      await tester.tap(find.text('Amoxicillin'));
      await tester.pumpAndSettle();
      expect(find.text('Medications page'), findsOneWidget);
      expect(find.byType(PatientSearchSheet), findsNothing, reason: 'the sheet closes');
    });

    testWidgets('a doctor opens the care team', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'kam');
      await tester.pump();
      expect(find.text('Care team'), findsWidgets);
      await tester.tap(find.text('Dr Kamau'));
      await tester.pumpAndSettle();
      expect(find.text('Care team page'), findsOneWidget);
    });

    testWidgets('pressing enter opens the best match', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'pills');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Medications page'), findsOneWidget);
    });

    testWidgets('nothing found says what to try', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'xylophone');
      await tester.pump();
      expect(find.text('Nothing found for "xylophone"'), findsOneWidget);
      expect(find.textContaining('a doctor\'s name'), findsOneWidget);
    });

    testWidgets("on a child's profile it says whose things it searches", (tester) async {
      await pump(tester, forName: 'Brian');
      expect(find.text("Search Brian's medicines, appointments…"), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'amox');
      await tester.pump();
      expect(find.text("Brian's medicines"), findsOneWidget);
    });
  });
}
