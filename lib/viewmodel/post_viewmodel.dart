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

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<bool> toggleLike({required int userId, required int postId}) async {
    if (userId < 1 || _postsBeingLiked.contains(postId)) {
      return false;
    }

    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return false;

    final post = _posts[index];
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
      );

      _posts[index] = post.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikesCount,
      );

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
    if (index == -1) return false;

    try {
      final response = await _apiClient.post(
        ApiConstants.updatePost,
        body: {'user_id': userId, 'post_id': postId, 'caption': newCaption},
      );

      final updatedCaption = response['caption']?.toString() ?? newCaption;
      _posts[index] = _posts[index].copyWith(caption: updatedCaption);
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
    if (index == -1) return;

    final currentCount = _posts[index].commentsCount;
    final newCount = (currentCount + delta) < 0 ? 0 : currentCount + delta;
    _posts[index] = _posts[index].copyWith(commentsCount: newCount);
    notifyListeners();
  }
}
