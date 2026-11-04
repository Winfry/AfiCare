import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:aficare_flutter/models/dependent_profile_model.dart';
import 'package:aficare_flutter/models/message_model.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/providers/dependent_provider.dart';
import 'package:aficare_flutter/providers/message_provider.dart';
import 'package:aficare_flutter/screens/patient/messages_screen.dart';
import 'package:aficare_flutter/screens/patient/patient_nav.dart';

import 'helpers/fake_supabase.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'mary',
        email: 'mary@example.com',
        fullName: 'Mary Wanjiru',
        role: UserRole.patient,
        createdAt: DateTime(2026, 1, 1),
      );
}

/// Mary, looking at her son Brian's profile.
class _OnBrian extends DependentProvider {
  static final brian = DependentProfileModel(
    id: 'brian',
    guardianId: 'mary',
    fullName: 'Brian Otieno',
    relationship: 'child',
    createdAt: DateTime(2026, 1, 1),
  );

  @override
  String? get ownId => 'mary';
  @override
  String? get activePatientId => 'brian';
  @override
  bool get isViewingDependent => true;
  @override
  DependentProfileModel? get activeDependent => brian;
}

Map<String, dynamic> _sent(Map body) => {
      'id': 'new-1',
      'sender_id': body['sender_id'],
      'receiver_id': body['receiver_id'],
      'patient_id': body['patient_id'],
      'content': body['content'],
      'message_type': 'text',
      'read': false,
      'created_at': '2026-11-03T06:00:00Z',
    };

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Future<void> pump(WidgetTester tester, {String? to, String? name, String? about, Size size = const Size(1400, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<DependentProvider>(create: (_) => _OnBrian()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(body: MessagesScreen(openWithId: to, openWithName: name, aboutPatientId: about)),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('"Message" on Brian\'s doctor opens that chat, ready to type, and the message is about Brian',
      (tester) async {
    fake.routeJson('/rest/v1/messages', <Object?>[]);
    await pump(tester, to: 'kamau', name: 'Dr Kamau', about: 'brian');

    expect(find.text('Dr Kamau'), findsWidgets);
    expect(find.textContaining('Write your first message to Dr Kamau'), findsOneWidget);
    expect(find.textContaining('call 999 or 112'), findsOneWidget);

    // The insert returns the saved row.
    fake.routeJson('/rest/v1/messages', {
      ..._sent({'sender_id': 'mary', 'receiver_id': 'kamau', 'patient_id': 'brian', 'content': 'Brian has a fever'}),
    });
    await typeAndSend(tester, 'Brian has a fever');

    final post = fake.requestsTo('POST', '/rest/v1/messages').single;
    final body = jsonDecode(post.body) as Map;
    expect(body['sender_id'], 'mary');
    expect(body['receiver_id'], 'kamau');
    expect(body['patient_id'], 'brian');
    expect(body['content'], 'Brian has a fever');
    expect(find.text('Brian has a fever'), findsOneWidget);
  });

  testWidgets('if a message cannot be sent she is told, and her words stay in the box', (tester) async {
    fake.routeJson('/rest/v1/messages', <Object?>[]);
    await pump(tester, to: 'kamau', name: 'Dr Kamau');

    fake.routeRaw('/rest/v1/messages',
        http.Response('{"message":"new row violates row-level security"}', 403,
            headers: {'content-type': 'application/json'}));
    await typeAndSend(tester, 'Are you open on Saturday?');

    expect(find.textContaining("Your message wasn't sent"), findsOneWidget);
    expect(find.textContaining('row-level security'), findsNothing);
    final box = tester.widget<TextField>(find.byType(TextField).last);
    expect(box.controller!.text, 'Are you open on Saturday?');
  });

  testWidgets('New message lists who she can write to, and opens that chat about the right child', (tester) async {
    fake.routeJson('/rest/v1/messages', <Object?>[]);
    fake.routeJson('/rest/v1/rpc/message_contacts', [
      {
        'user_id': 'kamau',
        'full_name': 'Dr Kamau',
        'role': 'doctor',
        'cares_for': ['brian'],
        'cares_for_names': ['Brian Otieno'],
      },
      {
        'user_id': 'wambui',
        'full_name': 'Nurse Wambui',
        'role': 'nurse',
        'cares_for': ['mary'],
        'cares_for_names': ['Mary Wanjiru'],
      },
    ]);
    await pump(tester);

    expect(find.text('No messages yet'), findsOneWidget);
    await tester.tap(find.text('New message').first);
    await tester.pumpAndSettle();

    expect(find.text('Doctor · Looks after Brian Otieno'), findsOneWidget);
    expect(find.text('Nurse · Looks after Mary Wanjiru'), findsOneWidget);

    await tester.tap(find.text('Dr Kamau'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Write your first message to Dr Kamau'), findsOneWidget);

    fake.routeJson('/rest/v1/messages',
        _sent({'sender_id': 'mary', 'receiver_id': 'kamau', 'patient_id': 'brian', 'content': 'Hello'}));
    await typeAndSend(tester, 'Hello');
    final body = jsonDecode(fake.requestsTo('POST', '/rest/v1/messages').single.body) as Map;
    expect(body['receiver_id'], 'kamau');
    expect(body['patient_id'], 'brian', reason: 'she is on Brian\'s profile and Dr Kamau looks after him');
  });

  testWidgets('with nobody to write to yet, it says how that changes', (tester) async {
    fake.routeJson('/rest/v1/messages', <Object?>[]);
    fake.routeJson('/rest/v1/rpc/message_contacts', <Object?>[]);
    await pump(tester);

    await tester.tap(find.text('Write a message'));
    await tester.pumpAndSettle();
    expect(find.text('No one to message yet'), findsOneWidget);
    expect(find.textContaining('appointment or a visit'), findsOneWidget);
  });

  testWidgets('on a phone the chat opens on its own screen, and Back returns to the list', (tester) async {
    fake.routeJson('/rest/v1/messages', <Object?>[]);
    await pump(tester, to: 'kamau', name: 'Dr Kamau', size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Write your first message to Dr Kamau'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
  });

  test('the Message buttons link to a chat with that clinician', () {
    expect(PatientRoutes.messageTo('kamau', name: 'Dr Kamau', patientId: 'brian'),
        '/patient/messages?to=kamau&name=Dr+Kamau&about=brian');
    expect(PatientRoutes.messageTo('kamau'), '/patient/messages?to=kamau');
  });

  test('message times are shown in local time', () {
    final m = MessageModel.fromJson({
      'id': 'm',
      'sender_id': 'a',
      'receiver_id': 'b',
      'content': 'x',
      'created_at': '2026-11-03T06:00:00Z',
    });
    expect(m.createdAt.isUtc, isFalse);
    expect(m.createdAt, DateTime.utc(2026, 11, 3, 6).toLocal());
  });
}
