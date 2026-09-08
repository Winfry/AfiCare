import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/providers/facility_admin_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  group('FacilityAdminProvider.loadMyFacility', () {
    test('does nothing when nobody is logged in (no crash)', () async {
      final provider = FacilityAdminProvider();
      await provider.loadMyFacility();

      // No Supabase session exists in this test harness, so the provider
      // must bail out quietly rather than attempt a request.
      expect(provider.myFacility, isNull);
      expect(fake.requestsTo('GET', 'facility_admins'), isEmpty);
    });
  });
}
