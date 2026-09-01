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
      await provider.loadFacilities();

      provider.setTypeFilter('clinic');
      expect(provider.filteredFacilities.map((f) => f.id), ['f2']);

      provider.setTypeFilter('all');
      provider.setSearchQuery('nairobi');
      expect(provider.filteredFacilities.map((f) => f.id), ['f2']);
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
}
