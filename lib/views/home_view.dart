import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/views/create_post_view.dart';
import 'package:ziesocial/views/login_view.dart';

const _primaryColor = Color(0xFF4F46E5);
const _pageColor = Color(0xFFF8F9FC);

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void _openCreatePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostView()),
    );
  }

  void _logout(BuildContext context) {
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(onLogout: () => _logout(context)),
            ),
            SliverToBoxAdapter(
              child: StoriesSection(
                onCreatePost: () => _openCreatePost(context),
              ),
            ),
            // Feed menggunakan mock data untuk membentuk UI referensi.
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => PostCard(post: _mockPosts[index]),
                childCount: _mockPosts.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
      bottomNavigationBar: const _HomeBottomNavigation(),
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
      child: Row(
        children: [
          const CircleAvatar(
            radius: 13,
            backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=12'),
          ),
          const Spacer(),
          const Text(
            'ZieSocial',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Menu akun',
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: _primaryColor,
            ),
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
    );
  }
}

class StoriesSection extends StatelessWidget {
  final VoidCallback onCreatePost;

  const StoriesSection({super.key, required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
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
        itemCount: _mockStories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          if (index == 0) return _YourStory(onTap: onCreatePost);
          return _StoryItem(story: _mockStories[index - 1]);
        },
      ),
    );
  }
}

class _YourStory extends StatelessWidget {
  final VoidCallback onTap;

  const _YourStory({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE0E3EA),
                      width: 1.5,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 23,
                    backgroundImage:
                        NetworkImage('https://i.pravatar.cc/120?img=12'),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
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
                color: Color(0xFF454956),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final StoryData story;

  const _StoryItem({required this.story});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primaryColor,
                  Color(0xFF9B5DE5),
                  Color(0xFFFFA45B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 21,
                backgroundImage: NetworkImage(story.avatarUrl),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            story.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF454956),
            ),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final PostData post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _liked = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(post.avatarUrl),
                ),
                const SizedBox(width: 8),
                Expanded(
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
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, size: 22),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE9EDF5),
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined, size: 42),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Row(
              children: [
                _ActionIcon(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked
                      ? Colors.redAccent
                      : const Color(0xFF424650),
                  onTap: () => setState(() => _liked = !_liked),
                ),
                const SizedBox(width: 15),
                _ActionIcon(
                  icon: Icons.mode_comment_outlined,
                  onTap: () {},
                ),
                const SizedBox(width: 15),
                _ActionIcon(icon: Icons.send_outlined, onTap: () {}),
                const Spacer(),
                _ActionIcon(
                  icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                  onTap: () => setState(() => _saved = !_saved),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
            child: Text(
              '${post.likes + (_liked ? 1 : 0)} likes • ${post.comments} comments',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF454956),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              '2 HOURS AGO',
              style: TextStyle(fontSize: 9, color: Color(0xFF8A8E98)),
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

class _HomeBottomNavigation extends StatelessWidget {
  const _HomeBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        // Home menjadi tab aktif; tab lain belum dihubungkan.
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _primaryColor,
      unselectedItemColor: const Color(0xFF454956),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded, size: 23),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded, size: 23),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_rounded, size: 23),
          label: 'Search',
        ),
      ],
    );
  }
}

class StoryData {
  final String username;
  final String avatarUrl;

  const StoryData({required this.username, required this.avatarUrl});
}

class PostData {
  final String username;
  final String location;
  final String avatarUrl;
  final String imageUrl;
  final int likes;
  final int comments;
  final String caption;

  const PostData({
    required this.username,
    required this.location,
    required this.avatarUrl,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.caption,
  });
}

// Data contoh dipisahkan dari widget agar mudah diganti dengan data API nanti.
const List<StoryData> _mockStories = [
  StoryData(
    username: 'sarah.j',
    avatarUrl: 'https://i.pravatar.cc/120?img=47',
  ),
  StoryData(
    username: 'mike_dev',
    avatarUrl: 'https://i.pravatar.cc/120?img=12',
  ),
  StoryData(
    username: 'art.flow',
    avatarUrl: 'https://i.pravatar.cc/120?img=5',
  ),
  StoryData(
    username: 'doggo',
    avatarUrl: 'https://i.pravatar.cc/120?img=11',
  ),
  StoryData(
    username: 'nina.jpg',
    avatarUrl: 'https://i.pravatar.cc/120?img=44',
  ),
];

const List<PostData> _mockPosts = [
  PostData(
    username: 'wander.lust',
    location: 'Bali, Indonesia',
    avatarUrl: 'https://i.pravatar.cc/120?img=32',
    imageUrl:
        'https://images.unsplash.com/photo-1518548419970-58e3b4079ab2?auto=format&fit=crop&w=1000&q=85',
    likes: 125,
    comments: 12,
    caption: 'Exploring paradise in Bali! 🌴✨ #travel #wanderlust',
  ),
];
