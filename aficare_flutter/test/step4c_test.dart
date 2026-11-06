import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/medication_reminder_model.dart';
import 'package:aficare_flutter/models/patient_profile_model.dart';
import 'package:aficare_flutter/models/user_preferences_model.dart';
import 'package:aficare_flutter/providers/preferences_provider.dart';
import 'package:aficare_flutter/screens/patient/medication_reminder_screen.dart';
import 'package:aficare_flutter/services/patient_photo_service.dart';

import 'helpers/fake_supabase.dart';

/// Step 4c: the buttons that said something happened when it didn't.
void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  group('"Set a reminder" after adding a medicine', () {
    test('the draft travels in the page address and comes back the same', () {
      const draft = ReminderDraft(medicine: 'Amoxicillin & Co', dosage: '500 mg', perDay: 3);
      final uri = Uri.parse(draft.toLocation());
      expect(uri.path, '/patient/medication-reminders');
      final back = ReminderDraft.fromQuery(uri.queryParameters)!;
      expect(back.medicine, 'Amoxicillin & Co');
      expect(back.dosage, '500 mg');
      expect(back.perDay, 3);
    });

    test('no medicine means no draft; odd counts are kept within 1–6', () {
      expect(ReminderDraft.fromQuery({}), isNull);
      expect(ReminderDraft.fromQuery({'medicine': '  '}), isNull);
      expect(ReminderDraft.fromQuery({'medicine': 'X', 'perDay': '9'})!.perDay, 6);
      expect(ReminderDraft.fromQuery({'medicine': 'X', 'perDay': 'abc'})!.perDay, 1);
    });

    test('every count from 1 to 6 has its own frequency, and back again', () {
      for (var n = 1; n <= 6; n++) {
        final f = MedicationReminder.frequencyFor(n);
        expect(MedicationReminder.perDay(f), n);
        expect(MedicationReminder.frequencyLabel(f), isNot(f), reason: 'has a label');
      }
      expect(MedicationReminder.perDay('as_needed'), 0);
    });
  });

  group('settings saved to her account', () {
    test('Bold text is stored and read back', () {
      final p = UserPreferencesModel(userId: 'u', boldText: true);
      expect(p.toJson()['bold_text'], isTrue);
      expect(UserPreferencesModel.fromJson(p.toJson()).boldText, isTrue);
      expect(UserPreferencesModel.fromJson({'user_id': 'u'}).boldText, isFalse);
      expect(p.copyWith(textScale: 1.2).boldText, isTrue, reason: 'copyWith keeps it');
    });

    test('settings that failed to load are never saved over', () async {
      fake.routeRaw('/rest/v1/user_preferences',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      final pp = PreferencesProvider();
      await pp.loadPreferences('u1');
      expect(pp.loadFailed, isTrue);

      final ok = await pp.save(pp.prefs!.copyWith(boldText: true));
      expect(ok, isFalse);
      expect(pp.error, contains("didn't load"));
      expect(fake.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    test('once they load, saving works again', () async {
      fake.routeRaw('/rest/v1/user_preferences',
          http.Response('{"message":"boom"}', 500, headers: {'content-type': 'application/json'}));
      final pp = PreferencesProvider();
      await pp.loadPreferences('u1');
      fake.clearRoute('/rest/v1/user_preferences');
      fake.routeJson('/rest/v1/user_preferences', {'user_id': 'u1', 'bold_text': false});
      await pp.loadPreferences('u1');
      expect(pp.loadFailed, isFalse);
      expect(await pp.save(pp.prefs!.copyWith(boldText: true)), isTrue);
    });
  });

  group('insurance provider', () {
    test('is stored and read back with the policy number', () {
      final p = PatientProfileModel(id: 'p1', insuranceId: 'SHA-123', insuranceProvider: 'SHA');
      final json = p.toJson();
      expect(json['insurance_provider'], 'SHA');
      expect(json['insurance_id'], 'SHA-123');
      final back = PatientProfileModel.fromJson(json);
      expect(back.insuranceProvider, 'SHA');
      expect(back.copyWith(bloodType: 'O+').insuranceProvider, 'SHA', reason: 'copyWith keeps it');
    });
  });

  group('private patient photo', () {
    final photos = PatientPhotoService();
    final bytes = Uint8List.fromList(List.filled(100, 7));

    test('the account stores where the photo is, never a public link', () {
      expect(PatientPhotoService.storedValueFor('p1'), 'patient-photos/p1/photo');
      expect(PatientPhotoService.isPrivate('patient-photos/p1/photo'), isTrue);
      expect(PatientPhotoService.isPrivate('https://x.supabase.co/storage/v1/object/public/a.jpg'), isFalse);
    });

    test('an old public link is shown as it is; no photo is no link', () async {
      expect(await photos.linkFor('https://example.com/a.jpg'), 'https://example.com/a.jpg');
      expect(await photos.linkFor(null), isNull);
      expect(await photos.linkFor(''), isNull);
    });

    // What Supabase Storage answers to an upload.
    void storageAcceptsUploads() =>
        fake.routeJson('/storage/v1/object/', {'Key': 'patient-photos/p1/photo', 'Id': 'obj-1'});

    test('saving uploads to the private bucket and records the place on her account', () async {
      storageAcceptsUploads();
      fake.routeJson('/rest/v1/users', [{'id': 'p1'}]);
      final problem = await photos.save('p1', bytes);
      expect(problem, isNull);
      final upload = fake.requests.firstWhere((r) => r.url.path.contains('/storage/v1/object/'));
      expect(upload.url.path, contains('patient-photos/p1/photo'));
      final update = fake.requestsTo('PATCH', '/rest/v1/users').single;
      expect(jsonDecode(update.body), {'photo_url': 'patient-photos/p1/photo'});
    });

    test('an account update that changed nothing is reported, not "Photo saved"', () async {
      storageAcceptsUploads();
      fake.routeJson('/rest/v1/users', <Object?>[]);
      final problem = await photos.save('p1', bytes);
      expect(problem, contains("couldn't save your photo"));
    });

    test('a refused upload is reported, and the account is not touched', () async {
      fake.routeRaw('/storage/v1/object/',
          http.Response('{"message":"denied","statusCode":"403"}', 403, headers: {'content-type': 'application/json'}));
      final problem = await photos.save('p1', bytes);
      expect(problem, isNotNull);
      expect(fake.requestsTo('PATCH', '/rest/v1/users'), isEmpty);
    });

    test('a photo over 5 MB is refused before anything is sent', () async {
      final big = Uint8List(PatientPhotoService.maxBytes + 1);
      expect(await photos.save('p1', big), contains('too large'));
      expect(fake.requests, isEmpty);
    });

    test('removing clears the account first', () async {
      fake.routeJson('/rest/v1/users', [{'id': 'p1'}]);
      expect(await photos.remove('p1'), isNull);
      final update = fake.requestsTo('PATCH', '/rest/v1/users').single;
      expect(jsonDecode(update.body), {'photo_url': null});
    });
  });
}
