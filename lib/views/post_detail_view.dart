import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/widget/post_card.dart';

const Color _primaryColor = Color(0xFF4F46E5);
const Color _pageColor = Color(0xFFF8F9FC);

class PostDetailView extends StatelessWidget {
  final PostModel initialPost;
  final bool isFromOwnProfileTab;
  final bool checkProfileDeletion;

  const PostDetailView({
    super.key,
    required this.initialPost,
    this.isFromOwnProfileTab = false,
    this.checkProfileDeletion = true,
  });

  PostModel? _findInList(List<PostModel>? list, int postId) {
    if (list == null) return null;
    for (final item in list) {
      if (item.id == postId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Postingan',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer2<ProfileViewModel, PostViewModel>(
        builder: (context, profileVm, postVm, _) {
          final sourceProfile = isFromOwnProfileTab
              ? profileVm.ownProfile
              : profileVm.profile;

          final fromProfile = _findInList(sourceProfile?.posts, initialPost.id);
          final wasDeletedFromProfile =
              sourceProfile != null &&
              sourceProfile.id == initialPost.userId &&
              fromProfile == null;

          if (checkProfileDeletion && wasDeletedFromProfile) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 40,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Postingan telah dihapus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Postingan ini sudah tidak tersedia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali ke Profil'),
                    ),
                  ],
                ),
              ),
            );
          }

          final resolvedPost =
              fromProfile ??
              _findInList(postVm.posts, initialPost.id) ??
              _findInList(postVm.savedPosts, initialPost.id) ??
              initialPost;

          return SingleChildScrollView(
            child: Column(
              children: [
                PostCard(
                  key: ValueKey('detail_post_${resolvedPost.id}'),
                  post: resolvedPost,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
