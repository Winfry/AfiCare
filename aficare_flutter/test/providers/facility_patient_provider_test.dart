import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/facility_patient_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> patientRow({
    String id = 'fp1',
    String facilityId = 'f1',
    String fullName = 'Jane Walkin',
    String shaStatus = 'unknown',
  }) {
    return {
      'id': id,
      'facility_id': facilityId,
      'full_name': fullName,
      'date_of_birth': '1990-01-01',
      'gender': 'female',
      'phone': '0700000000',
      'file_number': 'OP-001',
      'sha_status': shaStatus,
      'sha_number': null,
      'allergies': ['penicillin'],
      'linked_user_id': null,
      'linked_dependent_id': null,
      'created_by': null,
      'created_at': '2026-01-01T09:00:00.000Z',
      'updated_at': '2026-01-01T09:00:00.000Z',
    };
  }

  Map<String, dynamic> visitRow({
    String id = 'v1',
    String facilityPatientId = 'fp1',
    String status = 'registered',
  }) {
    return {
      'id': id,
      'facility_id': 'f1',
      'facility_patient_id': facilityPatientId,
      'status': status,
      'provider_id': null,
      'chief_complaint': 'Fever',
      'notes': null,
      'occurred_at': '2026-01-02T09:00:00.000Z',
      'created_by': null,
      'created_at': '2026-01-02T09:00:00.000Z',
    };
  }

  group('FacilityPatientProvider.loadFacilityPatients', () {
    test('maps rows for a facility', () async {
      fake.routeJson('/rest/v1/facility_patients', [patientRow()]);

      final provider = FacilityPatientProvider();
      await provider.loadFacilityPatients('f1');

      expect(provider.error, isNull);
      expect(provider.patients, hasLength(1));
      expect(provider.patients.first.fullName, 'Jane Walkin');
      expect(provider.patients.first.allergies, ['penicillin']);

      final req = fake.requestsTo('GET', 'facility_patients').single;
      expect(req.url.queryParameters['facility_id'], 'eq.f1');
    });

    test('empty facility has no patients, no crash', () async {
      fake.routeJson('/rest/v1/facility_patients', <Map<String, dynamic>>[]);

      final provider = FacilityPatientProvider();
      await provider.loadFacilityPatients('f1');

      expect(provider.patients, isEmpty);
    });

    test('server error records error', () async {
      fake.routeRaw(
        '/rest/v1/facility_patients',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = FacilityPatientProvider();
      await provider.loadFacilityPatients('f1');

      expect(provider.error, isNotNull);
    });
  });

  group('FacilityPatientProvider.loadPatientDetail', () {
    test('loads the patient and their visits', () async {
      fake.routeJson('/rest/v1/facility_patients', patientRow());
      fake.routeJson('/rest/v1/visits', [visitRow()]);

      final provider = FacilityPatientProvider();
      await provider.loadPatientDetail('fp1');

      expect(provider.selectedPatient?.id, 'fp1');
      expect(provider.selectedPatientVisits, hasLength(1));
      expect(provider.selectedPatientVisits.first.status, 'registered');
    });
  });

  group('FacilityPatientProvider.registerPatient', () {
    test('calls facility_admin_register_patient, not a raw insert', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_register_patient', 'fp1');
      fake.routeJson('/rest/v1/facility_patients', [patientRow()]);

      final provider = FacilityPatientProvider();
      final newId = await provider.registerPatient(
        facilityId: 'f1',
        fullName: 'Jane Walkin',
        allergies: const ['penicillin'],
      );

      expect(newId, 'fp1');
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_register_patient').single;
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
      expect(rpcCall.body, contains('"patient_full_name":"Jane Walkin"'));
      expect(fake.requestsTo('POST', '/facility_patients'), isEmpty);
      expect(provider.patients, hasLength(1));
    });

    test('RPC failure (e.g. wrong facility) surfaces the error, patient not added', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_register_patient',
        http.Response('{"message":"Only an admin of this facility can register a patient here"}', 400),
      );

      final provider = FacilityPatientProvider();
      final newId = await provider.registerPatient(facilityId: 'f2', fullName: 'X');

      expect(newId, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('FacilityPatientProvider.registerVisit', () {
    test('calls facility_admin_register_visit and reloads the visit list', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_register_visit', 'v1');
      fake.routeJson('/rest/v1/facility_patients', patientRow());
      fake.routeJson('/rest/v1/visits', [visitRow()]);

      final provider = FacilityPatientProvider();
      final ok = await provider.registerVisit(
        facilityPatientId: 'fp1',
        chiefComplaint: 'Fever',
      );

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_register_visit').single;
      expect(rpcCall.body, contains('"target_facility_patient_id":"fp1"'));
      expect(rpcCall.body, contains('"visit_chief_complaint":"Fever"'));
      expect(provider.selectedPatientVisits, hasLength(1));
    });

    test('forwards status and priority when adding straight to the queue', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_register_visit', 'v1');
      fake.routeJson('/rest/v1/facility_patients', patientRow());
      fake.routeJson('/rest/v1/visits', [visitRow()]);

      final provider = FacilityPatientProvider();
      final ok = await provider.registerVisit(
        facilityPatientId: 'fp1',
        chiefComplaint: 'Fever',
        status: 'waiting',
        priority: 'urgent',
      );

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_register_visit').single;
      expect(rpcCall.body, contains('"visit_status":"waiting"'));
      expect(rpcCall.body, contains('"visit_priority":"urgent"'));
    });
  });

  group('FacilityPatientProvider.loadActiveVisits', () {
    test('maps rows with patient names and file numbers', () async {
      fake.routeJson('/rest/v1/visits', [
        visitRow(id: 'v1', facilityPatientId: 'fp1', status: 'waiting'),
      ]);
      fake.routeJson('/rest/v1/facility_patients', [patientRow(id: 'fp1', fullName: 'Jane Walkin')]);

      final provider = FacilityPatientProvider();
      await provider.loadActiveVisits('f1');

      expect(provider.error, isNull);
      expect(provider.activeVisits, hasLength(1));
      expect(provider.activeVisits.first['patient_name'], 'Jane Walkin');
      expect(provider.activeVisits.first['patient_file_number'], 'OP-001');
    });

    test('requests only queue-relevant statuses, not registered/cancelled', () async {
      fake.routeJson('/rest/v1/visits', [
        visitRow(id: 'v1', facilityPatientId: 'fp1', status: 'waiting'),
      ]);
      fake.routeJson('/rest/v1/facility_patients', [patientRow(id: 'fp1')]);

      final provider = FacilityPatientProvider();
      await provider.loadActiveVisits('f1');

      final req = fake.requestsTo('GET', '/visits').single;
      final orParam = req.url.queryParameters['or'] ?? '';
      expect(orParam, contains('waiting'));
      expect(orParam, contains('triage'));
      expect(orParam, contains('in_consultation'));
      expect(orParam, contains('completed'));
      expect(orParam, isNot(contains('registered')));
      expect(orParam, isNot(contains('cancelled')));
    });

    test('empty facility has no active visits, no crash', () async {
      fake.routeJson('/rest/v1/visits', <Map<String, dynamic>>[]);

      final provider = FacilityPatientProvider();
      await provider.loadActiveVisits('f1');

      expect(provider.error, isNull);
      expect(provider.activeVisits, isEmpty);
      expect(fake.requestsTo('GET', '/facility_patients'), isEmpty);
    });
  });

  group('FacilityPatientProvider.updateVisitStatus', () {
    test('calls facility_admin_update_visit_status, not a raw update', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_update_visit_status', null);

      final provider = FacilityPatientProvider();
      final ok = await provider.updateVisitStatus(visitId: 'v1', newStatus: 'triage');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_update_visit_status').single;
      expect(rpcCall.body, contains('"target_visit_id":"v1"'));
      expect(rpcCall.body, contains('"new_status":"triage"'));
      expect(fake.requestsTo('PATCH', '/visits'), isEmpty);
    });

    test('RPC failure surfaces the error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_update_visit_status',
        http.Response('{"message":"Only an admin of this facility can update this visit"}', 400),
      );

      final provider = FacilityPatientProvider();
      final ok = await provider.updateVisitStatus(visitId: 'v1', newStatus: 'triage');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
