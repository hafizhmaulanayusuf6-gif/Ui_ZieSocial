import 'package:ziesocial/core/constants.dart';

class CommentModel {
  final int id;
  final int userId;
  final int postId;
  final String text;
  final String createdAt;
  final String username;
  final String name;
  final String avatarUrl;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.postId,
    required this.text,
    required this.createdAt,
    required this.username,
    required this.name,
    required this.avatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return CommentModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${author['id'] ?? json['user_id'] ?? 0}') ?? 0,
      postId: int.tryParse('${json['post_id'] ?? 0}') ?? 0,
      text: (json['text'] ?? '').toString(),
      createdAt: (json['create_date'] ?? json['created_at'] ?? '').toString(),
      username: (author['username'] ?? json['username'] ?? 'Pengguna')
          .toString(),
      name: (author['name'] ?? json['name'] ?? 'Pengguna').toString(),
      avatarUrl: resolveImageUrl(
        (author['avatar'] ?? json['avatar_url'] ?? '').toString(),
      ),
    );
  }

  static String resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConstants.serverRoot}/$normalizedPath';
  }
}
