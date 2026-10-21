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
  final bool isLiked;

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
    this.isLiked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return PostModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,

      userId: int.tryParse('${author['id'] ?? json['user_id'] ?? 0}') ?? 0,

      username:
          author['username']?.toString() ??
          json['username']?.toString() ??
          'Pengguna',

      avatarUrl:
          author['avatar']?.toString() ?? json['avatar_url']?.toString() ?? '',

      imageUrl: resolveImageUrl(json['image']?.toString() ?? ''),

      caption: json['caption']?.toString() ?? '',

      likesCount:
          int.tryParse('${json['like_count'] ?? json['likes_count'] ?? 0}') ??
          0,

      commentsCount:
          int.tryParse(
            '${json['comment_count'] ?? json['coment_count'] ?? 0}',
          ) ??
          0,

      createdAt:
          json['create_date']?.toString() ??
          json['created_at']?.toString() ??
          '',

      location: json['location']?.toString() ?? '',

      isLiked:
          json['is_liked'] == true ||
          json['is_liked'] == 1 ||
          json['is_liked']?.toString() == '1',
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

  PostModel copyWith({int? likesCount, bool? isLiked}) {
    return PostModel(
      id: id,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      imageUrl: imageUrl,
      caption: caption,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount,
      createdAt: createdAt,
      location: location,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
