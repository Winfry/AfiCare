import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';
import 'package:aficare_flutter/screens/patient/patient_onboarding_screen.dart';
import 'package:aficare_flutter/screens/patient/widgets/facility_picker.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  _FakeAuth({this.facilityId});
  final String? facilityId;

  @override
  UserModel? get currentUser => UserModel(
        id: 'mary',
        email: 'mary@example.com',
        fullName: 'Mary Wanjiru',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
        medilinkId: 'ML-NBO-111111',
        facilityId: facilityId,
      );
}

/// Records every person added; [failFor] names fail.
class _FakeDependants extends DependentProvider {
  final added = <String>[];
  final failFor = <String>{};

  @override
  Future<bool> addDependent({
    required String guardianId,
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
    required String relationship,
    String? bloodType,
    List<String>? allergies,
    String? notes,
  }) async {
    if (failFor.contains(fullName)) return false;
    added.add('$fullName ($relationship) for $guardianId');
    return true;
  }
}

const _tamia = FacilityChoice(id: 'tamia', name: 'Tamia Hospital', place: 'Kisumu · Hospital');
const _kisumu = FacilityChoice(id: 'kcrh', name: 'Kisumu County Referral Hospital', place: 'Kisumu');

class _FakeFacilities extends FacilitySearchService {
  _FakeFacilities() : super(null);
  bool fails = false;
  final searched = <String>[];

  @override
  Future<List<FacilityChoice>> search(String query) async {
    searched.add(query);
    if (fails) throw Exception('offline');
    final q = query.toLowerCase();
    return [for (final f in [_tamia, _kisumu]) if ('${f.name} ${f.place}'.toLowerCase().contains(q)) f];
  }

  @override
  Future<FacilityChoice?> byId(String id) async => [_tamia, _kisumu].where((f) => f.id == id).firstOrNull;
}

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  late _FakeDependants dependants;
  late _FakeFacilities facilities;

  Future<void> pump(WidgetTester tester, {String? savedFacility}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    dependants = _FakeDependants();
    facilities = _FakeFacilities();
    fake.routeJson('/rest/v1/users', {'id': 'mary'});
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth(facilityId: savedFacility)),
        ChangeNotifierProvider<DependentProvider>.value(value: dependants),
        ChangeNotifierProvider(create: (_) => PatientProfileProvider()),
      ],
      child: MaterialApp(home: PatientOnboardingScreen(facilityService: facilities, startAtStep: 2)),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// The name box in the "Someone you care for" form.
  Finder nameBox() => find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first;

  Future<void> addPerson(WidgetTester tester, String name) async {
    await tester.tap(find.text('+ Add someone'));
    await tester.pumpAndSettle();
    await tester.enterText(nameBox(), name);
    await tester.tap(find.text('Add them').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
  }

  List<http.Request> facilitySaves() => fake.requestsTo('PATCH', '/rest/v1/users').toList();

  testWidgets('Brian is added once, however many times she goes Back and Continue', (tester) async {
    await pump(tester);
    await addPerson(tester, 'Brian Otieno');
    await tapContinue(tester);

    expect(find.text('This is your MediLink ID'), findsOneWidget);
    expect(dependants.added, ['Brian Otieno (child) for mary']);

    for (var i = 0; i < 3; i++) {
      await goBack(tester);
      expect(find.text('Added ✓'), findsOneWidget, reason: 'he is shown as already added');
      expect(find.byTooltip('Remove Brian Otieno'), findsNothing);
      await tapContinue(tester);
    }
    expect(dependants.added, hasLength(1), reason: 'never added again');
  });

  testWidgets('if adding someone fails, she stays, is told who, and trying again adds only them', (tester) async {
    await pump(tester);
    await addPerson(tester, 'Brian Otieno');
    await addPerson(tester, 'Grace Akinyi');
    dependants.failFor.add('Grace Akinyi');

    await tapContinue(tester);
    expect(find.text('This is your MediLink ID'), findsNothing, reason: 'no false "All set"');
    expect(find.textContaining("We couldn't add Grace Akinyi"), findsOneWidget);
    expect(find.text('Added ✓'), findsOneWidget);
    expect(find.text('Not added yet. Continue tries again.'), findsOneWidget);
    expect(dependants.added, ['Brian Otieno (child) for mary']);

    dependants.failFor.clear();
    await tapContinue(tester);
    expect(find.text('This is your MediLink ID'), findsOneWidget);
    expect(dependants.added, ['Brian Otieno (child) for mary', 'Grace Akinyi (child) for mary']);
  });

  testWidgets('"My parent" is saved as a parent', (tester) async {
    await pump(tester);
    await tester.tap(find.text('+ Add someone'));
    await tester.pumpAndSettle();
    await tester.enterText(nameBox(), 'Mama Wanjiru');
    await tester.tap(find.text('My child'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My parent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add them').last);
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(dependants.added, ['Mama Wanjiru (parent) for mary']);
  });

  testWidgets('she finds her facility by typing, and it is saved once', (tester) async {
    await pump(tester);
    expect(find.text('Type at least 2 letters of its name or town.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'tam');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(facilities.searched, ['tam']);
    expect(find.text('Tamia Hospital'), findsOneWidget);

    await tester.tap(find.text('Tamia Hospital'));
    await tester.pumpAndSettle();
    expect(find.text('Change'), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('This is your MediLink ID'), findsOneWidget);
    final save = facilitySaves().single;
    expect(jsonDecode(save.body), {'facility_id': 'tamia'});
    expect(save.url.queryParameters['id'], 'eq.mary');

    await goBack(tester);
    expect(find.text('Tamia Hospital'), findsOneWidget);
    await tapContinue(tester);
    expect(facilitySaves(), hasLength(1), reason: 'unchanged, so not written again');
  });

  testWidgets('typing quickly searches once, for the last thing typed', (tester) async {
    await pump(tester);
    for (final q in ['k', 'ki', 'kis', 'kisu']) {
      await tester.enterText(find.byType(TextField).first, q);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(facilities.searched, ['kisu']);
    expect(find.text('Kisumu County Referral Hospital'), findsOneWidget);
  });

  testWidgets('a facility already on her account shows as chosen, and is not written again', (tester) async {
    await pump(tester, savedFacility: 'kcrh');
    expect(find.text('Kisumu County Referral Hospital'), findsOneWidget);
    await tapContinue(tester);
    expect(find.text('This is your MediLink ID'), findsOneWidget);
    expect(facilitySaves(), isEmpty);
  });

  testWidgets('if the facility cannot be saved, she stays and is told', (tester) async {
    await pump(tester);
    fake.routeRaw('/rest/v1/users',
        http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
    await tester.enterText(find.byType(TextField).first, 'tamia');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamia Hospital'));
    await tester.pumpAndSettle();

    await tapContinue(tester);
    expect(find.text('This is your MediLink ID'), findsNothing);
    expect(find.textContaining("We couldn't save your home facility"), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('if facilities cannot be searched it says so, and Try again works', (tester) async {
    await pump(tester);
    facilities.fails = true;
    await tester.enterText(find.byType(TextField).first, 'tamia');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't search facilities"), findsOneWidget);

    facilities.fails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Tamia Hospital'), findsOneWidget);
  });

  testWidgets('nothing found says what to try', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('No facility matches "zzz"'), findsOneWidget);
  });

  group('Skip for now', () {
    testWidgets('with nobody waiting, it just moves on', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(find.text('This is your MediLink ID'), findsOneWidget);
    });

    testWidgets('with someone not yet added, it asks; "Skip anyway" adds nobody', (tester) async {
      await pump(tester);
      await addPerson(tester, 'Brian Otieno');
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(find.text('Skip without adding Brian Otieno?'), findsOneWidget);
      await tester.tap(find.text('Skip anyway'));
      await tester.pumpAndSettle();
      expect(find.text('This is your MediLink ID'), findsOneWidget);
      expect(dependants.added, isEmpty);
    });

    testWidgets('"Add them" saves them and moves on', (tester) async {
      await pump(tester);
      await addPerson(tester, 'Brian Otieno');
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add them').last);
      await tester.pumpAndSettle();
      expect(find.text('This is your MediLink ID'), findsOneWidget);
      expect(dependants.added, ['Brian Otieno (child) for mary']);
    });
  });

  group('FacilitySearchService', () {
    test('cleaning keeps full stops and apostrophes, drops what would break the search', () {
      expect(FacilitySearchService.clean("  St. Mary's  "), "St. Mary's");
      expect(FacilitySearchService.clean('a"b\\c*d%e'), 'a b c d e');
    });

    test('searches by name, county or sub-county, quoted', () async {
      fake.routeJson('/rest/v1/facilities', [
        {'id': 'f1', 'name': "St. Mary's Mission Hospital", 'type': 'mission_hospital', 'county': 'Nairobi', 'sub_county': 'Langata'},
      ]);
      final found = await FacilitySearchService().search("St. Mary's");
      final url = fake.requestsTo('GET', '/rest/v1/facilities').single.url;
      expect(url.queryParameters['or'],
          '(name.ilike."*St. Mary\'s*",county.ilike."*St. Mary\'s*",sub_county.ilike."*St. Mary\'s*")');
      expect(url.queryParameters['limit'], '25');
      expect(found.single.name, "St. Mary's Mission Hospital");
      expect(found.single.place, 'Langata · Nairobi · Mission hospital');
    });

    test('one letter is not searched', () async {
      expect(await FacilitySearchService().search('k'), isEmpty);
      expect(fake.requests, isEmpty);
    });
  });
}
