import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/patient_profile_model.dart';
import 'package:aficare_flutter/providers/patient_profile_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> profileRow({String id = 'p1'}) {
    return {
      'id': id,
      'date_of_birth': '1990-01-01',
      'gender': 'female',
      'blood_type': 'O+',
      'allergies': ['Penicillin'],
      'chronic_conditions': ['Asthma'],
      'emergency_contact_name': 'Mother',
      'emergency_contact_phone': '0712345678',
      'address': 'Nairobi',
      'insurance_id': 'NHIF-1',
    };
  }

  group('PatientProfileProvider.loadProfile', () {
    test('maps an existing profile row', () async {
      fake.routeJson('/rest/v1/patients', profileRow());

      final provider = PatientProfileProvider();
      await provider.loadProfile('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.bloodType, 'O+');
      expect(provider.profile!.allergies, ['Penicillin']);
    });

    test('creates an empty profile when no row exists', () async {
      // maybeSingle unwraps a 1-element raw list; return an empty list.
      fake.routeJson('/rest/v1/patients', <Object?>[]);

      final provider = PatientProfileProvider();
      await provider.loadProfile('p1');

      expect(provider.error, isNull);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.id, 'p1');
    });

    test('falls back to empty profile on server error', () async {
      fake.routeRaw(
        '/rest/v1/patients',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = PatientProfileProvider();
      await provider.loadProfile('p1');

      expect(provider.error, isNotNull);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.id, 'p1');
    });
  });

  group('PatientProfileProvider.saveProfile', () {
    test('upserts the profile and updates local state', () async {
      fake.routeJson('/rest/v1/patients', <String, dynamic>{});

      final provider = PatientProfileProvider();
      final profile = PatientProfileModel(
        id: 'p1',
        bloodType: 'AB+',
        allergies: const ['None'],
      );

      final ok = await provider.saveProfile(profile);

      expect(ok, isTrue);
      expect(provider.profile, same(profile));

      final upsert = fake.requestsTo('POST', 'patients').single;
      final body = jsonDecode(upsert.body) as Map<String, dynamic>;
      expect(body, containsPair('id', 'p1'));
      expect(body, containsPair('blood_type', 'AB+'));
    });
  });
}
