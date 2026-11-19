import 'package:flutter/material.dart';
import 'package:ziesocial/model/chat_model.dart';

class SharedPostPreviewCard extends StatelessWidget {
  final SharedPostPreviewModel? sharedPost;
  final bool isMe;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const SharedPostPreviewCard({
    super.key,
    required this.sharedPost,
    required this.isMe,
    required this.accentColor,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final post = sharedPost;
    final canOpen = post != null && post.canOpen;

    if (!canOpen) {
      return _buildUnavailableCard();
    }

    final displayHandle = post.username.isNotEmpty
        ? '@${post.username}'
        : (post.name.isNotEmpty ? post.name : 'Pengguna');
    final avatarInitial = post.name.isNotEmpty
        ? post.name[0].toUpperCase()
        : (post.username.isNotEmpty ? post.username[0].toUpperCase() : '?');

    final cardBg = isMe
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFF4F5F9);
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.24)
        : const Color(0xFFE5E7EB);
    final primaryTextColor = isMe ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isMe
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF4B5563);
    final footerColor = isMe
        ? Colors.white.withValues(alpha: 0.9)
        : accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header ringkas pembuat postingan
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFE2E8F0),
                      backgroundImage: post.avatarUrl.isNotEmpty
                          ? NetworkImage(post.avatarUrl)
                          : null,
                      child: post.avatarUrl.isEmpty
                          ? Text(
                              avatarInitial,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isMe ? Colors.white : accentColor,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayHandle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: footerColor,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                  ],
                ),
              ),

              // Gambar postingan jika tersedia
              if (post.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    post.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isMe
                            ? Colors.black.withValues(alpha: 0.12)
                            : const Color(0xFFE5E7EB),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: footerColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isMe
                            ? Colors.black.withValues(alpha: 0.14)
                            : const Color(0xFFE5E7EB),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 26,
                          color: secondaryTextColor,
                        ),
                      );
                    },
                  ),
                ),

              // Caption ringkas + label aksi
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.caption.trim().isNotEmpty) ...[
                      Text(
                        post.caption.trim(),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 13,
                          color: footerColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lihat postingan',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: footerColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableCard() {
    final bgColor = isMe
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFF3F4F6);
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.22)
        : const Color(0xFFE5E7EB);
    final contentColor = isMe
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: contentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Postingan tidak tersedia',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: contentColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
