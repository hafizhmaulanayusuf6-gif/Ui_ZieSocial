import 'package:ziesocial/core/constants.dart';

class PostModel {
  final int id;
  final int userId;
  final String username;
  final String avatarUrl;
  final String imageUrl;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final String location;

  const PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.imageUrl,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.location,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return PostModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      username: json['username']?.toString() ?? 'Pengguna',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      imageUrl: resolveImageUrl(
        json['image']?.toString() ?? '',
      ),
      caption: json['caption']?.toString() ?? '',
      likesCount: int.tryParse('${json['likes_count']}') ?? 0,
      commentsCount: int.tryParse('${json['coment_count']}') ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
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
