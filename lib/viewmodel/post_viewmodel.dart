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

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPosts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiConstants.posts);
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
}
