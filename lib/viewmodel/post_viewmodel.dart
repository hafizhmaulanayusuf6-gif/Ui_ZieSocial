import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/post_model.dart';

class PostViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  PostViewModel(this._apiClient);

  List<PostModel> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Set<int> _postsBeingLiked = {};
  final Set<int> _postsBeingSaved = {};

  List<PostModel> _savedPosts = [];
  bool _isLoadingSaved = false;
  String? _savedErrorMessage;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<PostModel> get savedPosts => _savedPosts;
  bool get isLoadingSaved => _isLoadingSaved;
  String? get savedErrorMessage => _savedErrorMessage;

  Future<void> fetchPosts({required int userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.posts}?user_id=$userId',
      );

      final rawPosts = response['data'];

      if (rawPosts is! List) {
        throw const FormatException(
          'Respons API tidak memiliki daftar data postingan.',
        );
      }

      _posts = rawPosts.map((item) {
        if (item is! Map) {
          throw const FormatException('Format data postingan tidak valid.');
        }

        return PostModel.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSavedPosts({required int userId}) async {
    if (userId < 1) return;

    _isLoadingSaved = true;
    _savedErrorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.savedPosts}?user_id=$userId',
      );

      final rawPosts = response['data'];

      if (rawPosts is! List) {
        throw const FormatException(
          'Respons API tidak memiliki daftar data postingan tersimpan.',
        );
      }

      _savedPosts = rawPosts.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Format data postingan tersimpan tidak valid.',
          );
        }

        return PostModel.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      _savedErrorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingSaved = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSave({
    required int userId,
    required int postId,
    PostModel? fallbackPost,
  }) async {
    if (userId < 1 || _postsBeingSaved.contains(postId)) {
      return false;
    }

    final postIndex = _posts.indexWhere((post) => post.id == postId);
    final savedIndex = _savedPosts.indexWhere((post) => post.id == postId);

    if (postIndex == -1 && savedIndex == -1 && fallbackPost == null) {
      return false;
    }

    final targetPost = postIndex != -1
        ? _posts[postIndex]
        : (savedIndex != -1 ? _savedPosts[savedIndex] : fallbackPost!);
    final willSave = !targetPost.isSaved;

    _postsBeingSaved.add(postId);

    try {
      final endpoint =
          willSave ? ApiConstants.savePost : ApiConstants.unsavePost;

      final response = await _apiClient.post(
        endpoint,
        body: {'user_id': userId, 'post_id': postId},
      );

      final newIsSaved =
          response['is_saved'] == true ||
          response['is_saved'] == 1 ||
          response['is_saved'] == '1' ||
          (response['message'] != null && willSave);

      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(isSaved: newIsSaved);
      }

      if (newIsSaved) {
        if (savedIndex == -1) {
          final postToSave =
              postIndex != -1 ? _posts[postIndex] : targetPost;
          _savedPosts.insert(0, postToSave.copyWith(isSaved: true));
        } else {
          _savedPosts[savedIndex] = _savedPosts[savedIndex].copyWith(
            isSaved: true,
          );
        }
      } else {
        _savedPosts.removeWhere((post) => post.id == postId);
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _postsBeingSaved.remove(postId);
      notifyListeners();
    }
  }

  Future<bool> toggleLike({
    required int userId,
    required int postId,
    PostModel? fallbackPost,
  }) async {
    if (userId < 1 || _postsBeingLiked.contains(postId)) {
      return false;
    }

    final index = _posts.indexWhere((post) => post.id == postId);
    final savedIndex = _savedPosts.indexWhere((post) => post.id == postId);

    if (index == -1 && savedIndex == -1 && fallbackPost == null) {
      return false;
    }

    final post = index != -1
        ? _posts[index]
        : (savedIndex != -1 ? _savedPosts[savedIndex] : fallbackPost!);
    _postsBeingLiked.add(postId);

    try {
      final endpoint = post.isLiked ? ApiConstants.unlike : ApiConstants.like;

      final response = await _apiClient.post(
        endpoint,
        body: {'user_id': userId, 'post_id': postId},
      );

      final newIsLiked =
          response['is_liked'] == true ||
          response['is_liked'] == 1 ||
          response['is_liked'] == '1';

      final newLikesCount = int.tryParse(
        '${response['like_count'] ?? post.likesCount}',
      ) ?? (post.likesCount + (newIsLiked ? 1 : -1)).clamp(0, 999999);

      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          isLiked: newIsLiked,
          likesCount: newLikesCount,
        );
      }

      if (savedIndex != -1) {
        _savedPosts[savedIndex] = _savedPosts[savedIndex].copyWith(
          isLiked: newIsLiked,
          likesCount: newLikesCount,
        );
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _postsBeingLiked.remove(postId);
      notifyListeners();
    }
  }

  Future<bool> updateCaption({
    required int userId,
    required int postId,
    required String newCaption,
  }) async {
    if (userId < 1 || postId < 1) return false;

    final index = _posts.indexWhere((post) => post.id == postId);
    final savedIndex = _savedPosts.indexWhere((post) => post.id == postId);

    if (index == -1 && savedIndex == -1) return false;

    try {
      final response = await _apiClient.post(
        ApiConstants.updatePost,
        body: {'user_id': userId, 'post_id': postId, 'caption': newCaption},
      );

      final updatedCaption = response['caption']?.toString() ?? newCaption;

      if (index != -1) {
        _posts[index] = _posts[index].copyWith(caption: updatedCaption);
      }
      if (savedIndex != -1) {
        _savedPosts[savedIndex] =
            _savedPosts[savedIndex].copyWith(caption: updatedCaption);
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost({required int userId, required int postId}) async {
    if (userId < 1 || postId < 1) return false;

    try {
      await _apiClient.post(
        ApiConstants.deletePost,
        body: {'user_id': userId, 'post_id': postId},
      );

      _posts.removeWhere((post) => post.id == postId);
      _savedPosts.removeWhere((post) => post.id == postId);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void updateCommentCount({required int postId, required int delta}) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      final currentCount = _posts[index].commentsCount;
      final newCount = (currentCount + delta) < 0 ? 0 : currentCount + delta;
      _posts[index] = _posts[index].copyWith(commentsCount: newCount);
    }

    final savedIndex = _savedPosts.indexWhere((post) => post.id == postId);
    if (savedIndex != -1) {
      final currentCount = _savedPosts[savedIndex].commentsCount;
      final newCount = (currentCount + delta) < 0 ? 0 : currentCount + delta;
      _savedPosts[savedIndex] =
          _savedPosts[savedIndex].copyWith(commentsCount: newCount);
    }

    notifyListeners();
  }
}
