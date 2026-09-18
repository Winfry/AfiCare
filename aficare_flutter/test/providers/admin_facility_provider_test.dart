import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/providers/admin_facility_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> facilityRow({
    String id = 'f1',
    String name = 'Kenyatta Hospital',
    String type = 'hospital',
    String? county,
  }) {
    return {
      'id': id,
      'name': name,
      'type': type,
      'county': county,
      'status': 'active',
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  Map<String, dynamic> deptRow({String id = 'd1', String facilityId = 'f1'}) {
    return {
      'id': id,
      'facility_id': facilityId,
      'name': 'Cardiology',
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('AdminFacilityProvider filters', () {
    test('filteredFacilities applies type and search', () async {
      fake.routeJson('/rest/v1/facilities', [
        facilityRow(),
        facilityRow(id: 'f2', name: 'Nairobi Clinic', type: 'clinic', county: 'Nairobi'),
        facilityRow(id: 'f3', name: 'Mombasa Hospital', type: 'hospital'),
      ]);

      final provider = AdminFacilityProvider();
      addTearDown(provider.dispose); // cancels the search debounce timer below

      await provider.loadFacilities();

      provider.setTypeFilter('clinic');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(provider.filteredFacilities.map((f) => f.id), ['f2']);

      provider.setTypeFilter('all');
      await Future.delayed(const Duration(milliseconds: 20));
      provider.setSearchQuery('nairobi');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.filteredFacilities.map((f) => f.id), ['f2']);
    });
  });

  group('AdminFacilityProvider search (server-side)', () {
    test('setSearchQuery debounces then queries the database, not just what is loaded', () async {
      fake.routeJson('/rest/v1/facilities', [
        facilityRow(id: 'f9', name: 'Faraway Dispensary'),
      ]);

      final provider = AdminFacilityProvider();
      addTearDown(provider.dispose);
      provider.setSearchQuery('faraway');

      // Debounced -- nothing fired yet.
      expect(fake.requestsTo('GET', 'facilities'), isEmpty);

      await Future.delayed(const Duration(milliseconds: 400));

      final req = fake.requestsTo('GET', 'facilities').single;
      expect(req.url.queryParameters['name'], contains('faraway'));
      expect(provider.facilities.single.id, 'f9');
    });

    test('clearing search and type filter falls back to the recent-200 browse view', () async {
      fake.routeJson('/rest/v1/facilities', [facilityRow()]);

      final provider = AdminFacilityProvider();
      addTearDown(provider.dispose);
      provider.setTypeFilter('all');

      await Future.delayed(const Duration(milliseconds: 50));

      final req = fake.requestsTo('GET', 'facilities').single;
      expect(req.url.queryParameters['limit'], '200');
      expect(req.url.queryParameters['order'], contains('created_at.desc'));
    });
  });

  group('AdminFacilityProvider.loadFacilities', () {
    test('maps rows', () async {
      fake.routeJson('/rest/v1/facilities', [facilityRow()]);

      final provider = AdminFacilityProvider();
      await provider.loadFacilities();

      expect(provider.error, isNull);
      expect(provider.facilities, hasLength(1));
      expect(provider.facilities.first.name, 'Kenyatta Hospital');
    });

    test('server error records error', () async {
      fake.routeRaw(
        '/rest/v1/facilities',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AdminFacilityProvider();
      await provider.loadFacilities();

      expect(provider.error, isNotNull);
    });
  });

  group('AdminFacilityProvider departments', () {
    test('loadDepartments maps rows for a facility', () async {
      fake.routeJson('/rest/v1/departments', [deptRow()]);

      final provider = AdminFacilityProvider();
      await provider.loadDepartments('f1');

      expect(provider.departments, hasLength(1));
      expect(provider.departments.first.name, 'Cardiology');

      final req = fake.requestsTo('GET', 'departments').single;
      expect(req.url.queryParameters['facility_id'], 'eq.f1');
    });

    test('getFacilityStats counts providers and departments', () async {
      fake.routeJson('/rest/v1/users', [
        {'id': 'u1'},
        {'id': 'u2'},
      ]);
      fake.routeJson('/rest/v1/departments', [
        {'id': 'd1'},
        {'id': 'd2'},
        {'id': 'd3'},
      ]);

      final provider = AdminFacilityProvider();
      final stats = await provider.getFacilityStats('f1');

      expect(stats['providers'], 2);
      expect(stats['departments'], 3);
    });
  });

  group('AdminFacilityProvider provider linking', () {
    Map<String, dynamic> linkRow({String providerId = 'p1', String facilityId = 'f1', bool isPrimary = false}) {
      return {
        'provider_id': providerId,
        'facility_id': facilityId,
        'specialty': 'Cardiology',
        'is_primary': isPrimary,
        'created_at': '2026-01-01T09:00:00.000Z',
      };
    }

    test('loadFacilityProviders merges provider_facilities with user names', () async {
      fake.routeJson('/rest/v1/provider_facilities', [linkRow()]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi'},
      ]);

      final provider = AdminFacilityProvider();
      await provider.loadFacilityProviders('f1');

      expect(provider.facilityProviders, hasLength(1));
      expect(provider.facilityProviders.first.providerName, 'Dr. Mwangi');
      expect(provider.facilityProviders.first.specialty, 'Cardiology');
    });

    test('searchVerifiedProviders keeps only verified candidates', () async {
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi', 'email': 'mwangi@example.com'},
        {'id': 'p2', 'full_name': 'Dr. Otieno', 'email': 'otieno@example.com'},
      ]);
      fake.routeJson('/rest/v1/provider_credentials', [
        {'provider_id': 'p1', 'specialty': 'Cardiology'},
      ]);

      final provider = AdminFacilityProvider();
      await provider.searchVerifiedProviders('Dr');

      expect(provider.providerSearchResults, hasLength(1));
      expect(provider.providerSearchResults.first['id'], 'p1');
    });

    test('linkProviderToFacility calls the admin RPC and reloads the roster', () async {
      fake.routeJson('/rest/v1/rpc/admin_link_provider_to_facility', <String, dynamic>{});
      fake.routeJson('/rest/v1/provider_facilities', [linkRow(isPrimary: true)]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi'},
      ]);

      final provider = AdminFacilityProvider();
      final ok = await provider.linkProviderToFacility('p1', 'f1', specialty: 'Cardiology', isPrimary: true);

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/admin_link_provider_to_facility').single;
      expect(rpcCall.body, contains('"target_user_id":"p1"'));
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
      expect(provider.facilityProviders.single.isPrimary, isTrue);
    });
  });

  group('AdminFacilityProvider departments via RPC', () {
    test('addDepartment calls facility_admin_add_department, not a raw insert', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_add_department', <String, dynamic>{});
      fake.routeJson('/rest/v1/departments', [deptRow()]);

      final provider = AdminFacilityProvider();
      final ok = await provider.addDepartment({
        'facility_id': 'f1',
        'name': 'Cardiology',
        'description': 'Heart care',
      });

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_add_department').single;
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
      expect(rpcCall.body, contains('"department_name":"Cardiology"'));
      expect(fake.requestsTo('POST', '/departments'), isEmpty);
    });

    test('updateDepartment calls facility_admin_update_department and reloads', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_update_department', <String, dynamic>{});
      fake.routeJson('/rest/v1/departments', [deptRow(id: 'd1')]);

      final provider = AdminFacilityProvider();
      final ok = await provider.updateDepartment('d1', 'f1', 'Cardiology', 'Updated');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_update_department').single;
      expect(rpcCall.body, contains('"target_department_id":"d1"'));
    });
  });

  group('AdminFacilityProvider facility admins', () {
    test('loadFacilityAdmins merges facility_admins with user names', () async {
      fake.routeJson('/rest/v1/facility_admins', [
        {'user_id': 'u1', 'facility_id': 'f1', 'created_at': '2026-01-01T09:00:00.000Z'},
      ]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'u1', 'full_name': 'Jane Front-Desk', 'email': 'jane@example.com'},
      ]);

      final provider = AdminFacilityProvider();
      await provider.loadFacilityAdmins('f1');

      expect(provider.facilityAdmins, hasLength(1));
      expect(provider.facilityAdmins.first['full_name'], 'Jane Front-Desk');
    });

    test('searchPatientsForFacilityAdmin only queries patients', () async {
      fake.routeJson('/rest/v1/users', [
        {'id': 'u1', 'full_name': 'Jane Doe', 'email': 'jane@example.com'},
      ]);

      final provider = AdminFacilityProvider();
      await provider.searchPatientsForFacilityAdmin('jane');

      final req = fake.requestsTo('GET', 'users').single;
      expect(req.url.queryParameters['role'], 'eq.patient');
      expect(provider.patientSearchResults, hasLength(1));
    });

    test('grantFacilityAdmin calls the admin RPC and reloads', () async {
      fake.routeJson('/rest/v1/rpc/admin_grant_facility_admin', <String, dynamic>{});
      fake.routeJson('/rest/v1/facility_admins', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      final ok = await provider.grantFacilityAdmin('u1', 'f1');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/admin_grant_facility_admin').single;
      expect(rpcCall.body, contains('"target_user_id":"u1"'));
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
    });

    test('revokeFacilityAdmin calls the admin RPC and reloads', () async {
      fake.routeJson('/rest/v1/rpc/admin_revoke_facility_admin', <String, dynamic>{});
      fake.routeJson('/rest/v1/facility_admins', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      final ok = await provider.revokeFacilityAdmin('u1', 'f1');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/admin_revoke_facility_admin').single;
      expect(rpcCall.body, contains('"target_user_id":"u1"'));
    });
  });

  group('AdminFacilityProvider.loadFacilityAppointments', () {
    test('merges appointments with patient and provider names', () async {
      fake.routeJson('/rest/v1/appointments', [
        {
          'id': 'a1',
          'patient_id': 'p1',
          'provider_id': 'd1',
          'scheduled_at': '2026-01-05T09:00:00.000Z',
          'type': 'in-person',
          'status': 'confirmed',
        },
      ]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Jane Doe'},
        {'id': 'd1', 'full_name': 'Dr. Mwangi'},
      ]);

      final provider = AdminFacilityProvider();
      await provider.loadFacilityAppointments('f1');

      expect(provider.facilityAppointments, hasLength(1));
      expect(provider.facilityAppointments.first['patient_name'], 'Jane Doe');
      expect(provider.facilityAppointments.first['provider_name'], 'Dr. Mwangi');
      expect(provider.facilityAppointments.first['status'], 'confirmed');

      final req = fake.requestsTo('GET', 'appointments').single;
      expect(req.url.queryParameters['facility_id'], 'eq.f1');
    });

    test('empty facility has no appointments, no crash', () async {
      fake.routeJson('/rest/v1/appointments', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      await provider.loadFacilityAppointments('f1');

      expect(provider.facilityAppointments, isEmpty);
    });
  });

  Map<String, dynamic> drugStockRow({
    String id = 'ds1',
    String facilityId = 'f1',
    String drugName = 'Amoxicillin 250mg',
    int quantityOnHand = 8,
    int reorderThreshold = 20,
  }) {
    return {
      'id': id,
      'facility_id': facilityId,
      'drug_name': drugName,
      'batch_number': 'B123',
      'expiry_date': '2027-03-01',
      'quantity_on_hand': quantityOnHand,
      'reorder_threshold': reorderThreshold,
      'created_by': null,
      'created_at': '2026-01-01T09:00:00.000Z',
      'updated_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('AdminFacilityProvider.loadDrugStock', () {
    test('maps rows for a facility', () async {
      fake.routeJson('/rest/v1/facility_drug_stock', [drugStockRow()]);

      final provider = AdminFacilityProvider();
      await provider.loadDrugStock('f1');

      expect(provider.error, isNull);
      expect(provider.drugStock, hasLength(1));
      expect(provider.drugStock.first.drugName, 'Amoxicillin 250mg');
      expect(provider.drugStock.first.stockLevelStatus, 'warning');
    });

    test('empty facility has no stock, no crash', () async {
      fake.routeJson('/rest/v1/facility_drug_stock', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      await provider.loadDrugStock('f1');

      expect(provider.drugStock, isEmpty);
    });
  });

  group('AdminFacilityProvider.receiveStock', () {
    test('calls facility_admin_receive_stock, not a raw insert', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_receive_stock', 'ds1');

      final provider = AdminFacilityProvider();
      final id = await provider.receiveStock(
        facilityId: 'f1',
        drugName: 'Amoxicillin 250mg',
        quantity: 50,
      );

      expect(id, 'ds1');
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_receive_stock').single;
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
      expect(rpcCall.body, contains('"new_drug_name":"Amoxicillin 250mg"'));
      expect(rpcCall.body, contains('"received_quantity":50'));
      expect(fake.requestsTo('POST', '/facility_drug_stock'), isEmpty);
    });

    test('RPC failure surfaces the error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_receive_stock',
        http.Response('{"message":"Only an admin of this facility can receive stock here"}', 400),
      );

      final provider = AdminFacilityProvider();
      final id = await provider.receiveStock(facilityId: 'f2', drugName: 'X', quantity: 1);

      expect(id, isNull);
      expect(provider.error, isNotNull);
    });
  });

  group('AdminFacilityProvider.dispensePrescription', () {
    test('calls facility_admin_dispense_prescription, not a raw update', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_dispense_prescription', null);

      final provider = AdminFacilityProvider();
      final ok = await provider.dispensePrescription(prescriptionId: 'rx1');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_dispense_prescription').single;
      expect(rpcCall.body, contains('"target_prescription_id":"rx1"'));
      expect(rpcCall.body, contains('"dispensed_quantity":1'));
      expect(fake.requestsTo('PATCH', '/facility_drug_stock'), isEmpty);
      expect(fake.requestsTo('PATCH', '/visit_prescriptions'), isEmpty);
    });

    test('insufficient-stock RPC failure surfaces via provider.error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_dispense_prescription',
        http.Response('{"message":"Insufficient stock: only 0 unit(s) on hand"}', 400),
      );

      final provider = AdminFacilityProvider();
      final ok = await provider.dispensePrescription(prescriptionId: 'rx1');

      expect(ok, isFalse);
      expect(provider.error, contains('Insufficient stock'));
    });
  });

  Map<String, dynamic> wardRow({
    String id = 'w1',
    String facilityId = 'f1',
    String name = 'Ward A — Maternity',
    int totalBeds = 20,
  }) {
    return {
      'id': id,
      'facility_id': facilityId,
      'name': name,
      'total_beds': totalBeds,
      'created_by': null,
      'created_at': '2026-01-01T09:00:00.000Z',
      'updated_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('AdminFacilityProvider.loadWards', () {
    test('maps rows for a facility', () async {
      fake.routeJson('/rest/v1/wards', [wardRow()]);

      final provider = AdminFacilityProvider();
      await provider.loadWards('f1');

      expect(provider.error, isNull);
      expect(provider.wards, hasLength(1));
      expect(provider.wards.first.name, 'Ward A — Maternity');
      expect(provider.wards.first.totalBeds, 20);
    });

    test('empty facility has no wards, no crash', () async {
      fake.routeJson('/rest/v1/wards', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      await provider.loadWards('f1');

      expect(provider.wards, isEmpty);
    });
  });

  group('AdminFacilityProvider.addWard', () {
    test('calls facility_admin_add_ward, not a raw insert', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_add_ward', 'w1');

      final provider = AdminFacilityProvider();
      final ok = await provider.addWard(facilityId: 'f1', name: 'Ward A', totalBeds: 20);

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_add_ward').single;
      expect(rpcCall.body, contains('"target_facility_id":"f1"'));
      expect(rpcCall.body, contains('"ward_name":"Ward A"'));
      expect(rpcCall.body, contains('"ward_total_beds":20'));
      expect(fake.requestsTo('POST', '/wards'), isEmpty);
    });

    test('RPC failure surfaces the error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_add_ward',
        http.Response('{"message":"Only an admin of this facility can add a ward"}', 400),
      );

      final provider = AdminFacilityProvider();
      final ok = await provider.addWard(facilityId: 'f2', name: 'X', totalBeds: 1);

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('AdminFacilityProvider.updateWard', () {
    test('calls facility_admin_update_ward, not a raw update', () async {
      fake.routeJson('/rest/v1/rpc/facility_admin_update_ward', null);

      final provider = AdminFacilityProvider();
      final ok = await provider.updateWard(wardId: 'w1', name: 'Ward A', totalBeds: 25);

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/facility_admin_update_ward').single;
      expect(rpcCall.body, contains('"target_ward_id":"w1"'));
      expect(rpcCall.body, contains('"ward_total_beds":25'));
      expect(fake.requestsTo('PATCH', '/wards'), isEmpty);
    });

    test('capacity-shrink-rejection failure surfaces via provider.error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/facility_admin_update_ward',
        http.Response('{"message":"Cannot reduce capacity below currently occupied beds (5 occupied)"}', 400),
      );

      final provider = AdminFacilityProvider();
      final ok = await provider.updateWard(wardId: 'w1', name: 'Ward A', totalBeds: 1);

      expect(ok, isFalse);
      expect(provider.error, contains('occupied beds'));
    });
  });

  group('AdminFacilityProvider.loadRecentActivity', () {
    test('maps rows for a facility', () async {
      fake.routeJson('/rest/v1/audit_log', [
        {
          'id': 'al1',
          'action': 'patient_admitted',
          'user_id': 'u1',
          'details': {'facility_id': 'f1', 'visit_id': 'v1', 'admission_id': 'ad1', 'ward_id': 'w1'},
          'timestamp': '2026-01-02T09:00:00.000Z',
        },
      ]);

      final provider = AdminFacilityProvider();
      await provider.loadRecentActivity('f1');

      expect(provider.error, isNull);
      expect(provider.recentActivity, hasLength(1));
      expect(provider.recentActivity.first.action, 'patient_admitted');
      expect(provider.recentActivity.first.details['ward_id'], 'w1');

      final req = fake.requestsTo('GET', 'audit_log').single;
      expect(req.url.queryParameters['details->>facility_id'], 'eq.f1');
    });

    test('empty facility has no activity, no crash', () async {
      fake.routeJson('/rest/v1/audit_log', <Map<String, dynamic>>[]);

      final provider = AdminFacilityProvider();
      await provider.loadRecentActivity('f1');

      expect(provider.error, isNull);
      expect(provider.recentActivity, isEmpty);
    });

    test('server error records error', () async {
      fake.routeRaw(
        '/rest/v1/audit_log',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = AdminFacilityProvider();
      await provider.loadRecentActivity('f1');

      expect(provider.error, isNotNull);
    });
  });
}
