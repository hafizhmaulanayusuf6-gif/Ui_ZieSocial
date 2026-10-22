import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/comment_model.dart';

class CommentViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  CommentViewModel(this._apiClient);

  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> fetchComments({required int postId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.readComments}?post_id=$postId',
      );

      final rawComments = response['data'];
      if (rawComments is! List) {
        throw const FormatException('Format data komentar tidak valid.');
      }

      _comments = rawComments.map((item) {
        if (item is! Map) {
          throw const FormatException('Item data komentar tidak valid.');
        }
        return CommentModel.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addComment({
    required int userId,
    required int postId,
    required String text,
  }) async {
    if (userId < 1 || postId < 1 || text.trim().isEmpty) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.createComment,
        body: {'user_id': userId, 'post_id': postId, 'text': text.trim()},
      );

      await fetchComments(postId: postId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteComment({
    required int userId,
    required int commentId,
  }) async {
    if (userId < 1 || commentId < 1) return false;

    try {
      await _apiClient.post(
        ApiConstants.deleteComment,
        body: {'user_id': userId, 'comment_id': commentId},
      );

      _comments.removeWhere((c) => c.id == commentId);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _comments = [];
    _errorMessage = null;
    _isLoading = false;
    _isSubmitting = false;
  }
}
