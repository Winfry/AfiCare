import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aficare_flutter/services/avatar_storage.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AvatarStorage', () {
    test('get returns null when nothing is stored', () async {
      expect(await AvatarStorage.get(patientId: 'p1', providerId: 'prov1'),
          isNull);
    });

    test('set then get round-trips the asset path', () async {
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov1', assetPath: 'assets/a.png');

      expect(
          await AvatarStorage.get(patientId: 'p1', providerId: 'prov1'),
          'assets/a.png');
    });

    test('choices are isolated per provider', () async {
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov1', assetPath: 'assets/a.png');
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov2', assetPath: 'assets/b.png');

      expect(
          await AvatarStorage.get(patientId: 'p1', providerId: 'prov1'),
          'assets/a.png');
      expect(
          await AvatarStorage.get(patientId: 'p1', providerId: 'prov2'),
          'assets/b.png');
    });

    test('clear removes only the given patient/provider pair', () async {
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov1', assetPath: 'assets/a.png');
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov2', assetPath: 'assets/b.png');

      await AvatarStorage.clear(patientId: 'p1', providerId: 'prov1');

      expect(
          await AvatarStorage.get(patientId: 'p1', providerId: 'prov1'),
          isNull);
      expect(
          await AvatarStorage.get(patientId: 'p1', providerId: 'prov2'),
          'assets/b.png');
    });

    test('getAll aggregates only the given patient choices', () async {
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov1', assetPath: 'assets/a.png');
      await AvatarStorage.set(
          patientId: 'p1', providerId: 'prov2', assetPath: 'assets/b.png');
      await AvatarStorage.set(
          patientId: 'p2', providerId: 'prov1', assetPath: 'assets/c.png');

      final choices = await AvatarStorage.getAll(patientId: 'p1');

      expect(choices, {'prov1': 'assets/a.png', 'prov2': 'assets/b.png'});
    });
  });
}