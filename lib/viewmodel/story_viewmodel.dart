import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/story_model.dart';

class StoryViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  StoryViewModel(this._apiClient);

  StoryGroupModel? _myStory;
  List<StoryGroupModel> _followingStories = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _isUploading = false;
  String? _uploadError;

  final Set<int> _viewingStoryIds = {};

  StoryGroupModel? get myStory => _myStory;
  List<StoryGroupModel> get followingStories => _followingStories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;

  List<StoryGroupModel> get allGroups {
    final list = <StoryGroupModel>[];
    if (_myStory != null && _myStory!.stories.isNotEmpty) {
      list.add(_myStory!);
    }
    list.addAll(_followingStories.where((g) => g.stories.isNotEmpty));
    return list;
  }

  Future<void> fetchStories({required int userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.storyFeed}?user_id=$userId',
      );

      final myStoryData = response['my_story'];
      if (myStoryData is Map<String, dynamic>) {
        _myStory = StoryGroupModel.fromJson(myStoryData);
      } else {
        _myStory = null;
      }

      final followingData = response['following_stories'];
      if (followingData is List) {
        _followingStories = followingData
            .whereType<Map<String, dynamic>>()
            .map((item) => StoryGroupModel.fromJson(item))
            .toList();
      } else {
        _followingStories = [];
      }
    } catch (e) {
      _errorMessage = _getReadableErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadStory({
    required int userId,
    required String imagePath,
    String? caption,
  }) async {
    _isUploading = true;
    _uploadError = null;
    notifyListeners();

    try {
      final fields = {'user_id': userId.toString()};
      if (caption != null && caption.trim().isNotEmpty) {
        fields['caption'] = caption.trim();
      }

      await _apiClient.upload(
        ApiConstants.storyCreate,
        filePath: imagePath,
        fieldName: 'image',
        fields: fields,
      );

      // Otomatis refresh feed setelah berhasil mengunggah
      await fetchStories(userId: userId);
      return true;
    } catch (e) {
      _uploadError = _getReadableErrorMessage(e);
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> markStoryViewed({
    required int viewerId,
    required int storyId,
    required int ownerId,
  }) async {
    // Jangan mencatat penayangan untuk story sendiri
    if (viewerId == ownerId || viewerId < 1 || storyId < 1) return;

    // Cegah pemanggilan berulang untuk story yang sama dalam satu sesi
    if (_viewingStoryIds.contains(storyId)) return;

    // Cek apakah story ini sudah pernah dilihat di state lokal
    final groupIndex = _followingStories.indexWhere((g) => g.userId == ownerId);
    if (groupIndex == -1) return;

    final targetGroup = _followingStories[groupIndex];
    final storyIndex = targetGroup.stories.indexWhere((s) => s.id == storyId);
    if (storyIndex == -1) return;

    if (targetGroup.stories[storyIndex].isViewed) return;

    _viewingStoryIds.add(storyId);

    // Optimistic update status isViewed pada state lokal
    final updatedStories = List<StoryItemModel>.from(targetGroup.stories);
    updatedStories[storyIndex] = updatedStories[storyIndex].copyWith(
      isViewed: true,
    );

    final allViewed = updatedStories.every((s) => s.isViewed);

    _followingStories[groupIndex] = targetGroup.copyWith(
      stories: updatedStories,
      allViewed: allViewed,
    );
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.storyView,
        body: {'user_id': viewerId, 'story_id': storyId},
      );
    } catch (e) {
      debugPrint('Gagal mengirim status view story: $e');
    } finally {
      _viewingStoryIds.remove(storyId);
    }
  }

  Future<bool> deleteStory({required int userId, required int storyId}) async {
    try {
      await _apiClient.post(
        ApiConstants.storyDelete,
        body: {'user_id': userId, 'story_id': storyId},
      );

      // Hapus dari state lokal
      if (_myStory != null) {
        final remainingStories = _myStory!.stories
            .where((s) => s.id != storyId)
            .toList();
        if (remainingStories.isEmpty) {
          _myStory = null;
        } else {
          _myStory = _myStory!.copyWith(stories: remainingStories);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getReadableErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // --- Realtime Pusher Handlers ---

  void handleRealtimeStoryCreated(Map<String, dynamic> data) {
    try {
      final storyMap = data['story'] is Map
          ? Map<String, dynamic>.from(data['story'] as Map)
          : data;
      final storyItem = StoryItemModel.fromJson(storyMap);
      final userId =
          int.tryParse('${data['user_id'] ?? storyItem.userId}') ?? 0;

      if (_myStory != null && _myStory!.userId == userId) {
        if (!_myStory!.stories.any((s) => s.id == storyItem.id)) {
          final updated = List<StoryItemModel>.from(_myStory!.stories)
            ..add(storyItem);
          _myStory = _myStory!.copyWith(stories: updated);
          notifyListeners();
        }
        return;
      }

      final fIndex = _followingStories.indexWhere((g) => g.userId == userId);
      if (fIndex != -1) {
        final group = _followingStories[fIndex];
        if (!group.stories.any((s) => s.id == storyItem.id)) {
          final updated = List<StoryItemModel>.from(group.stories)
            ..add(storyItem);
          _followingStories[fIndex] = group.copyWith(
            stories: updated,
            allViewed: false,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to handle realtime story-created: $e');
    }
  }

  void handleRealtimeStoryDeleted(int storyId, int userId) {
    if (_myStory != null && _myStory!.userId == userId) {
      final remaining = _myStory!.stories
          .where((s) => s.id != storyId)
          .toList();
      _myStory = remaining.isEmpty
          ? null
          : _myStory!.copyWith(stories: remaining);
      notifyListeners();
      return;
    }

    final fIndex = _followingStories.indexWhere((g) => g.userId == userId);
    if (fIndex != -1) {
      final group = _followingStories[fIndex];
      final remaining = group.stories.where((s) => s.id != storyId).toList();
      if (remaining.isEmpty) {
        _followingStories.removeAt(fIndex);
      } else {
        _followingStories[fIndex] = group.copyWith(stories: remaining);
      }
      notifyListeners();
    }
  }

  String _getReadableErrorMessage(dynamic error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('network')) {
      return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (raw.toLowerCase().contains('timeout')) {
      return 'Koneksi ke server terputus karena batas waktu habis.';
    }
    return raw.isNotEmpty ? raw : 'Terjadi kesalahan sistem.';
  }
}
