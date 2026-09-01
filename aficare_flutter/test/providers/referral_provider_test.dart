import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/referral_model.dart';
import 'package:aficare_flutter/providers/referral_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> referralRow({
    String id = 'r1',
    String patientId = 'p1',
    String fromProviderId = 'prov-1',
    String status = 'pending',
    String urgency = 'urgent',
    String reason = 'Chest pain',
    String createdAt = '2026-04-01T09:00:00.000Z',
  }) {
    return {
      'id': id,
      'patient_id': patientId,
      'from_provider_id': fromProviderId,
      'from_facility': 'Clinic A',
      'to_facility': 'Hospital B',
      'to_department': 'Cardiology',
      'to_specialist': 'Dr. X',
      'reason': reason,
      'clinical_notes': null,
      'urgency': urgency,
      'status': status,
      'notes': null,
      'responded_at': null,
      'response_notes': null,
      'created_at': createdAt,
    };
  }

  group('ReferralProvider.loadPatientReferrals', () {
    test('populates referrals for a patient', () async {
      fake.routeJson('/rest/v1/referrals', [
        referralRow(),
        referralRow(id: 'r2', reason: 'Shortness of breath', status: 'completed'),
      ]);

      final provider = ReferralProvider();
      await provider.loadPatientReferrals('p1');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.referrals, hasLength(2));
      expect(provider.referrals.first.patientId, 'p1');
      expect(provider.referrals.first.urgency, ReferralUrgency.urgent);
    });

    test('empty response leaves an empty list', () async {
      fake.routeJson('/rest/v1/referrals', <Object?>[]);

      final provider = ReferralProvider();
      await provider.loadPatientReferrals('p1');

      expect(provider.referrals, isEmpty);
      expect(provider.error, isNull);
    });
  });

  group('ReferralProvider.loadProviderReferrals', () {
    test('populates referrals sent by a provider', () async {
      fake.routeJson('/rest/v1/referrals', [
        referralRow(fromProviderId: 'prov-1'),
        referralRow(id: 'r2', fromProviderId: 'prov-1'),
      ]);

      final provider = ReferralProvider();
      await provider.loadProviderReferrals('prov-1');

      expect(provider.referrals, hasLength(2));
      expect(provider.referrals.every((r) => r.fromProviderId == 'prov-1'), isTrue);
    });
  });

  group('ReferralProvider.submitReferral', () {
    test('inserts the exact schema columns and prepends locally', () async {
      fake.routeJson('/rest/v1/referrals', <String, dynamic>{});

      final provider = ReferralProvider();
      final referral = ReferralModel(
        id: 'new-1',
        patientId: 'p1',
        fromProviderId: 'prov-1',
        fromFacility: 'Clinic A',
        toFacility: 'Hospital B',
        toDepartment: 'Cardiology',
        toSpecialist: 'Dr. X',
        reason: 'Chest pain',
        clinicalNotes: 'echo needed',
        urgency: ReferralUrgency.emergency,
        status: ReferralStatus.pending,
        createdAt: DateTime.utc(2026, 4, 1),
      );

      final ok = await provider.submitReferral(referral);

      expect(ok, isTrue);
      expect(provider.error, isNull);
      expect(provider.referrals.first, same(referral));

      final insert = fake.requestsTo('POST', 'referrals').last;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;

      // The columns the A3 migration (008) must provide.
      expect(body, containsPair('patient_id', 'p1'));
      expect(body, containsPair('from_provider_id', 'prov-1'));
      expect(body, containsPair('from_facility', 'Clinic A'));
      expect(body, containsPair('to_facility', 'Hospital B'));
      expect(body, containsPair('to_department', 'Cardiology'));
      expect(body, containsPair('to_specialist', 'Dr. X'));
      expect(body, containsPair('reason', 'Chest pain'));
      expect(body, containsPair('clinical_notes', 'echo needed'));
      expect(body, containsPair('urgency', 'emergency'));
      expect(body, containsPair('status', 'pending'));
      expect(body, containsPair('created_at', isNotNull));
    });

    test('failure returns false and records an error', () async {
      fake.routeRaw(
        '/rest/v1/referrals',
        http.Response('{"message":"constraint violation"}', 409),
      );

      final provider = ReferralProvider();
      final referral = ReferralModel(
        id: 'new-1',
        patientId: 'p1',
        fromProviderId: 'prov-1',
        toFacility: 'Hospital B',
        reason: 'Chest pain',
        createdAt: DateTime.utc(2026, 4, 1),
      );

      final ok = await provider.submitReferral(referral);

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('ReferralProvider.updateReferralStatus', () {
    test('updates status, response fields, and the local list', () async {
      fake.routeJson('/rest/v1/referrals', [referralRow()]);

      final provider = ReferralProvider();
      await provider.loadPatientReferrals('p1');

      final ok = await provider.updateReferralStatus(
        'r1',
        ReferralStatus.completed,
        responseNotes: 'Seen by cardiologist',
      );

      expect(ok, isTrue);
      final updated = provider.referrals.first;
      expect(updated.status, ReferralStatus.completed);
      expect(updated.responseNotes, 'Seen by cardiologist');
      expect(updated.respondedAt, isNotNull);

      final patch = fake.requestsTo('PATCH', 'referrals').last;
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['status'], 'completed');
      expect(body['response_notes'], 'Seen by cardiologist');
      expect(body['responded_at'], isNotNull);
    });

    test('failure returns false without mutating the local list', () async {
      fake.routeJson('/rest/v1/referrals', [referralRow()]);

      final provider = ReferralProvider();
      await provider.loadPatientReferrals('p1');

      // Only fail the subsequent PATCH (the load already happened above).
      fake.routeRaw(
        '/rest/v1/referrals',
        http.Response('{"message":"boom"}', 500),
      );

      final ok = await provider.updateReferralStatus(
        'r1',
        ReferralStatus.declined,
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.referrals.first.status, ReferralStatus.pending);
    });
  });
}