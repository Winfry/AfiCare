import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../models/message_model.dart';
import '../../utils/theme.dart';

class ProviderInboxScreen extends StatefulWidget {
  const ProviderInboxScreen({super.key});

  @override
  State<ProviderInboxScreen> createState() => _ProviderInboxScreenState();
}

class _ProviderInboxScreenState extends State<ProviderInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) {
      Provider.of<MessageProvider>(context, listen: false)
          .loadConversations(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<MessageProvider>(
        builder: (ctx, msgProvider, _) {
          if (msgProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = msgProvider.conversations;

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No conversations yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: conversations.length,
            itemBuilder: (ctx, i) {
              final conv = conversations[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openThread(conv, uid),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.15),
                          child: Text(
                            conv.counterpartName.isNotEmpty
                                ? conv.counterpartName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AfiCareTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conv.counterpartName,
                                      style: TextStyle(
                                        fontWeight: conv.unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(conv.lastMessageAt),
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                conv.lastMessage,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        if (conv.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AfiCareTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${conv.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openThread(ConversationSummary conv, String userId) {
    final msgProvider =
        Provider.of<MessageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MessageThreadSheet(
        userId: userId,
        counterpartId: conv.counterpartId,
        counterpartName: conv.counterpartName,
        msgProvider: msgProvider,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MessageThreadSheet extends StatefulWidget {
  final String userId;
  final String counterpartId;
  final String counterpartName;
  final MessageProvider msgProvider;

  const _MessageThreadSheet({
    required this.userId,
    required this.counterpartId,
    required this.counterpartName,
    required this.msgProvider,
  });

  @override
  State<_MessageThreadSheet> createState() => _MessageThreadSheetState();
}

class _MessageThreadSheetState extends State<_MessageThreadSheet> {
  final _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.msgProvider.loadThread(widget.userId, widget.counterpartId);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(widget.counterpartName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Messages
          Expanded(
            child: Consumer<MessageProvider>(
              builder: (ctx, mp, _) {
                if (mp.isThreadLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final thread = mp.thread;
                if (thread.isEmpty) {
                  return Center(
                    child: Text('No messages yet. Send a message below.',
                        style: TextStyle(color: Colors.grey[600])),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: thread.length,
                  itemBuilder: (ctx, i) {
                    final msg = thread[i];
                    final isMe = msg.senderId == widget.userId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AfiCareTheme.primaryBlue
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                            bottomLeft: isMe
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                          ),
                        ),
                        constraints:
                            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send,
                        color: AfiCareTheme.primaryBlue),
                    onPressed: () async {
                      final text = _msgController.text.trim();
                      if (text.isEmpty) return;
                      _msgController.clear();
                      await widget.msgProvider.sendMessage(
                        senderId: widget.userId,
                        receiverId: widget.counterpartId,
                        content: text,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
