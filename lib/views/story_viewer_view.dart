import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/story_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

class StoryViewerView extends StatefulWidget {
  final List<StoryGroupModel> storyGroups;
  final int initialGroupIndex;

  const StoryViewerView({
    super.key,
    required this.storyGroups,
    required this.initialGroupIndex,
  });

  @override
  State<StoryViewerView> createState() => _StoryViewerViewState();
}

class _StoryViewerViewState extends State<StoryViewerView>
    with SingleTickerProviderStateMixin {
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  late AnimationController _progressController;

  late List<StoryGroupModel> _groups;
  bool _isPaused = false;
  bool _isImageLoaded = false;
  double _dragStartY = 0;

  StoryGroupModel? get _currentGroup {
    if (_currentGroupIndex < 0 || _currentGroupIndex >= _groups.length) {
      return null;
    }
    return _groups[_currentGroupIndex];
  }

  StoryItemModel? get _currentStory {
    final group = _currentGroup;
    if (group == null ||
        _currentStoryIndex < 0 ||
        _currentStoryIndex >= group.stories.length) {
      return null;
    }
    return group.stories[_currentStoryIndex];
  }

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.storyGroups);
    _currentGroupIndex = widget.initialGroupIndex.clamp(0, _groups.length - 1);

    // Buka dari story yang belum dilihat jika ada, atau mulai dari 0
    final group = _groups[_currentGroupIndex];
    final firstUnviewed = group.stories.indexWhere((s) => !s.isViewed);
    _currentStoryIndex = firstUnviewed != -1 ? firstUnviewed : 0;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCurrentStory();
    });
  }

  @override
  void dispose() {
    _progressController.stop();
    _progressController.dispose();
    super.dispose();
  }

  void _startCurrentStory() {
    final story = _currentStory;
    final group = _currentGroup;
    if (story == null || group == null) {
      Navigator.pop(context);
      return;
    }

    _isImageLoaded = false;
    _progressController.stop();
    _progressController.reset();

    // Catat status view ke backend
    final currentUserId = int.tryParse(
      context.read<LoginViewModel>().user?.id ?? '',
    );
    if (currentUserId != null && currentUserId > 0) {
      context.read<StoryViewModel>().markStoryViewed(
        viewerId: currentUserId,
        storyId: story.id,
        ownerId: group.userId,
      );
    }
  }

  void _onImageLoaded(int storyId) {
    if (!mounted || storyId != _currentStory?.id) return;
    if (_isImageLoaded) return;

    setState(() {
      _isImageLoaded = true;
    });

    if (!_isPaused) {
      _progressController.stop();
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _onImageError(int storyId) {
    if (!mounted || storyId != _currentStory?.id) return;

    setState(() {
      _isImageLoaded = false;
    });
    _progressController.stop();
  }

  void _nextStory() {
    final group = _currentGroup;
    if (group == null) return;

    if (_currentStoryIndex < group.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startCurrentStory();
    } else {
      // Pindah ke grup pengguna berikutnya
      if (_currentGroupIndex < _groups.length - 1) {
        setState(() {
          _currentGroupIndex++;
          _currentStoryIndex = 0;
        });
        _startCurrentStory();
      } else {
        // Habis semua story
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startCurrentStory();
    } else {
      // Pindah ke grup pengguna sebelumnya
      if (_currentGroupIndex > 0) {
        setState(() {
          _currentGroupIndex--;
          final prevGroup = _groups[_currentGroupIndex];
          _currentStoryIndex = prevGroup.stories.length - 1;
        });
        _startCurrentStory();
      } else {
        _startCurrentStory();
      }
    }
  }

  void _pauseProgress() {
    if (!_isPaused) {
      _isPaused = true;
      if (_isImageLoaded) {
        _progressController.stop();
      }
    }
  }

  void _resumeProgress() {
    if (_isPaused) {
      _isPaused = false;
      if (_isImageLoaded) {
        _progressController.forward();
      }
    }
  }

  Future<void> _confirmDeleteStory() async {
    final story = _currentStory;
    final group = _currentGroup;
    if (story == null || group == null || !group.isMine) return;

    _pauseProgress();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Story?'),
        content: const Text(
          'Story ini akan dihapus secara permanen dan tidak dapat dipulihkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm != true) {
      _resumeProgress();
      return;
    }

    final currentUserId = int.tryParse(
      context.read<LoginViewModel>().user?.id ?? '',
    );
    if (currentUserId == null || currentUserId < 1) {
      _resumeProgress();
      return;
    }

    final success = await context.read<StoryViewModel>().deleteStory(
      userId: currentUserId,
      storyId: story.id,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story berhasil dihapus.'),
          backgroundColor: Colors.black87,
        ),
      );

      final updatedStories = group.stories
          .where((s) => s.id != story.id)
          .toList();

      if (updatedStories.isEmpty) {
        _groups.removeAt(_currentGroupIndex);
        if (_groups.isEmpty) {
          Navigator.pop(context);
          return;
        }
        if (_currentGroupIndex >= _groups.length) {
          _currentGroupIndex = _groups.length - 1;
        }
        _currentStoryIndex = 0;
      } else {
        _groups[_currentGroupIndex] = group.copyWith(stories: updatedStories);
        if (_currentStoryIndex >= updatedStories.length) {
          _currentStoryIndex = updatedStories.length - 1;
        }
      }

      setState(() {});
      _startCurrentStory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus Story. Coba lagi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _resumeProgress();
    }
  }

  String _formatTimeAgo(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} mnt lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      } else {
        return '${difference.inDays} hari lalu';
      }
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup;
    final story = _currentStory;

    if (group == null || story == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragStart: (details) {
            _dragStartY = details.globalPosition.dy;
          },
          onVerticalDragUpdate: (details) {
            final dragDistance = details.globalPosition.dy - _dragStartY;
            if (dragDistance > 80) {
              Navigator.pop(context);
            }
          },
          onLongPressStart: (_) => _pauseProgress(),
          onLongPressEnd: (_) => _resumeProgress(),
          onLongPressCancel: () => _resumeProgress(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar Story dengan penanganan loading & frameBuilder
              Center(
                child: Image.network(
                  story.mediaUrl,
                  key: ValueKey('story_${story.id}'),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _onImageLoaded(story.id);
                          });
                          return child;
                        }
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        );
                      },
                  errorBuilder: (context, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _onImageError(story.id);
                    });
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar Story',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Area Sentuh Kiri (Previous) & Kanan (Next)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _previousStory,
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _nextStory,
                      ),
                    ),
                  ],
                ),
              ),

              // Kontrol Atas: Progress Bar & User Info
              Positioned(
                top: 8,
                left: 10,
                right: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented Progress Bar
                    Row(
                      children: List.generate(
                        group.stories.length,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                double fill = 0.0;
                                if (index < _currentStoryIndex) {
                                  fill = 1.0;
                                } else if (index == _currentStoryIndex) {
                                  fill = _isImageLoaded
                                      ? _progressController.value
                                      : 0.0;
                                } else {
                                  fill = 0.0;
                                }

                                return Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: fill,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // User Info Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white24,
                          backgroundImage: group.avatarUrl.isNotEmpty
                              ? NetworkImage(group.avatarUrl)
                              : null,
                          child: group.avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                group.username.isNotEmpty
                                    ? group.username
                                    : group.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatTimeAgo(story.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tombol Hapus (Khusus Pemilik Story)
                        if (group.isMine)
                          IconButton(
                            onPressed: _confirmDeleteStory,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: 'Hapus Story',
                          ),

                        // Tombol Tutup
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Area Bawah: Caption & Penayangan (Views Count)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption
                    if (story.caption != null && story.caption!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          story.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),

                    // Indikator Jumlah Penayangan (Hanya untuk Pemilik Story)
                    if (group.isMine) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${story.viewsCount} penonton',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
