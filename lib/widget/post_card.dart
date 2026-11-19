import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/model/comment_model.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/viewmodel/comment_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/views/chat_detail_view.dart';
import 'package:ziesocial/views/profile_view.dart';
import 'package:ziesocial/widget/share_post_bottom_sheet.dart';

const _primaryColor = Color(0xFF4F46E5);

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showLikeAnimation = false;

  Future<void> _toggleSave() async {
    final userId = int.tryParse(context.read<LoginViewModel>().user?.id ?? '');

    if (userId == null || userId < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan login kembali.')));
      return;
    }

    final willSave = !widget.post.isSaved;

    final success = await context.read<PostViewModel>().toggleSave(
      userId: userId,
      postId: widget.post.id,
      fallbackPost: widget.post,
    );

    if (!mounted) return;

    if (success) {
      try {
        context.read<ProfileViewModel>().syncPostSave(
          postId: widget.post.id,
          isSaved: willSave,
        );
      } catch (_) {}

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willSave
                ? 'Postingan berhasil disimpan.'
                : 'Postingan dihapus dari simpanan.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final message = context.read<PostViewModel>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message == null || message.isEmpty
                ? 'Gagal menyimpan postingan.'
                : message,
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike() async {
    final userId = int.tryParse(context.read<LoginViewModel>().user?.id ?? '');

    if (userId == null || userId < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan login kembali.')));
      return;
    }

    final willLike = !widget.post.isLiked;
    final success = await context.read<PostViewModel>().toggleLike(
      userId: userId,
      postId: widget.post.id,
      fallbackPost: widget.post,
    );

    if (success && mounted) {
      try {
        final newLikes = (widget.post.likesCount + (willLike ? 1 : -1)).clamp(
          0,
          999999,
        );
        context.read<ProfileViewModel>().syncPostLike(
          postId: widget.post.id,
          isLiked: willLike,
          likesCount: newLikes,
        );
      } catch (_) {}
    } else if (!success && mounted) {
      final message = context.read<PostViewModel>().errorMessage;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message == null || message.isEmpty
                ? 'Gagal memperbarui Like.'
                : message,
          ),
        ),
      );
    }
  }

  void _likeWithAnimation() {
    // Double-tap hanya menambahkan Like jika belum disukai.
    if (!widget.post.isLiked) {
      _toggleLike();
    }

    setState(() {
      _showLikeAnimation = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;

      setState(() {
        _showLikeAnimation = false;
      });
    });
  }

  void _showPostOptions(BuildContext context, bool isOwner, int currentUserId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: _primaryColor,
                  ),
                  title: const Text('Edit Caption'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showEditCaptionDialog(context, currentUserId);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Hapus Postingan',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showDeleteConfirmationDialog(context, currentUserId);
                  },
                ),
              ] else ...[
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Opsi Postingan'),
                  subtitle: Text(
                    'Hanya pemilik postingan yang dapat mengedit atau menghapus.',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditCaptionDialog(BuildContext context, int currentUserId) {
    final controller = TextEditingController(text: widget.post.caption);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Caption'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tulis caption baru...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCaption = controller.text.trim();
                Navigator.pop(dialogContext);

                final success = await context
                    .read<PostViewModel>()
                    .updateCaption(
                      userId: currentUserId,
                      postId: widget.post.id,
                      newCaption: newCaption,
                    );

                if (!context.mounted) return;

                if (success) {
                  try {
                    context.read<ProfileViewModel>().syncPostCaption(
                      postId: widget.post.id,
                      caption: newCaption,
                    );
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Caption berhasil diperbarui.'),
                    ),
                  );
                } else {
                  final error =
                      context.read<PostViewModel>().errorMessage ??
                      'Gagal memperbarui caption.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int currentUserId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Postingan'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus postingan ini? Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                final success = await context.read<PostViewModel>().deletePost(
                  userId: currentUserId,
                  postId: widget.post.id,
                );

                if (!context.mounted) return;

                if (success) {
                  try {
                    context.read<ProfileViewModel>().syncPostDeleted(
                      postId: widget.post.id,
                    );
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Postingan berhasil dihapus.'),
                    ),
                  );
                } else {
                  final error =
                      context.read<PostViewModel>().errorMessage ??
                      'Gagal menghapus postingan.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _openComments() {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CommentsBottomSheet(post: widget.post, currentUserId: currentUserId),
    );
  }

  Future<void> _openSharePost() async {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;

    if (currentUserId < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan login kembali.')));
      return;
    }

    final parentSearchVm = context.read<SearchViewModel>();

    final sentConversation = await showModalBottomSheet<ConversationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<SearchViewModel>(
        create: (_) => parentSearchVm.createScopedCopy(),
        child: SharePostBottomSheet(
          post: widget.post,
          currentUserId: currentUserId,
        ),
      ),
    );

    if (!mounted || sentConversation == null) return;

    final targetName = sentConversation.peer.name.isNotEmpty
        ? sentConversation.peer.name
        : '@${sentConversation.peer.username}';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Postingan dibagikan ke $targetName.'),
        action: SnackBarAction(
          label: 'Buka Chat',
          onPressed: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailView(
                  conversationId: sentConversation.conversationId,
                  peer: sentConversation.peer,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.only(top: 0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileView(
                          userId: post.userId,
                          username: post.username,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFE9EDF5),
                    backgroundImage: post.avatarUrl.isNotEmpty
                        ? NetworkImage(post.avatarUrl)
                        : null,
                    child: post.avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileView(
                            userId: post.userId,
                            username: post.username,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.location,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF858A96),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final currentUser = context.read<LoginViewModel>().user;
                    final currentUserId =
                        int.tryParse(currentUser?.id ?? '') ?? 0;
                    final isOwner =
                        currentUserId > 0 && currentUserId == post.userId;
                    _showPostOptions(context, isOwner, currentUserId);
                  },
                  icon: const Icon(Icons.more_horiz, size: 22),
                ),
              ],
            ),
          ),

          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onDoubleTap: _likeWithAnimation,
                    child: post.imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFE9EDF5),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 42,
                              ),
                            ),
                          )
                        : Image.network(
                            post.imageUrl,
                            cacheWidth: 1080,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;

                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFE9EDF5),
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                if (_showLikeAnimation)
                  IgnorePointer(
                    child: Lottie.asset(
                      'assets/animations/Like.json',
                      width: 200,
                      height: 200,
                      repeat: false,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Row(
              children: [
                _ActionIcon(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked
                      ? Colors.redAccent
                      : const Color(0xFF424650),
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 15),
                _ActionIcon(
                  icon: Icons.mode_comment_outlined,
                  onTap: _openComments,
                ),
                const SizedBox(width: 15),
                _ActionIcon(icon: Icons.send_outlined, onTap: _openSharePost),
                const Spacer(),
                _ActionIcon(
                  icon: widget.post.isSaved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: widget.post.isSaved
                      ? _primaryColor
                      : const Color(0xFF424650),
                  onTap: _toggleSave,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
            child: GestureDetector(
              onTap: _openComments,
              child: Text(
                '${post.likesCount} likes · ${post.commentsCount} comments',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF454956),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF343741),
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '${post.username}  ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              post.createdAt.isEmpty ? '' : post.createdAt,
              style: const TextStyle(fontSize: 9, color: Color(0xFF8A8E98)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF424650),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final int currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommentViewModel>().fetchComments(postId: widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (widget.currentUserId < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk berkomentar.')),
      );
      return;
    }

    final success = await context.read<CommentViewModel>().addComment(
      userId: widget.currentUserId,
      postId: widget.post.id,
      text: text,
    );

    if (!mounted) return;

    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      context.read<PostViewModel>().updateCommentCount(
        postId: widget.post.id,
        delta: 1,
      );
      try {
        context.read<ProfileViewModel>().syncPostCommentCount(
          postId: widget.post.id,
          delta: 1,
        );
      } catch (_) {}
    } else {
      final error =
          context.read<CommentViewModel>().errorMessage ??
          'Gagal menambahkan komentar.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Komentar'),
        content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<CommentViewModel>().deleteComment(
      userId: widget.currentUserId,
      commentId: comment.id,
    );

    if (!mounted) return;

    if (success) {
      context.read<PostViewModel>().updateCommentCount(
        postId: widget.post.id,
        delta: -1,
      );
      try {
        context.read<ProfileViewModel>().syncPostCommentCount(
          postId: widget.post.id,
          delta: -1,
        );
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komentar berhasil dihapus.')),
      );
    } else {
      final error =
          context.read<CommentViewModel>().errorMessage ??
          'Gagal menghapus komentar.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Komentar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: Consumer<CommentViewModel>(
              builder: (context, commentVm, child) {
                if (commentVm.isLoading && commentVm.comments.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (commentVm.errorMessage != null &&
                    commentVm.comments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(commentVm.errorMessage!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                commentVm.fetchComments(postId: widget.post.id),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (commentVm.comments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: Color(0xFF9CA3AF),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada komentar.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Jadilah yang pertama berkomentar!',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: commentVm.comments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final comment = commentVm.comments[index];
                    final canDelete =
                        widget.currentUserId > 0 &&
                        (comment.userId == widget.currentUserId ||
                            widget.post.userId == widget.currentUserId);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: comment.avatarUrl.isNotEmpty
                              ? NetworkImage(comment.avatarUrl)
                              : null,
                          child: comment.avatarUrl.isEmpty
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    comment.username,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.createdAt,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                comment.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canDelete)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                            tooltip: 'Hapus komentar',
                            onPressed: () => _deleteComment(comment),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: mediaQuery.viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan komentar...',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9CA3AF),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _primaryColor),
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 4),
                Consumer<CommentViewModel>(
                  builder: (context, commentVm, _) {
                    if (commentVm.isSubmitting) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                      );
                    }

                    return IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: _primaryColor,
                      ),
                      onPressed: _submitComment,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
