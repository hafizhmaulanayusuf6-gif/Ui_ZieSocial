import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/model/user_profile_model.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';

class _ShareRecipient {
  final int? conversationId;
  final int targetUserId;
  final String name;
  final String username;
  final String avatarUrl;
  final String? subtitle;

  const _ShareRecipient({
    this.conversationId,
    required this.targetUserId,
    required this.name,
    required this.username,
    required this.avatarUrl,
    this.subtitle,
  });

  String get displayName => name.isNotEmpty ? name : '@$username';

  factory _ShareRecipient.fromConversation(ConversationModel conv) {
    return _ShareRecipient(
      conversationId: conv.conversationId,
      targetUserId: conv.peer.id,
      name: conv.peer.name,
      username: conv.peer.username,
      avatarUrl: PostModel.resolveImageUrl(conv.peer.avatar ?? ''),
      subtitle: conv.lastMessage,
    );
  }

  factory _ShareRecipient.fromUser(UserSummaryModel user) {
    return _ShareRecipient(
      conversationId: null,
      targetUserId: user.id,
      name: user.name,
      username: user.username,
      avatarUrl: PostModel.resolveImageUrl(user.avatarUrl),
    );
  }
}

class SharePostBottomSheet extends StatefulWidget {
  final PostModel post;
  final int currentUserId;

  const SharePostBottomSheet({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<SharePostBottomSheet> createState() => _SharePostBottomSheetState();
}

class _SharePostBottomSheetState extends State<SharePostBottomSheet> {
  static const Color _primaryColor = Color(0xFF4F46E5);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  _ShareRecipient? _selectedRecipient;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatViewModel>().fetchConversations(
        userId: widget.currentUserId,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    context.read<SearchViewModel>().onKeywordChanged(
      value,
      viewerId: widget.currentUserId,
    );
  }

  void _clearSearchInput() {
    _searchController.clear();
    setState(() {});
    context.read<SearchViewModel>().clearSearch();
  }

  Future<void> _handleSend() async {
    final recipient = _selectedRecipient;
    if (recipient == null) return;

    final note = _noteController.text.trim();
    if (note.runes.length > ChatViewModel.maxMessageLength) {
      setState(() {
        _submitError =
            'Catatan terlalu panjang (maksimal ${ChatViewModel.maxMessageLength} karakter).';
      });
      return;
    }

    final chatVm = context.read<ChatViewModel>();
    if (chatVm.isSharingPost || chatVm.isSending) return;

    setState(() {
      _submitError = null;
    });

    final sentConversation = await chatVm.sharePostToChat(
      senderId: widget.currentUserId,
      postId: widget.post.id,
      conversationId: recipient.conversationId,
      targetUserId: recipient.targetUserId,
      note: note,
    );

    if (!mounted) return;

    if (sentConversation != null) {
      Navigator.pop(context, sentConversation);
    } else {
      setState(() {
        _submitError = chatVm.messagesError ?? 'Gagal membagikan postingan.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Consumer<ChatViewModel>(
      builder: (context, chatVm, _) {
        final isBusy = chatVm.isSharingPost || chatVm.isSending;

        return PopScope(
          canPop: !isBusy,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                      child: Row(
                        children: [
                          if (_selectedRecipient != null)
                            IconButton(
                              onPressed: isBusy
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedRecipient = null;
                                        _submitError = null;
                                      });
                                    },
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                                color: Color(0xFF1F2937),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Pilih penerima lain',
                            ),
                          Expanded(
                            child: Text(
                              _selectedRecipient == null
                                  ? 'Bagikan Postingan'
                                  : 'Kirim Postingan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isBusy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.black54,
                            ),
                            tooltip: 'Tutup',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEDEEF2)),
                    if (_selectedRecipient == null)
                      Flexible(child: _buildRecipientPicker(chatVm))
                    else
                      Flexible(
                        child: _buildConfirmAndNoteStep(
                          recipient: _selectedRecipient!,
                          isBusy: isBusy,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientPicker(ChatViewModel chatVm) {
    final query = _searchController.text.trim();
    final lowerQuery = query.toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search bar menggunakan SearchViewModel yang sudah tersedia
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F6),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                icon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Colors.black45,
                ),
                hintText: 'Cari percakapan atau pengguna...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.black45,
                ),
                border: InputBorder.none,
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.black45,
                        ),
                        onPressed: _clearSearchInput,
                      )
                    : null,
              ),
            ),
          ),
        ),
        Flexible(
          child: Consumer<SearchViewModel>(
            builder: (context, searchVm, _) {
              if (query.isEmpty) {
                return _buildConversationsList(chatVm);
              }

              // Filter percakapan lokal + hasil pencarian akun
              final matchedConversations = chatVm.conversations.where((conv) {
                final name = conv.peer.name.toLowerCase();
                final username = conv.peer.username.toLowerCase();
                return name.contains(lowerQuery) ||
                    username.contains(lowerQuery);
              }).toList();

              final existingPeerIds = matchedConversations
                  .map((c) => c.peer.id)
                  .toSet();

              final filteredSearchUsers = searchVm.results.where((u) {
                return u.id != widget.currentUserId &&
                    !existingPeerIds.contains(u.id);
              }).toList();

              if (searchVm.isLoading &&
                  matchedConversations.isEmpty &&
                  filteredSearchUsers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  ),
                );
              }

              if (searchVm.errorMessage != null &&
                  matchedConversations.isEmpty &&
                  filteredSearchUsers.isEmpty) {
                return _buildStateMessage(
                  icon: Icons.error_outline_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Gagal mencari pengguna',
                  subtitle: searchVm.errorMessage!,
                  actionLabel: 'Coba Lagi',
                  onAction: () => searchVm.onKeywordChanged(
                    query,
                    viewerId: widget.currentUserId,
                  ),
                );
              }

              if (matchedConversations.isEmpty && filteredSearchUsers.isEmpty) {
                return _buildStateMessage(
                  icon: Icons.person_search_rounded,
                  title: 'Pengguna tidak ditemukan',
                  subtitle: 'Coba kata kunci nama atau username lain.',
                );
              }

              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (matchedConversations.isNotEmpty) ...[
                    _buildSectionLabel('Percakapan'),
                    ...matchedConversations.map(
                      (conv) => _buildRecipientTile(
                        _ShareRecipient.fromConversation(conv),
                      ),
                    ),
                  ],
                  if (filteredSearchUsers.isNotEmpty) ...[
                    _buildSectionLabel('Pengguna'),
                    ...filteredSearchUsers.map(
                      (user) =>
                          _buildRecipientTile(_ShareRecipient.fromUser(user)),
                    ),
                  ],
                  if (searchVm.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConversationsList(ChatViewModel chatVm) {
    if (chatVm.isLoadingConversations && chatVm.conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (chatVm.conversationsError != null && chatVm.conversations.isEmpty) {
      return _buildStateMessage(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        title: 'Gagal memuat percakapan',
        subtitle: chatVm.conversationsError!,
        actionLabel: 'Coba Lagi',
        onAction: () => chatVm.fetchConversations(userId: widget.currentUserId),
      );
    }

    if (chatVm.conversations.isEmpty) {
      return _buildStateMessage(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Belum ada percakapan',
        subtitle: 'Cari nama atau username di atas untuk memilih penerima.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: chatVm.conversations.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionLabel('Percakapan Terbaru');
        }
        final conv = chatVm.conversations[index - 1];
        return _buildRecipientTile(_ShareRecipient.fromConversation(conv));
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildRecipientTile(_ShareRecipient recipient) {
    final initial = recipient.displayName.isNotEmpty
        ? recipient.displayName
              .replaceFirst('@', '')
              .substring(0, 1)
              .toUpperCase()
        : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: const Color(0xFFE2E8F0),
        backgroundImage: recipient.avatarUrl.isNotEmpty
            ? NetworkImage(recipient.avatarUrl)
            : null,
        child: recipient.avatarUrl.isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                  fontSize: 15,
                ),
              )
            : null,
      ),
      title: Text(
        recipient.displayName,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '@${recipient.username}',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.black38,
        size: 20,
      ),
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _selectedRecipient = recipient;
          _submitError = null;
        });
      },
    );
  }

  Widget _buildConfirmAndNoteStep({
    required _ShareRecipient recipient,
    required bool isBusy,
  }) {
    final initial = recipient.displayName.isNotEmpty
        ? recipient.displayName
              .replaceFirst('@', '')
              .substring(0, 1)
              .toUpperCase()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Penerima terpilih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: recipient.avatarUrl.isNotEmpty
                      ? NetworkImage(recipient.avatarUrl)
                      : null,
                  child: recipient.avatarUrl.isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${recipient.username}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          setState(() {
                            _selectedRecipient = null;
                            _submitError = null;
                          });
                        },
                  child: const Text('Ganti'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preview ringkas postingan yang akan dibagikan
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.post.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFE5E7EB),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 20,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.article_outlined,
                      size: 22,
                      color: Colors.black45,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.post.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.post.caption.trim().isNotEmpty
                            ? widget.post.caption.trim()
                            : 'Postingan tanpa caption',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.post.caption.trim().isNotEmpty
                              ? const Color(0xFF4B5563)
                              : Colors.black38,
                          fontStyle: widget.post.caption.trim().isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Catatan opsional (boleh kosong, maks 2000 karakter)
          TextField(
            controller: _noteController,
            enabled: !isBusy,
            minLines: 1,
            maxLines: 3,
            maxLength: ChatViewModel.maxMessageLength,
            onChanged: (_) {
              if (_submitError != null) {
                setState(() => _submitError = null);
              }
            },
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan (opsional)...',
              hintStyle: const TextStyle(fontSize: 13.5, color: Colors.black38),
              errorText: _submitError,
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Batal & Kirim
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isBusy ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isBusy ? null : _handleSend,
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kirim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    Color iconColor = Colors.black26,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: iconColor),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
