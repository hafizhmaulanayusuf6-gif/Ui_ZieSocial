import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/pusher_service.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/views/post_detail_view.dart';
import 'package:ziesocial/widget/shared_post_preview_card.dart';

class ChatDetailView extends StatefulWidget {
  final int conversationId;
  final PeerModel peer;

  const ChatDetailView({
    super.key,
    required this.conversationId,
    required this.peer,
  });

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final PusherService _pusherService = PusherService();

  int _currentUserId = 0;
  ChatMessageModel? _replyingTo;
  int? _openingPostMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<LoginViewModel>().user;
      final uid = int.tryParse(user?.id ?? '0') ?? 0;
      _currentUserId = uid;

      if (uid > 0) {
        final chatVm = context.read<ChatViewModel>();
        chatVm.setActiveConversation(widget.conversationId);
        chatVm.initRealtime(currentUserId: uid);

        _pusherService.init(currentUserId: uid);
        _pusherService.subscribeToConversation(widget.conversationId, (
          message,
        ) {
          if (mounted) {
            context.read<ChatViewModel>().onMessageReceived(message);
            _scrollToBottom(force: false);
          }
        });

        chatVm
            .fetchMessages(conversationId: widget.conversationId, userId: uid)
            .then((_) => _scrollToBottom(force: true));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_currentUserId > 0 && mounted) {
        context.read<ChatViewModel>().stopTypingImmediately(
          conversationId: widget.conversationId,
          userId: _currentUserId,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_currentUserId > 0) {
      try {
        context.read<ChatViewModel>().stopTypingImmediately(
          conversationId: widget.conversationId,
          userId: _currentUserId,
        );
      } catch (_) {}
    }
    _pusherService.unregisterMessageListener(widget.conversationId);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return (maxScroll - currentScroll) <= 150;
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (force || _isNearBottom) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _currentUserId < 1) return;

    final chatVm = context.read<ChatViewModel>();
    chatVm.stopTypingImmediately(
      conversationId: widget.conversationId,
      userId: _currentUserId,
    );

    final targetReply = _replyingTo;
    _textController.clear();
    if (_replyingTo != null) {
      setState(() {
        _replyingTo = null;
      });
    }

    final success = await chatVm.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      message: text,
      replyToMessageId: targetReply?.id,
    );

    if (success) {
      _scrollToBottom(force: true);
    } else if (mounted && chatVm.messagesError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatVm.messagesError!)));
    }
  }

  void _setReplyTarget(ChatMessageModel message) {
    if (message.isDeletedForEveryone) return;
    setState(() {
      _replyingTo = message;
    });
    _focusNode.requestFocus();
  }

  Future<void> _copyMessageText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan disalin.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSharedPost(ChatMessageModel message) async {
    final sharedPost = message.sharedPost;
    if (sharedPost == null || !sharedPost.canOpen) return;
    if (_openingPostMessageId != null) return;

    setState(() {
      _openingPostMessageId = message.id;
    });

    final chatVm = context.read<ChatViewModel>();
    final post = await chatVm.fetchPostDetail(
      postId: sharedPost.id!,
      userId: _currentUserId,
    );

    if (!mounted) return;
    setState(() {
      _openingPostMessageId = null;
    });

    if (post != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetailView(initialPost: post, checkProfileDeletion: false),
        ),
      );
    } else {
      final error = chatVm.messagesError ?? 'Postingan tidak tersedia.';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _showMessageActionsSheet(ChatMessageModel msg, Color primaryColor) {
    if (_currentUserId < 1) return;
    HapticFeedback.mediumImpact();

    final isMe = msg.senderId == _currentUserId;
    final isDeleted = msg.isDeletedForEveryone;
    final canReply = !isDeleted;
    final canCopy = !isDeleted && msg.message.trim().isNotEmpty;
    final canEdit =
        isMe && !isDeleted && msg.messageType == ChatMessageModel.typeText;
    final canDeleteForEveryone = isMe && !isDeleted;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        msg.conversationPreviewText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontStyle: isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEDEEF2)),
                  if (canReply)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.reply_rounded, color: primaryColor),
                      title: const Text('Balas'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _setReplyTarget(msg);
                      },
                    ),
                  if (canCopy)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.copy_rounded,
                        color: Color(0xFF374151),
                      ),
                      title: const Text('Salin'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _copyMessageText(msg.message);
                      },
                    ),
                  if (canEdit)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined, color: primaryColor),
                      title: const Text('Edit'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showEditMessageDialog(msg, primaryColor);
                      },
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFF374151),
                    ),
                    title: const Text('Hapus untuk saya'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showDeleteConfirmationDialog(
                        msg,
                        deleteFor: ChatViewModel.deleteForMe,
                      );
                    },
                  ),
                  if (canDeleteForEveryone)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Hapus untuk semua orang',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showDeleteConfirmationDialog(
                          msg,
                          deleteFor: ChatViewModel.deleteForEveryone,
                        );
                      },
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditMessageDialog(
    ChatMessageModel msg,
    Color primaryColor,
  ) async {
    if (msg.senderId != _currentUserId ||
        msg.isDeletedForEveryone ||
        msg.messageType != ChatMessageModel.typeText) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _EditMessageDialog(
          initialText: msg.message,
          primaryColor: primaryColor,
          onSubmit: (newText) async {
            final chatVm = context.read<ChatViewModel>();
            final success = await chatVm.editMessage(
              messageId: msg.id,
              newMessage: newText,
              userId: _currentUserId,
            );
            if (success) return null;
            return chatVm.messagesError ?? 'Gagal memperbarui pesan.';
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(
    ChatMessageModel msg, {
    required String deleteFor,
  }) async {
    final isEveryone = deleteFor == ChatViewModel.deleteForEveryone;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return PopScope(
              canPop: !isSubmitting,
              child: AlertDialog(
                title: Text(
                  isEveryone
                      ? 'Hapus untuk semua orang?'
                      : 'Hapus pesan untuk Anda?',
                ),
                content: Text(
                  isEveryone
                      ? 'Pesan ini akan dihapus untuk seluruh peserta dalam percakapan ini dan tidak dapat dikembalikan.'
                      : 'Pesan ini hanya akan dihapus dari tampilan Anda dan tetap terlihat oleh lawan bicara.',
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEveryone
                          ? Colors.redAccent
                          : const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);

                            final chatVm = context.read<ChatViewModel>();
                            final success = await chatVm.deleteMessage(
                              messageId: msg.id,
                              deleteFor: deleteFor,
                              userId: _currentUserId,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (!mounted) return;

                            if (success) {
                              if (_replyingTo?.id == msg.id) {
                                setState(() {
                                  _replyingTo = null;
                                });
                              }
                            } else {
                              final error =
                                  chatVm.messagesError ??
                                  'Gagal menghapus pesan.';
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEveryone ? 'Hapus untuk semua' : 'Hapus'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(11, 16) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6C5CE7);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _currentUserId > 0) {
          try {
            context.read<ChatViewModel>().stopTypingImmediately(
              conversationId: widget.conversationId,
              userId: _currentUserId,
            );
          } catch (_) {}
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              if (_currentUserId > 0) {
                context.read<ChatViewModel>().stopTypingImmediately(
                  conversationId: widget.conversationId,
                  userId: _currentUserId,
                );
              }
              context.read<ChatViewModel>().clearMessages();
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE2E8F0),
                backgroundImage:
                    widget.peer.avatar != null && widget.peer.avatar!.isNotEmpty
                    ? NetworkImage(
                        '${ApiConstants.serverRoot}/${widget.peer.avatar}',
                      )
                    : null,
                child: widget.peer.avatar == null || widget.peer.avatar!.isEmpty
                    ? Text(
                        widget.peer.name.isNotEmpty
                            ? widget.peer.name[0].toUpperCase()
                            : (widget.peer.username.isNotEmpty
                                  ? widget.peer.username[0].toUpperCase()
                                  : '?'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peer.name.isNotEmpty
                          ? widget.peer.name
                          : widget.peer.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Consumer<ChatViewModel>(
                      builder: (context, vm, _) {
                        final isTyping = vm.isPeerTyping(
                          widget.conversationId,
                          widget.peer.id,
                        );
                        if (isTyping) {
                          return const Text(
                            'Sedang mengetik...',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }

                        final isOnline = vm.isPeerOnline(
                          widget.conversationId,
                          widget.peer.id,
                        );
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<ChatViewModel>(
                builder: (context, vm, _) {
                  if (vm.isLoadingMessages && vm.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (vm.messagesError != null && vm.messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 44,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vm.messagesError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                vm.fetchMessages(
                                  conversationId: widget.conversationId,
                                  userId: _currentUserId,
                                );
                              },
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (vm.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Mulai percakapan dengan @${widget.peer.username}',
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: vm.messages.length,
                    itemBuilder: (context, index) {
                      final msg = vm.messages[index];
                      final isMe = msg.senderId == _currentUserId;

                      return _SwipeToReplyBubble(
                        key: ValueKey('msg_${msg.id}_$index'),
                        accentColor: primaryColor,
                        enabled: !msg.isDeletedForEveryone,
                        onReplyTriggered: () => _setReplyTarget(msg),
                        child: _buildMessageBubble(msg, isMe, primaryColor),
                      );
                    },
                  );
                },
              ),
            ),
            // Bar Preview Balasan (ketika user melakukan swipe-to-reply)
            if (_replyingTo != null) _buildReplyPreviewBar(primaryColor),
            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEDEEF2))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          onChanged: (text) {
                            if (_currentUserId > 0) {
                              context.read<ChatViewModel>().onUserTyping(
                                conversationId: widget.conversationId,
                                userId: _currentUserId,
                                currentText: text,
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Ketik pesan...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<ChatViewModel>(
                      builder: (context, vm, _) {
                        return IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                          ),
                          icon: vm.isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          onPressed: vm.isSending ? null : _handleSend,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessageModel msg,
    bool isMe,
    Color primaryColor,
  ) {
    final isDeleted = msg.isDeletedForEveryone;
    final bubbleColor = isDeleted
        ? (isMe
              ? primaryColor.withValues(alpha: 0.72)
              : const Color(0xFFF3F4F6))
        : (isMe ? primaryColor : Colors.white);
    final metaColor = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black38;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActionsSheet(msg, primaryColor),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (isDeleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 14,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        ChatMessageModel.deletedPlaceholder,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.88)
                              : Colors.black54,
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                // Preview Pesan Asli jika ini adalah pesan balasan (Reply)
                if (msg.replyMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.black.withValues(alpha: 0.15)
                          : const Color(0xFFF1F2F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: isMe ? Colors.white : primaryColor,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.replyMessage!.senderId == _currentUserId
                              ? 'Anda'
                              : (msg.replyMessage!.senderName.isNotEmpty
                                    ? msg.replyMessage!.senderName
                                    : widget.peer.name),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white : primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg.replyMessage!.message,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: msg.replyMessage!.isDeleted
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.85)
                                : (msg.replyMessage!.isDeleted
                                      ? Colors.black54
                                      : Colors.black87),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                // Preview Shared Post jika tipe pesan shared_post
                if (msg.isSharedPost) ...[
                  SharedPostPreviewCard(
                    sharedPost: msg.sharedPost,
                    isMe: isMe,
                    accentColor: primaryColor,
                    isLoading: _openingPostMessageId == msg.id,
                    onTap: msg.sharedPost?.canOpen == true
                        ? () => _openSharedPost(msg)
                        : null,
                  ),
                  if (msg.message.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        msg.message,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDeleted && msg.isEdited) ...[
                    Text(
                      'diedit',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: metaColor,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: TextStyle(fontSize: 10, color: metaColor),
                    ),
                  ],
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(fontSize: 10, color: metaColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar(Color primaryColor) {
    if (_replyingTo == null) return const SizedBox.shrink();
    final isMyMessage = _replyingTo!.senderId == _currentUserId;
    final senderName = isMyMessage
        ? 'Anda'
        : (widget.peer.name.isNotEmpty
              ? widget.peer.name
              : widget.peer.username);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F2F6),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.reply_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Membalas $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.conversationPreviewText,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Batalkan reply',
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialText;
  final Color primaryColor;
  final Future<String?> Function(String newText) onSubmit;

  const _EditMessageDialog({
    required this.initialText,
    required this.primaryColor,
    required this.onSubmit,
  });

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Pesan tidak boleh kosong.';
      });
      return;
    }
    if (trimmed.runes.length > ChatViewModel.maxMessageLength) {
      setState(() {
        _errorText =
            'Pesan terlalu panjang (maksimal ${ChatViewModel.maxMessageLength} karakter).';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final errorMessage = await widget.onSubmit(trimmed);
    if (!mounted) return;

    if (errorMessage == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isSaving = false;
        _errorText = errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('Edit Pesan'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_isSaving,
              minLines: 1,
              maxLines: 5,
              maxLength: ChatViewModel.maxMessageLength,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Tulis pesan...',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _SwipeToReplyBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback onReplyTriggered;
  final Color accentColor;
  final bool enabled;

  const _SwipeToReplyBubble({
    super.key,
    required this.child,
    required this.onReplyTriggered,
    required this.accentColor,
    this.enabled = true,
  });

  @override
  State<_SwipeToReplyBubble> createState() => _SwipeToReplyBubbleState();
}

class _SwipeToReplyBubbleState extends State<_SwipeToReplyBubble>
    with SingleTickerProviderStateMixin {
  static const double _maxTranslation = 65.0;
  static const double _replyThreshold = 48.0;

  late final AnimationController _returnController;
  late final CurvedAnimation _returnCurve;

  double _rawDragOffset = 0.0;
  double _currentOffset = 0.0;
  double _returnStartOffset = 0.0;
  bool _hasTriggeredInCurrentGesture = false;

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _returnCurve = CurvedAnimation(
      parent: _returnController,
      curve: Curves.easeOutCubic,
    );
    _returnController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentOffset = _returnStartOffset * (1.0 - _returnCurve.value);
      });
    });
  }

  @override
  void dispose() {
    _returnCurve.dispose();
    _returnController.dispose();
    super.dispose();
  }

  double _applyResistance(double rawDrag) {
    if (rawDrag <= 0) return 0.0;
    const linearZone = 40.0;
    const linearFactor = 0.85;
    if (rawDrag <= linearZone) {
      return rawDrag * linearFactor;
    }
    const base = linearZone * linearFactor;
    const remaining = _maxTranslation - base;
    final extra = rawDrag - linearZone;
    return base + remaining * (extra / (extra + 45.0));
  }

  void _handleDragStart(DragStartDetails details) {
    _returnController.stop();
    _rawDragOffset = 0.0;
    _hasTriggeredInCurrentGesture = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    if (delta == 0.0) return;

    _rawDragOffset = (_rawDragOffset + delta).clamp(0.0, double.infinity);
    final nextOffset = _applyResistance(_rawDragOffset);

    if (nextOffset != _currentOffset) {
      setState(() {
        _currentOffset = nextOffset;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_currentOffset >= _replyThreshold && !_hasTriggeredInCurrentGesture) {
      _hasTriggeredInCurrentGesture = true;
      widget.onReplyTriggered();
    }
    _animateBack();
  }

  void _handleDragCancel() {
    _hasTriggeredInCurrentGesture = false;
    _animateBack();
  }

  void _animateBack() {
    if (!mounted) return;
    _rawDragOffset = 0.0;
    if (_currentOffset == 0.0) return;

    _returnStartOffset = _currentOffset;
    _returnController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentOffset / _replyThreshold).clamp(0.0, 1.0);
    final isThresholdReached = _currentOffset >= _replyThreshold;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: widget.enabled ? _handleDragStart : null,
      onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
      onHorizontalDragCancel: widget.enabled ? _handleDragCancel : null,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_currentOffset > 0.5)
            Positioned(
              left: 4,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: isThresholdReached ? 1.05 : (0.6 + 0.4 * progress),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: isThresholdReached ? 0.22 : 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_currentOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
