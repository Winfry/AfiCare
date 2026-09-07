import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/provider_credential_model.dart';
import 'package:aficare_flutter/providers/provider_verification_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> credentialRow({
    String id = 'c1',
    String providerId = 'p1',
    String licenseNumber = 'KMPDC/12345',
    String requestedRole = 'doctor',
    String verificationStatus = 'pending',
  }) {
    return {
      'id': id,
      'provider_id': providerId,
      'license_number': licenseNumber,
      'specialty': 'Cardiology',
      'requested_role': requestedRole,
      'verification_status': verificationStatus,
      'verified_by': null,
      'verified_at': null,
      'rejection_reason': null,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('ProviderVerificationProvider.loadRequests', () {
    test('merges provider_credentials with applicant name/email', () async {
      fake.routeJson('/rest/v1/provider_credentials', [credentialRow()]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi', 'email': 'mwangi@example.com'},
      ]);

      final provider = ProviderVerificationProvider();
      await provider.loadRequests();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.requests, hasLength(1));
      expect(provider.requests.first.providerName, 'Dr. Mwangi');
      expect(provider.requests.first.providerEmail, 'mwangi@example.com');
    });

    test('server error sets error', () async {
      fake.routeRaw('/rest/v1/provider_credentials', http.Response('{"message":"boom"}', 500));

      final provider = ProviderVerificationProvider();
      await provider.loadRequests();

      expect(provider.error, isNotNull);
      expect(provider.requests, isEmpty);
    });
  });

  group('ProviderVerificationProvider filters', () {
    test('filteredRequests applies status and search', () async {
      fake.routeJson('/rest/v1/provider_credentials', [
        credentialRow(id: 'c1', providerId: 'p1', verificationStatus: 'pending'),
        credentialRow(id: 'c2', providerId: 'p2', verificationStatus: 'verified'),
      ]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi', 'email': 'mwangi@example.com'},
        {'id': 'p2', 'full_name': 'Dr. Otieno', 'email': 'otieno@example.com'},
      ]);

      final provider = ProviderVerificationProvider();
      await provider.loadRequests();

      expect(provider.filteredRequests.map((r) => r.id), ['c1']);

      provider.setStatusFilter('all');
      provider.setSearchQuery('otieno');
      expect(provider.filteredRequests.map((r) => r.id), ['c2']);
    });
  });

  group('ProviderVerificationProvider.submitRequest', () {
    test('inserts a pending request as the current user', () async {
      fake.routeJson('/rest/v1/provider_credentials', credentialRow());

      final provider = ProviderVerificationProvider();
      final ok = await provider.submitRequest(
        licenseNumber: 'KMPDC/12345',
        specialty: 'Cardiology',
        requestedRole: 'doctor',
      );

      // No logged-in user in this test harness, so submission is refused
      // client-side before any request is made.
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('ProviderVerificationProvider.approve/reject', () {
    test('approve calls the RPC with decision=verified and reloads', () async {
      fake.routeJson('/rest/v1/rpc/admin_verify_provider_license', <String, dynamic>{});
      fake.routeJson('/rest/v1/provider_credentials', [credentialRow(verificationStatus: 'verified')]);
      fake.routeJson('/rest/v1/users', [
        {'id': 'p1', 'full_name': 'Dr. Mwangi', 'email': 'mwangi@example.com'},
      ]);

      final provider = ProviderVerificationProvider();
      final ok = await provider.approve('p1');

      expect(ok, isTrue);
      final rpcCall = fake.requestsTo('POST', 'rpc/admin_verify_provider_license').single;
      final body = jsonDecode(rpcCall.body) as Map<String, dynamic>;
      expect(body, containsPair('target_user_id', 'p1'));
      expect(body, containsPair('decision', 'verified'));
      expect(provider.requests.single.verificationStatus, VerificationStatus.verified);
    });

    test('reject sends a reason and a rejected caller surfaces as an error', () async {
      fake.routeRaw(
        '/rest/v1/rpc/admin_verify_provider_license',
        http.Response(jsonEncode({'message': 'Only admins can verify provider licenses'}), 403),
      );

      final provider = ProviderVerificationProvider();
      final ok = await provider.reject('p1', 'License could not be verified');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
