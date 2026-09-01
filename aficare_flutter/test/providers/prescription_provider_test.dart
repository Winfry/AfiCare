import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/prescription_model.dart';
import 'package:aficare_flutter/providers/prescription_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> rxCrow({
    String id = 'rx1',
    String patientId = 'p1',
    String status = 'active',
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'provider_id': 'prov-1',
      'consultation_id': null,
      'medication_name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': 'twice daily',
      'duration': '7 days',
      'instructions': 'After food',
      'issued_at': '2026-06-01T09:00:00.000Z',
      'expires_at': null,
      'status': status,
    };
  }

  group('PrescriptionProvider.loadPrescriptions', () {
    test('maps rows for a patient', () async {
      fake.routeJson('/rest/v1/prescriptions', [
        rxCrow(),
        rxCrow(id: 'rx2', status: 'completed'),
      ]);

      final provider = PrescriptionProvider();
      await provider.loadPrescriptions('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.prescriptions, hasLength(2));
      expect(provider.getActivePrescriptions(), hasLength(1));

      final req = fake.requestsTo('GET', 'prescriptions').single;
      expect(req.url.queryParameters['patient_id'], 'eq.p1');
    });

    test('empty response leaves empty list', () async {
      fake.routeJson('/rest/v1/prescriptions', <Object?>[]);

      final provider = PrescriptionProvider();
      await provider.loadPrescriptions('p1');

      expect(provider.prescriptions, isEmpty);
      expect(provider.error, isNull);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/prescriptions',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = PrescriptionProvider();
      await provider.loadPrescriptions('p1');

      expect(provider.error, isNotNull);
    });
  });

  group('PrescriptionProvider.createPrescription', () {
    test('inserts without id and reloads', () async {
      fake.routeJson('/rest/v1/prescriptions', <String, dynamic>{});

      final provider = PrescriptionProvider();
      final rx = PrescriptionModel(
        id: 'rx-new',
        patientId: 'p1',
        providerId: 'prov-1',
        medicationName: 'Paracetamol',
        dosage: '1g',
        frequency: 'three times daily',
        duration: '5 days',
        issuedAt: DateTime.utc(2026, 6, 1),
        status: PrescriptionStatus.active,
      );

      final ok = await provider.createPrescription(rx);
      expect(ok, isTrue);

      final insert = fake.requestsTo('POST', 'prescriptions').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body, containsPair('medication_name', 'Paracetamol'));
      expect(body, containsPair('status', 'active'));
    });

    test('failure returns false', () async {
      fake.routeRaw(
        '/rest/v1/prescriptions',
        http.Response('{"message":"conflict"}', 409),
      );

      final provider = PrescriptionProvider();
      final rx = PrescriptionModel(
        id: 'rx-new',
        patientId: 'p1',
        providerId: 'prov-1',
        medicationName: 'Paracetamol',
        dosage: '1g',
        frequency: 'three times daily',
        duration: '5 days',
        issuedAt: DateTime.utc(2026, 6, 1),
        status: PrescriptionStatus.active,
      );

      expect(await provider.createPrescription(rx), isFalse);
    });
  });

  group('PrescriptionProvider.updateStatus', () {
    test('updates status locally and sends patch', () async {
      fake.routeJson('/rest/v1/prescriptions', [rxCrow()]);

      final provider = PrescriptionProvider();
      await provider.loadPrescriptions('p1');

      final ok = await provider.updateStatus('rx1', PrescriptionStatus.completed);

      expect(ok, isTrue);
      expect(provider.prescriptions.single.status, PrescriptionStatus.completed);

      final update = fake.requestsTo('PATCH', 'prescriptions').single;
      final body = jsonDecode(update.body) as Map<String, dynamic>;
      expect(body, containsPair('status', 'completed'));
    });
  });
}
