import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';
import '../models/user_model.dart';

class MessageProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ConversationSummary> _conversations = [];
  List<MessageModel> _thread = [];
  final Map<String, UserModel> _userCache = {};
  bool _isLoading = false;
  bool _isThreadLoading = false;
  String? _error;

  List<ConversationSummary> get conversations => _conversations;
  List<MessageModel> get thread => _thread;
  bool get isLoading => _isLoading;
  bool get isThreadLoading => _isThreadLoading;
  String? get error => _error;

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Build a conversation list for [userId] by grouping all messages
  /// where the user is sender or receiver, keyed by the counterpart.
  Future<void> loadConversations(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final messages = (response as List)
          .map((j) => MessageModel.fromJson(j as Map<String, dynamic>))
          .toList();

      // Group by counterpart, keeping the latest message per counterpart.
      final Map<String, List<MessageModel>> grouped = {};
      for (final m in messages) {
        final counterpart = m.senderId == userId ? m.receiverId : m.senderId;
        grouped.putIfAbsent(counterpart, () => []).add(m);
      }

      // Resolve counterpart names.
      final counterpartIds = grouped.keys.toList();
      await _cacheUsers(counterpartIds);

      final summaries = <ConversationSummary>[];
      grouped.forEach((counterpartId, msgs) {
        msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latest = msgs.first;
        final unread = msgs
            .where((m) => m.receiverId == userId && !m.read)
            .length;
        final user = _userCache[counterpartId];
        summaries.add(ConversationSummary(
          counterpartId: counterpartId,
          counterpartName: user?.fullName ?? 'Unknown',
          counterpartRole: user?.role.name,
          lastMessage: latest.content,
          lastMessageAt: latest.createdAt,
          unreadCount: unread,
        ));
      });

      summaries.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      _conversations = summaries;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load the full message thread between [userId] and [counterpartId].
  Future<void> loadThread(String userId, String counterpartId) async {
    _isThreadLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId,receiver_id.eq.$counterpartId),and(sender_id.eq.$counterpartId,receiver_id.eq.$userId)')
          .order('created_at', ascending: true);

      _thread = (response as List)
          .map((j) => MessageModel.fromJson(j as Map<String, dynamic>))
          .toList();

      _isThreadLoading = false;
      notifyListeners();

      // Fire-and-forget: mark incoming messages as read.
      _markThreadRead(userId, counterpartId);
    } catch (e) {
      _error = e.toString();
      _isThreadLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? patientId,
    MessageType type = MessageType.text,
    String? referenceId,
  }) async {
    try {
      final data = {
        'sender_id': senderId,
        'receiver_id': receiverId,
        'patient_id': patientId,
        'content': content,
        'message_type': MessageModel(
          id: '',
          senderId: senderId,
          receiverId: receiverId,
          content: content,
          messageType: type,
          createdAt: DateTime.now(),
        ).toJson()['message_type'],
        'reference_id': referenceId,
      };
      final inserted =
          await _supabase.from('messages').insert(data).select().single();
      _thread.add(MessageModel.fromJson(inserted));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _markThreadRead(String userId, String counterpartId) async {
    try {
      await _supabase
          .from('messages')
          .update({'read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', userId)
          .eq('sender_id', counterpartId)
          .eq('read', false);
    } catch (_) {
      // Non-critical.
    }
  }

  Future<void> _cacheUsers(List<String> ids) async {
    final missing = ids.where((id) => !_userCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final response =
          await _supabase.from('users').select().inFilter('id', missing);
      for (final j in (response as List)) {
        final user = UserModel.fromJson(j as Map<String, dynamic>);
        _userCache[user.id] = user;
      }
    } catch (_) {
      // Leave uncached; names show as Unknown.
    }
  }

  UserModel? cachedUser(String id) => _userCache[id];
}
