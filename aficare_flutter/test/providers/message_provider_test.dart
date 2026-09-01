import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/providers/message_provider.dart';

import '../helpers/fake_supabase.dart';

void main() {
  final fake = FakeSupabase();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initSupabase(fake);
  });

  setUp(() => fake.reset());

  Map<String, dynamic> msg({
    String id = 'm1',
    required String senderId,
    required String receiverId,
    String content = 'Hello',
    bool read = false,
    String createdAt = '2026-06-01T09:00:00.000Z',
  }) {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'patient_id': null,
      'content': content,
      'message_type': 'text',
      'reference_id': null,
      'read': read,
      'read_at': null,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> userRow({
    String id = 'u2',
    String fullName = 'Doctor Smith',
    String role = 'doctor',
  }) {
    return {
      'id': id,
      'email': 'u$id@example.com',
      'full_name': fullName,
      'role': role,
      'status': 'active',
      'medilink_id': null,
      'created_at': '2026-01-01T09:00:00.000Z',
    };
  }

  group('MessageProvider.loadConversations', () {
    test('groups by counterpart, resolves names and counts unread', () async {
      fake.routeJson('/rest/v1/messages', [
        msg(id: 'm1', senderId: 'u2', receiverId: 'me', content: 'Hi', read: false),
        msg(id: 'm2', senderId: 'u2', receiverId: 'me', content: 'Followup', read: false, createdAt: '2026-06-01T10:00:00.000Z'),
        msg(id: 'm3', senderId: 'me', receiverId: 'u3', content: 'Outgoing', read: true),
      ]);
      fake.routeJson('/rest/v1/users', [userRow(), userRow(id: 'u3', fullName: 'Nurse Ann', role: 'nurse')]);

      final provider = MessageProvider();
      await provider.loadConversations('me');

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.conversations, hasLength(2));
      expect(provider.totalUnread, 2);

      final withU2 = provider.conversations
          .firstWhere((c) => c.counterpartId == 'u2');
      expect(withU2.counterpartName, 'Doctor Smith');
      expect(withU2.counterpartRole, UserRole.doctor.name);
      expect(withU2.unreadCount, 2);
      expect(withU2.lastMessage, 'Followup');

      final withU3 = provider.conversations
          .firstWhere((c) => c.counterpartId == 'u3');
      expect(withU3.unreadCount, 0);
      expect(withU3.counterpartName, 'Nurse Ann');
    });

    test('uses Unknown name when counterpart is not cached', () async {
      fake.routeJson('/rest/v1/messages', [
        msg(id: 'm1', senderId: 'ghost', receiverId: 'me'),
      ]);
      fake.routeJson('/rest/v1/users', <Object?>[]);

      final provider = MessageProvider();
      await provider.loadConversations('me');

      final c = provider.conversations.single;
      expect(c.counterpartName, 'Unknown');
      expect(c.unreadCount, 1);
    });

    test('server error sets error', () async {
      fake.routeRaw(
        '/rest/v1/messages',
        http.Response('{"message":"boom"}', 500),
      );

      final provider = MessageProvider();
      await provider.loadConversations('me');

      expect(provider.error, isNotNull);
      expect(provider.conversations, isEmpty);
    });
  });

  group('MessageProvider.loadThread', () {
    test('loads and marks incoming as read (fire-and-forget)', () async {
      fake.routeJson('/rest/v1/messages', [
        msg(id: 'm1', senderId: 'u2', receiverId: 'me'),
        msg(id: 'm2', senderId: 'me', receiverId: 'u2'),
      ]);

      final provider = MessageProvider();
      await provider.loadThread('me', 'u2');

      expect(provider.isThreadLoading, isFalse);
      expect(provider.thread, hasLength(2));
      expect(provider.error, isNull);

      // _markThreadRead is fire-and-forget; give it a beat to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final update = fake.requestsTo('PATCH', 'messages').first;
      expect(update.url.queryParameters['receiver_id'], 'eq.me');
      expect(update.url.queryParameters['sender_id'], 'eq.u2');
    });
  });

  group('MessageProvider.sendMessage', () {
    test('inserts and appends the returned message', () async {
      fake.routeJson('/rest/v1/messages', {
        'id': 'm-new',
        'sender_id': 'me',
        'receiver_id': 'u2',
        'content': 'Hello doc',
        'message_type': 'text',
        'read': false,
        'created_at': '2026-06-01T09:00:00.000Z',
      });

      final provider = MessageProvider();
      final ok = await provider.sendMessage(
        senderId: 'me',
        receiverId: 'u2',
        content: 'Hello doc',
      );

      expect(ok, isTrue);
      final insert = fake.requestsTo('POST', 'messages').single;
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body, containsPair('sender_id', 'me'));
      expect(body, containsPair('receiver_id', 'u2'));
      expect(body, containsPair('message_type', 'text'));
      expect(body.containsKey('id'), isFalse);

      expect(provider.thread, hasLength(1));
      expect(provider.thread.single.content, 'Hello doc');
    });
  });
}
