import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/emergency_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> profileRow({
    String id = 'e1',
    String? bloodType = 'O+',
    List<String> allergies = const ['Penicillin'],
    String? contactName = 'John Doe',
    String? contactPhone = '0700000000',
  }) {
    return {
      'id': id,
      'patient_id': 'p1',
      'blood_type': bloodType,
      'allergies': allergies,
      'chronic_conditions': <String>[],
      'current_medications': <String>[],
      'emergency_contact_name': contactName,
      'emergency_contact_phone': contactPhone,
      'emergency_contact_relationship': 'Spouse',
      'emergency_contact2_name': null,
      'emergency_contact2_phone': null,
      'emergency_contact2_relationship': null,
      'notes': null,
    };
  }

  group('EmergencyProfileProvider.loadProfile', () {
    test('loads a profile and reports completeness', () async {
      fake.routeJson('/rest/v1/emergency_profiles', [profileRow()]);

      final provider = EmergencyProfileProvider();
      await provider.loadProfile('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.bloodType, 'O+');
      expect(provider.profile!.allergies, ['Penicillin']);
      expect(provider.isComplete, isTrue);

      final req = fake.requestsTo('GET', 'emergency_profiles').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('no profile leaves it null', () async {
      fake.routeJson('/rest/v1/emergency_profiles', <Object?>[]);

      final provider = EmergencyProfileProvider();
      await provider.loadProfile('p1');

      expect(provider.profile, isNull);
      expect(provider.isComplete, isFalse);
    });
  });

  group('EmergencyProfileProvider.saveProfile', () {
    test('upserts and stores a new profile', () async {
      fake.routeJson('/rest/v1/emergency_profiles', <String, dynamic>{});

      final provider = EmergencyProfileProvider();
      final ok = await provider.saveProfile(
        patientId: 'p1',
        bloodType: 'A-',
        allergies: ['Sulfa'],
        emergencyContactName: 'Jane Roe',
        emergencyContactPhone: '0711000000',
      );

      expect(ok, isTrue);
      final upsert = fake.requestsTo('POST', 'emergency_profiles').single;
      final body = jsonDecode(upsert.body) as Map<String, dynamic>;
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('blood_type', 'A-'));
      expect(provider.profile!.bloodType, 'A-');
      expect(provider.isComplete, isTrue);
    });

    test('failure returns false and records error', () async {
      fake.routeRaw(
        '/rest/v1/emergency_profiles',
        http.Response('{"message":"denied"}', 500),
      );

      final provider = EmergencyProfileProvider();
      final ok = await provider.saveProfile(patientId: 'p1', bloodType: 'O+');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
