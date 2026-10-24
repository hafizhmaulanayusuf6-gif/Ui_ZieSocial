import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/user_profile_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';

const _primaryColor = Color(0xFF4F46E5);
const _pageColor = Color(0xFFF8F9FC);

class FollowListView extends StatefulWidget {
  /// ID profil yang follower/following-nya ingin ditampilkan.
  final int profileUserId;

  /// "followers" atau "following"
  final String type;

  /// Label judul (mis. "Followers" / "Following")
  final String title;

  const FollowListView({
    super.key,
    required this.profileUserId,
    required this.type,
    required this.title,
  });

  @override
  State<FollowListView> createState() => _FollowListViewState();
}

class _FollowListViewState extends State<FollowListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final currentUserId =
        int.tryParse(context.read<LoginViewModel>().user?.id ?? '') ?? 0;
    await context.read<ProfileViewModel>().fetchFollowList(
          userId: widget.profileUserId,
          viewerId: currentUserId,
          type: widget.type,
        );
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
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoadingFollowList) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (vm.followListError != null && vm.followList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vm.followListError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (vm.followList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.type == 'followers'
                            ? Icons.people_outline_rounded
                            : Icons.person_add_alt_1_outlined,
                        size: 46,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.type == 'followers'
                          ? 'Belum ada pengikut'
                          : 'Belum mengikuti siapapun',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: vm.followList.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72, endIndent: 16),
              itemBuilder: (context, index) {
                final user = vm.followList[index];
                return _UserListTile(user: user);
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _UserListTile extends StatelessWidget {
  final UserSummaryModel user;

  const _UserListTile({required this.user});

  Future<void> _toggleFollow(BuildContext context) async {
    final currentUserId =
        int.tryParse(context.read<LoginViewModel>().user?.id ?? '') ?? 0;

    if (currentUserId < 1) return;
    if (currentUserId == user.id) return;

    await context.read<ProfileViewModel>().toggleFollowInList(
          currentUserId: currentUserId,
          targetUserId: user.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        int.tryParse(context.read<LoginViewModel>().user?.id ?? '') ?? 0;
    final isSelf = currentUserId == user.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFE9EDF5),
        backgroundImage: user.avatarUrl.isNotEmpty
            ? NetworkImage(user.avatarUrl)
            : null,
        child: user.avatarUrl.isEmpty
            ? const Icon(Icons.person, color: Color(0xFF9CA3AF))
            : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
      ),
      subtitle: user.name.isNotEmpty
          ? Text(
              user.name,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            )
          : null,
      trailing: isSelf
          ? null
          : Consumer<ProfileViewModel>(
              builder: (context, vm, _) {
                final isFollowing = vm.followList
                    .firstWhere(
                      (u) => u.id == user.id,
                      orElse: () => user,
                    )
                    .isFollowing;

                return GestureDetector(
                  onTap: () => _toggleFollow(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isFollowing ? Colors.white : _primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFollowing
                            ? const Color(0xFFD1D5DB)
                            : _primaryColor,
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Mengikuti' : 'Ikuti',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isFollowing ? const Color(0xFF374151) : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
