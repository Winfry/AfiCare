import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/message_provider.dart';
import 'package:aficare_flutter/providers/pregnancy_provider.dart';
import 'package:aficare_flutter/utils/medicine_course.dart';

import 'helpers/fake_supabase.dart';

/// Step 4d: weak spots — figures that flattered, failures that looked empty.
void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  http.Response boom() =>
      http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'});

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

  group('a failed load is not "nothing here"', () {
    test('People I care for: a failed save is not shown as "could not load"', () async {
      fake.routeJson('/rest/v1/dependent_profiles', <Object?>[]);
      final dep = DependentProvider();
      await dep.loadDependents('g1');
      expect(dep.loadFailed, isFalse);

      fake.routeRaw('/rest/v1/dependent_profiles', boom());
      final ok = await dep.updateDependent('d1', guardianId: 'g1', fullName: 'Amani');
      expect(ok, isFalse);
      expect(dep.loadFailed, isFalse, reason: 'only the save failed');
      expect(dep.error, contains("couldn't save"));
      expect(dep.error, isNot(contains('Exception')), reason: 'plain words, not technical text');

      await dep.loadDependents('g1');
      expect(dep.loadFailed, isTrue);
    });

    test('Maternal care: a failed save is not "couldn\'t load your pregnancy record"', () async {
      fake.routeJson('/rest/v1/pregnancies', <Object?>[]);
      fake.routeJson('/rest/v1/anc_visits', <Object?>[]);
      final p = PregnancyProvider();
      await p.load('p1');
      expect(p.loadFailed, isFalse);

      fake.routeRaw('/rest/v1/pregnancies', boom());
      await p.load('p1');
      expect(p.loadFailed, isTrue);
    });

    test('a chat that failed to load says so, instead of "Write your first message"', () async {
      fake.routeRaw('/rest/v1/messages', boom());
      final mp = MessageProvider();
      await mp.loadThread('me', 'dr');
      expect(mp.threadFailed, isTrue);
      expect(mp.thread, isEmpty);

      fake.clearRoute('/rest/v1/messages');
      fake.routeJson('/rest/v1/messages', <Object?>[]);
      await mp.loadThread('me', 'dr');
      expect(mp.threadFailed, isFalse);
    });
  });

  group('People I care for: wrong details can be cleared', () {
    test('"Not known" sends an empty date of birth, gender and blood type', () async {
      fake.routeJson('/rest/v1/dependent_profiles', [{'id': 'd1'}]);
      final ok = await DependentProvider().updateDependent(
        'd1',
        guardianId: 'g1',
        fullName: 'Amani',
        relationship: 'child',
        allergies: const [],
      );
      expect(ok, isTrue);
      final body = jsonDecode(fake.requestsTo('PATCH', 'dependent_profiles').single.body) as Map;
      expect(body.containsKey('date_of_birth'), isTrue);
      expect(body['date_of_birth'], isNull);
      expect(body['gender'], isNull);
      expect(body['blood_type'], isNull);
    });

    test('an update the database quietly refused is a failure', () async {
      fake.routeJson('/rest/v1/dependent_profiles', <Object?>[]);
      final dep = DependentProvider();
      expect(await dep.updateDependent('d1', guardianId: 'g1', fullName: 'Amani'), isFalse);
    });
  });
}
