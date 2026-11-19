import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/views/chat_detail_view.dart';

class ConversationsView extends StatefulWidget {
  final bool isTab;

  const ConversationsView({super.key, this.isTab = false});

  @override
  State<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView>
    with WidgetsBindingObserver {
  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<LoginViewModel>().user;
      final uid = int.tryParse(user?.id ?? '0') ?? 0;
      _currentUserId = uid;

      if (uid > 0) {
        context.read<ChatViewModel>().fetchConversations(userId: uid);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUserId > 0) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_currentUserId > 0) {
      await context.read<ChatViewModel>().fetchConversations(
        userId: _currentUserId,
      );
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6C5CE7);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: !widget.isTab,
        title: const Text(
          'Pesan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Consumer<ChatViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoadingConversations && vm.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.conversationsError != null && vm.conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vm.conversationsError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (vm.conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F2F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada Pesan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Cari pengguna dan kirim pesan melalui halaman profil mereka.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: widget.isTab
                  ? const EdgeInsets.only(bottom: 92)
                  : EdgeInsets.zero,
              itemCount: vm.conversations.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 72,
                color: Color(0xFFF1F2F6),
              ),
              itemBuilder: (context, index) {
                final conv = vm.conversations[index];
                final peer = conv.peer;
                final isOnline = vm.isPeerOnline(conv.conversationId, peer.id);
                final isTyping = vm.isPeerTyping(conv.conversationId, peer.id);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage:
                            peer.avatar != null && peer.avatar!.isNotEmpty
                            ? NetworkImage(
                                '${ApiConstants.serverRoot}/${peer.avatar}',
                              )
                            : null,
                        child: peer.avatar == null || peer.avatar!.isEmpty
                            ? Text(
                                peer.name.isNotEmpty
                                    ? peer.name[0].toUpperCase()
                                    : (peer.username.isNotEmpty
                                          ? peer.username[0].toUpperCase()
                                          : '?'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                peer.name.isNotEmpty
                                    ? peer.name
                                    : peer.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageTime),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  subtitle: isTyping
                      ? const Text(
                          'Mengetik...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          conv.lastMessage ?? 'Memulai percakapan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: conv.lastMessage != null
                                ? Colors.black54
                                : Colors.grey,
                          ),
                        ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailView(
                          conversationId: conv.conversationId,
                          peer: peer,
                        ),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
