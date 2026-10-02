import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../theme/patient_tokens.dart';
import '../../widgets/provider_avatar.dart';
import 'widgets/patient_ui.dart';

/// True when a real photo should be preferred over plain initials --
/// either the counterpart genuinely has one uploaded, or their role is
/// provider-shaped (ProviderAvatar's default illustration always wins
/// over initials once loaded, so this is skipped for patient/admin/chw
/// counterparts who have no photo, preserving their existing initials).
bool _prefersIllustratedAvatar(String? roleName, UserModel? cached) {
  const providerRoleNames = {'doctor', 'nurse', 'radiologist'};
  final hasPhoto = cached?.photoUrl != null && cached!.photoUrl!.isNotEmpty;
  return hasPhoto || providerRoleNames.contains(roleName ?? cached?.role.name);
}

/// Messages — conversation list beside the open thread on wide screens,
/// list-then-push on narrow ones. Rendered inside the patient shell, so
/// it carries no app bar of its own.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  String _search = '';
  ConversationSummary? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final mp = Provider.of<MessageProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null) await mp.loadConversations(id);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = !PT.isTablet(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PScreenHead(
          eyebrow: 'Your care',
          title: 'Messages',
          subtitle: 'Keep conversations with your care team in one place.',
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: PT.teal))
              : Consumer<MessageProvider>(
                  builder: (context, mp, _) {
                    final convos = mp.conversations
                        .where((c) =>
                            c.counterpartName.toLowerCase().contains(_search.toLowerCase()))
                        .toList();

                    if (!isWide) return _conversationsCard(convos, isWide: false);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: _conversationsCard(convos, isWide: true)),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: _chatPane()),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _conversationsCard(List<ConversationSummary> convos, {required bool isWide}) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCardTitle('Conversations'),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: pInput(hint: 'Search messages…').copyWith(
              prefixIcon: const Icon(Icons.search, size: 18, color: PT.muted),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: convos.isEmpty
                ? const PEmpty(
                    emoji: '💬',
                    title: 'No messages yet',
                    body: 'Conversations with your care team will appear here.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: convos.length,
                      itemBuilder: (_, i) => _conversationRow(convos[i], isWide: isWide),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _conversationRow(ConversationSummary c, {required bool isWide}) {
    final selected = isWide && _selected?.counterpartId == c.counterpartId;
    final cached = context.read<MessageProvider>().cachedUser(c.counterpartId);

    final avatar = _prefersIllustratedAvatar(c.counterpartRole, cached)
        ? ProviderAvatarSmall(
            name: c.counterpartName,
            role: cached?.role ?? UserRole.doctor,
            gender: cached?.gender,
            photoUrl: cached?.photoUrl,
            radius: 20,
          )
        : PAvatar(
            initials: c.counterpartName.isNotEmpty ? c.counterpartName[0].toUpperCase() : '?',
            size: 40,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? PT.calloutBg : Colors.transparent,
        borderRadius: BorderRadius.circular(PT.rRow),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PT.rRow),
          onTap: () async {
            if (isWide) {
              setState(() => _selected = c);
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    counterpartId: c.counterpartId,
                    counterpartName: c.counterpartName,
                  ),
                ),
              );
              _load();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? PT.teal.withOpacity(.35) : PT.line),
              borderRadius: BorderRadius.circular(PT.rRow),
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.counterpartName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.rowTitle()),
                      const SizedBox(height: 3),
                      Text(c.lastMessage,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.rowSub()),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_shortTime(c.lastMessageAt),
                        style: PT.rowSub().copyWith(
                          fontSize: 11,
                          color: c.unreadCount > 0 ? PT.teal : PT.muted,
                          fontWeight: c.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                        )),
                    const SizedBox(height: 5),
                    if (c.unreadCount > 0)
                      PBadge('${c.unreadCount}', tone: PTone.blue)
                    else
                      const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatPane() {
    if (_selected == null) {
      return const PCard(
        child: Center(
          child: PEmpty(
            emoji: '💬',
            title: 'Select a conversation',
            body: 'Choose someone on the left to read and reply to your messages.',
          ),
        ),
      );
    }
    return ChatScreen(
      key: ValueKey(_selected!.counterpartId),
      embedded: true,
      counterpartId: _selected!.counterpartId,
      counterpartName: _selected!.counterpartName,
    );
  }

  String _shortTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Individual chat
// ═══════════════════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  final String counterpartId;
  final String counterpartName;

  /// When true, renders without its own Scaffold/AppBar so it can be
  /// embedded inside the split-pane layout.
  final bool embedded;

  const ChatScreen({
    super.key,
    required this.counterpartId,
    required this.counterpartName,
    this.embedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final mp = Provider.of<MessageProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null) await mp.loadThread(id, widget.counterpartId);
    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final mp = Provider.of<MessageProvider>(context, listen: false);
    final id = auth.currentUser?.id;
    if (id != null) {
      final ok = await mp.sendMessage(
        senderId: id,
        receiverId: widget.counterpartId,
        content: text,
      );
      if (ok) _controller.clear();
    }
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = auth.currentUser?.id;

    if (widget.embedded) {
      return PCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _paneHeader(),
            const Divider(height: 1, color: PT.line),
            Expanded(child: _chatBody(myId)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: PT.page,
      appBar: AppBar(
        backgroundColor: PT.page,
        surfaceTintColor: PT.page,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: PT.ink),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            _avatar(18),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.counterpartName, style: PT.h3())),
          ],
        ),
      ),
      body: _chatBody(myId),
    );
  }

  Widget _avatar(double radius) {
    final cached = context.read<MessageProvider>().cachedUser(widget.counterpartId);
    return _prefersIllustratedAvatar(null, cached)
        ? ProviderAvatarSmall(
            name: widget.counterpartName,
            role: cached?.role ?? UserRole.doctor,
            gender: cached?.gender,
            photoUrl: cached?.photoUrl,
            radius: radius,
          )
        : PAvatar(
            initials:
                widget.counterpartName.isNotEmpty ? widget.counterpartName[0].toUpperCase() : '?',
            size: radius * 2,
          );
  }

  Widget _paneHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
      child: Row(
        children: [
          _avatar(18),
          const SizedBox(width: 11),
          Expanded(child: Text(widget.counterpartName, style: PT.h3())),
        ],
      ),
    );
  }

  Widget _chatBody(String? myId) {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: PT.teal))
              : Consumer<MessageProvider>(
                  builder: (context, mp, _) {
                    if (mp.thread.isEmpty) {
                      return Center(
                        child: Text('Start the conversation', style: PT.sub()),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: mp.thread.length,
                      itemBuilder: (_, i) {
                        final m = mp.thread[i];
                        return _bubble(m, m.senderId == myId);
                      },
                    );
                  },
                ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _bubble(MessageModel m, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        decoration: BoxDecoration(
          color: mine ? PT.teal : PT.calloutBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.content,
              style: PT.body().copyWith(color: mine ? Colors.white : PT.ink, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(m.createdAt),
              style: PT.rowSub().copyWith(
                fontSize: 10,
                color: mine ? Colors.white70 : PT.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: PT.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _sending ? null : _send(),
                decoration: pInput(hint: 'Type a message…'),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: PT.navy,
              borderRadius: BorderRadius.circular(PT.rButton),
              child: InkWell(
                borderRadius: BorderRadius.circular(PT.rButton),
                onTap: _sending ? null : _send,
                child: SizedBox(
                  width: 46,
                  height: 42,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
