import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/pusher_service.dart';
import 'package:ziesocial/model/story_model.dart';
import 'package:ziesocial/viewmodel/comment_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';
import 'package:ziesocial/views/create_story_view.dart';
import 'package:ziesocial/views/login_view.dart';
import 'package:ziesocial/views/profile_view.dart';
import 'package:ziesocial/views/saved_posts_view.dart';
import 'package:ziesocial/views/story_viewer_view.dart';
import 'package:ziesocial/widget/post_card.dart';

const _primaryColor = Color(0xFF4F46E5);
const _pageColor = Color(0xFFF8F9FC);

class HomeView extends StatefulWidget {
  final bool isEmbeddedInShell;

  const HomeView({super.key, this.isEmbeddedInShell = false});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ScrollController _scrollController = ScrollController();
  final PusherService _pusherService = PusherService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final userId = int.tryParse(
        context.read<LoginViewModel>().user?.id ?? '',
      );

      if (userId == null || userId < 1) {
        return;
      }

      context.read<PostViewModel>().fetchPosts(userId: userId);
      context.read<StoryViewModel>().fetchStories(userId: userId);

      // Inisialisasi Pusher dan hubungkan event realtime
      _pusherService.init(currentUserId: userId).then((_) {
        _pusherService.subscribeToFeed();

        _pusherService.onPostCreated = (data) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimePostCreated(data);
          }
        };
        _pusherService.onPostDeleted = (postId) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimePostDeleted(postId);
          }
        };
        _pusherService.onPostLiked = (postId, likedUserId, count) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimePostLiked(
              postId,
              likedUserId,
              count,
              userId,
            );
          }
        };
        _pusherService.onPostUnliked = (postId, unlikedUserId, count) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimePostUnliked(
              postId,
              unlikedUserId,
              count,
              userId,
            );
          }
        };
        _pusherService.onCommentCreated = (postId, comment, count) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimeCommentCount(
              postId,
              count,
            );
            context.read<CommentViewModel>().handleRealtimeCommentCreated(
              postId,
              comment,
              count,
            );
          }
        };
        _pusherService.onCommentDeleted = (postId, commentId, count) {
          if (mounted) {
            context.read<PostViewModel>().handleRealtimeCommentCount(
              postId,
              count,
            );
            context.read<CommentViewModel>().handleRealtimeCommentDeleted(
              postId,
              commentId,
              count,
            );
          }
        };
        _pusherService.onStoryCreated = (data) {
          if (mounted) {
            context.read<StoryViewModel>().handleRealtimeStoryCreated(data);
          }
        };
        _pusherService.onStoryDeleted = (storyId, storyUserId) {
          if (mounted) {
            context.read<StoryViewModel>().handleRealtimeStoryDeleted(
              storyId,
              storyUserId,
            );
          }
        };
      });
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      final userId = int.tryParse(
        context.read<LoginViewModel>().user?.id ?? '',
      );
      if (userId != null && userId > 0) {
        context.read<PostViewModel>().fetchMorePosts(userId: userId);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pusherService.unsubscribeFromFeed();
    super.dispose();
  }

  void _logout(BuildContext context) {
    context.read<ProfileViewModel>().clearAll();
    context.read<LoginViewModel>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primaryColor,
          onRefresh: () async {
            final userId = int.tryParse(
              context.read<LoginViewModel>().user?.id ?? '',
            );
            if (userId != null && userId > 0) {
              await Future.wait([
                context.read<PostViewModel>().fetchPosts(
                  userId: userId,
                  refresh: true,
                ),
                context.read<StoryViewModel>().fetchStories(userId: userId),
              ]);
            }
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(onLogout: () => _logout(context)),
              ),
              const SliverToBoxAdapter(child: StoriesSection()),
              Consumer<PostViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isLoading && viewModel.posts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (viewModel.errorMessage != null &&
                      viewModel.posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('Postingan gagal dimuat.'),
                            const SizedBox(height: 8),
                            Text(
                              viewModel.errorMessage!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final userId = int.tryParse(
                                  context.read<LoginViewModel>().user?.id ?? '',
                                );

                                if (userId != null && userId > 0) {
                                  viewModel.fetchPosts(userId: userId);
                                }
                              },
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (viewModel.posts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Belum ada postingan.')),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => PostCard(
                        key: ValueKey(viewModel.posts[index].id),
                        post: viewModel.posts[index],
                      ),
                      childCount: viewModel.posts.length,
                    ),
                  );
                },
              ),
              Consumer<PostViewModel>(
                builder: (context, vm, child) {
                  if (vm.isLoadingMore) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return const SliverToBoxAdapter(child: SizedBox(height: 92));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onLogout;

  const _HomeHeader({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEEF2))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'ZieSocial',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileView()),
                );
              },
              child: const CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/100?img=12',
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              tooltip: 'Menu akun',
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _primaryColor,
                size: 24,
              ),
              onSelected: (value) {
                if (value == 'logout') onLogout();
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileView()),
                  );
                }
                if (value == 'saved') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedPostsView()),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: _primaryColor,
                      ),
                      SizedBox(width: 10),
                      Text('Profil Saya'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'saved',
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline_rounded,
                        size: 20,
                        color: _primaryColor,
                      ),
                      SizedBox(width: 10),
                      Text('Postingan Tersimpan'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
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
          ),
        ],
      ),
    );
  }
}

class StoriesSection extends StatelessWidget {
  const StoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryViewModel>(
      builder: (context, storyVm, child) {
        final followingStories = storyVm.followingStories;
        final myStory = storyVm.myStory;
        final allGroups = storyVm.allGroups;

        return Container(
          height: 112,
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEDEEF2))),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: followingStories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 13),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _YourStory(myStory: myStory, allGroups: allGroups);
              }

              final group = followingStories[index - 1];
              final groupIndexInAll = allGroups.indexOf(group);

              return _StoryItem(
                group: group,
                onTap: () {
                  if (allGroups.isNotEmpty && groupIndexInAll != -1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerView(
                          storyGroups: allGroups,
                          initialGroupIndex: groupIndexInAll,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _YourStory extends StatelessWidget {
  final StoryGroupModel? myStory;
  final List<StoryGroupModel> allGroups;

  const _YourStory({this.myStory, required this.allGroups});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return;

    final file = File(image.path);
    final fileSize = await file.length();

    if (fileSize > 5 * 1024 * 1024) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran gambar maksimal 5MB.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final ext = image.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png'];
    if (!allowedExtensions.contains(ext)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format tidak didukung. Gunakan gambar JPG atau PNG.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateStoryView(initialImage: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = context.watch<LoginViewModel>().user;
    final hasActiveStories = myStory != null && myStory!.stories.isNotEmpty;

    String avatarUrl = '';
    if (hasActiveStories && myStory!.avatarUrl.isNotEmpty) {
      avatarUrl = myStory!.avatarUrl;
    } else if (loggedInUser != null && loggedInUser.avatar.isNotEmpty) {
      avatarUrl = StoryItemModel.resolveStoryUrl(loggedInUser.avatar);
    }

    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  if (hasActiveStories) {
                    final myGroupIndex = allGroups.indexOf(myStory!);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerView(
                          storyGroups: allGroups,
                          initialGroupIndex: myGroupIndex != -1
                              ? myGroupIndex
                              : 0,
                        ),
                      ),
                    );
                  } else {
                    _pickImage(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasActiveStories
                        ? const LinearGradient(
                            colors: [
                              _primaryColor,
                              Color(0xFF9B5DE5),
                              Color(0xFFFFA45B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: !hasActiveStories
                        ? Border.all(color: const Color(0xFFE0E3EA), width: 1.5)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: const Color(0xFFEEF0F5),
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF9CA3AF),
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: GestureDetector(
                  onTap: () => _pickImage(context),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Story',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final StoryGroupModel group;
  final VoidCallback onTap;

  const _StoryItem({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnviewed = !group.allViewed;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnviewed
                    ? const LinearGradient(
                        colors: [
                          _primaryColor,
                          Color(0xFF9B5DE5),
                          Color(0xFFFFA45B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !isUnviewed
                    ? Border.all(color: const Color(0xFFE0E3EA), width: 1.5)
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFFEEF0F5),
                  backgroundImage: group.avatarUrl.isNotEmpty
                      ? NetworkImage(group.avatarUrl)
                      : null,
                  child: group.avatarUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF9CA3AF),
                          size: 24,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              group.username.isNotEmpty ? group.username : group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isUnviewed ? FontWeight.w600 : FontWeight.w500,
                color: isUnviewed
                    ? const Color(0xFF1F2937)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
