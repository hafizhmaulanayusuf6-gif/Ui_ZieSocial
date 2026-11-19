import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/views/conversations_view.dart';
import 'package:ziesocial/views/create_post_view.dart';
import 'package:ziesocial/views/home_view.dart';
import 'package:ziesocial/views/profile_view.dart';
import 'package:ziesocial/views/search_view.dart';

const Color _primaryColor = Color(0xFF4F46E5);

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentTabIndex = 0;
  bool _isOpeningCreate = false;

  // Lazy initialization: hanya Home (index 0) yang dibuat saat startup.
  // Tab Chat (1), Search (2), dan Profile (3) baru dibuat saat pertama kali dibuka.
  final List<Widget?> _pages = [
    const HomeView(isEmbeddedInShell: true),
    null,
    null,
    null,
  ];

  void _selectTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _pages.length) return;
    setState(() {
      if (_pages[tabIndex] == null) {
        switch (tabIndex) {
          case 1:
            _pages[1] = const ConversationsView(isTab: true);
            break;
          case 2:
            _pages[2] = const SearchView(isTab: true);
            break;
          case 3:
            _pages[3] = const ProfileView(isTab: true);
            break;
        }
      }
      _currentTabIndex = tabIndex;
    });
  }

  Future<void> _openCreatePost() async {
    if (_isOpeningCreate) return;
    _isOpeningCreate = true;

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreatePostView()),
      );

      if (!mounted) return;

      final userId = int.tryParse(context.read<LoginViewModel>().user?.id ?? '');
      if (userId == null || userId < 1) return;

      await context.read<PostViewModel>().fetchPosts(userId: userId);

      if (!mounted) return;
      final profileVm = context.read<ProfileViewModel>();
      if (profileVm.ownProfile != null) {
        await profileVm.fetchOwnProfile(userId: userId, silent: true);
      }
    } finally {
      _isOpeningCreate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentTabIndex != 0) {
          setState(() => _currentTabIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentTabIndex,
          children: List.generate(
            _pages.length,
            (index) => _pages[index] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: _PersistentCapsuleNavBar(
          currentTabIndex: _currentTabIndex,
          onSelectTab: _selectTab,
          onCreatePost: _openCreatePost,
        ),
      ),
    );
  }
}

class _PersistentCapsuleNavBar extends StatefulWidget {
  final int currentTabIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onCreatePost;

  const _PersistentCapsuleNavBar({
    required this.currentTabIndex,
    required this.onSelectTab,
    required this.onCreatePost,
  });

  @override
  State<_PersistentCapsuleNavBar> createState() =>
      _PersistentCapsuleNavBarState();
}

class _PersistentCapsuleNavBarState extends State<_PersistentCapsuleNavBar> {
  static const Color _inactiveColor = Color(0xFF64748B);
  bool _isCreatePressed = false;

  double _indicatorAlignmentX() {
    switch (widget.currentTabIndex) {
      case 1: // Chat (slot 1 of 5)
        return -0.5;
      case 2: // Search (slot 3 of 5)
        return 0.5;
      case 3: // Profile (slot 4 of 5)
        return 1.0;
      case 0: // Home (slot 0 of 5)
      default:
        return -1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEDEEF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Indikator titik ungu di atas item tab aktif (Home/Chat/Search/Profile)
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: Alignment(_indicatorAlignmentX(), -1.0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 0.2,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(
                        heightFactor: 1,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildNavItem(
                    tabIndex: 0,
                    icon: Icons.home_outlined,
                    label: 'Home',
                  ),
                  _buildNavItem(
                    tabIndex: 1,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                  ),
                  _buildCreatePostButton(),
                  _buildNavItem(
                    tabIndex: 2,
                    icon: Icons.search_rounded,
                    label: 'Search',
                  ),
                  _buildNavItem(
                    tabIndex: 3,
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int tabIndex,
    required IconData icon,
    required String label,
  }) {
    final isSelected = widget.currentTabIndex == tabIndex;
    final itemColor = isSelected ? _primaryColor : _inactiveColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelectTab(tabIndex),
          borderRadius: BorderRadius.circular(20),
          splashColor: _primaryColor.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: itemColor),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, color, _) =>
                        Icon(icon, size: 22, color: color ?? itemColor),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: itemColor,
                        ),
                        child: Text(label, maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostButton() {
    return Expanded(
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (!_isCreatePressed) {
              setState(() => _isCreatePressed = true);
            }
          },
          onTapUp: (_) {
            if (_isCreatePressed) {
              setState(() => _isCreatePressed = false);
            }
          },
          onTapCancel: () {
            if (_isCreatePressed) {
              setState(() => _isCreatePressed = false);
            }
          },
          onTap: widget.onCreatePost,
          child: AnimatedScale(
            scale: _isCreatePressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.34),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
