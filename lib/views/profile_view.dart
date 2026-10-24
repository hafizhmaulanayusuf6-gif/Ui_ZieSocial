import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/user_profile_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/views/follow_list_view.dart';
import 'package:ziesocial/views/home_view.dart';
import 'package:ziesocial/views/login_view.dart';
import 'package:ziesocial/views/saved_posts_view.dart';

const _primaryColor = Color(0xFF4F46E5);
const _pageColor = Color(0xFFF8F9FC);

// ─────────────────────────────────────────────────────────────────────────────
/// Halaman profil yang dapat menampilkan profil sendiri maupun profil orang lain.
///
/// Jika [profileUserId] atau [userId] adalah null, maka menampilkan profil milik pengguna
/// yang sedang login.
// ─────────────────────────────────────────────────────────────────────────────
class ProfileView extends StatefulWidget {
  final int? profileUserId;
  final String? username;

  const ProfileView({
    super.key,
    int? userId,
    int? profileUserId,
    this.username,
  }) : profileUserId = profileUserId ?? userId;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _currentUserId = 0;
  int _targetProfileId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    _currentUserId =
        int.tryParse(context.read<LoginViewModel>().user?.id ?? '') ?? 0;
    _targetProfileId = widget.profileUserId ?? _currentUserId;

    if (_targetProfileId < 1) return;

    // Reset agar tidak tampil profil lama
    context.read<ProfileViewModel>().resetProfile();

    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    final futures = <Future>[
      context.read<ProfileViewModel>().fetchProfile(
            profileId: _targetProfileId,
            viewerId: _currentUserId,
          ),
      // Juga muat jumlah postingan tersimpan jika melihat profil sendiri
      if (_targetProfileId == _currentUserId)
        context
            .read<PostViewModel>()
            .fetchSavedPosts(userId: _currentUserId),
    ];
    await Future.wait(futures);
  }

  void _logout() {
    context.read<LoginViewModel>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  bool get _isOwnProfile => _targetProfileId == _currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: _buildAppBar(),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.profile == null) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (vm.errorMessage != null && vm.profile == null) {
            return _buildError(vm.errorMessage!);
          }

          if (vm.profile == null) {
            return const Center(child: Text('Profil tidak tersedia.'));
          }

          return RefreshIndicator(
            color: _primaryColor,
            onRefresh: _loadAll,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(context, vm.profile!),
                ),
                SliverToBoxAdapter(
                  child: _buildPostsHeader(vm.profile!),
                ),
                if (vm.profile!.posts.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyPosts())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = vm.profile!.posts[index];
                        return PostCard(
                          key: ValueKey('profile_post_${post.id}'),
                          post: post,
                        );
                      },
                      childCount: vm.profile!.posts.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final loginUser = context.watch<LoginViewModel>().user;
    final profileUser = context.watch<ProfileViewModel>().profile;
    final title = _isOwnProfile
        ? (loginUser?.username.isNotEmpty == true
            ? loginUser!.username
            : 'Profil')
        : (widget.username?.isNotEmpty == true
            ? widget.username!
            : (profileUser?.username.isNotEmpty == true
                ? profileUser!.username
                : 'Profil'));

    return AppBar(
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
        title,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        if (_isOwnProfile) ...[
          IconButton(
            tooltip: 'Postingan Tersimpan',
            icon: const Icon(
              Icons.bookmark_outline_rounded,
              color: _primaryColor,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedPostsView()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu akun',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF374151),
            ),
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── Header kartu profil ─────────────────────────────────────────────
  Widget _buildProfileHeader(BuildContext context, UserProfileModel profile) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: profile.isFollowing || _isOwnProfile
                  ? const LinearGradient(
                      colors: [_primaryColor, Color(0xFF9B5DE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: (!profile.isFollowing && !_isOwnProfile)
                  ? Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 2,
                    )
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFFE9EDF5),
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF9CA3AF),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Nama & username
          Text(
            profile.name.isNotEmpty ? profile.name : profile.username,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '@${profile.username}',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),

          // Bio
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              profile.bio,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Statistik: Posts · Followers · Following
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Postingan',
                count: profile.postsCount,
                onTap: null,
              ),
              _Divider(),
              _StatItem(
                label: 'Followers',
                count: profile.followersCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowListView(
                      profileUserId: profile.id,
                      type: 'followers',
                      title: 'Followers',
                    ),
                  ),
                ),
              ),
              _Divider(),
              _StatItem(
                label: 'Following',
                count: profile.followingCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowListView(
                      profileUserId: profile.id,
                      type: 'following',
                      title: 'Following',
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Tombol Follow / Unfollow (hanya tampil jika bukan profil sendiri)
          if (!_isOwnProfile)
            _FollowButton(
              profile: profile,
              currentUserId: _currentUserId,
            ),
        ],
      ),
    );
  }

  // ─── Judul grid postingan ─────────────────────────────────────────────
  Widget _buildPostsHeader(UserProfileModel profile) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.grid_on_rounded, size: 20, color: _primaryColor),
          const SizedBox(width: 8),
          Text(
            'Postingan (${profile.postsCount})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state postingan ────────────────────────────────────────────
  Widget _buildEmptyPosts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
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
              Icons.camera_alt_outlined,
              size: 40,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada postingan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Postingan akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Widget item statistik (Postingan / Followers / Following).
// ─────────────────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCount(count),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onTap != null
                  ? const Color(0xFF111827)
                  : const Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null
                  ? _primaryColor
                  : const Color(0xFF6B7280),
              fontWeight: onTap != null
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Tombol Follow / Mengikuti dengan animasi.
// ─────────────────────────────────────────────────────────────────────────────
class _FollowButton extends StatelessWidget {
  final UserProfileModel profile;
  final int currentUserId;

  const _FollowButton({
    required this.profile,
    required this.currentUserId,
  });

  Future<void> _toggle(BuildContext context) async {
    final success =
        await context.read<ProfileViewModel>().toggleFollow(
              followerId: currentUserId,
              followingId: profile.id,
            );

    if (!context.mounted) return;

    if (!success) {
      final err = context.read<ProfileViewModel>().errorMessage ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err.isEmpty ? 'Gagal memperbarui status follow.' : err,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        final isFollowing = vm.profile?.isFollowing ?? profile.isFollowing;
        final isLoading = vm.isTogglingFollow;

        return SizedBox(
          width: double.infinity,
          height: 44,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.white : _primaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFollowing
                    ? const Color(0xFFD1D5DB)
                    : _primaryColor,
                width: 1.5,
              ),
              boxShadow: isFollowing
                  ? null
                  : [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isLoading ? null : () => _toggle(context),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isFollowing
                                ? _primaryColor
                                : Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                              size: 18,
                              color: isFollowing
                                  ? const Color(0xFF374151)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFollowing ? 'Mengikuti' : 'Ikuti',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isFollowing
                                    ? const Color(0xFF374151)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
