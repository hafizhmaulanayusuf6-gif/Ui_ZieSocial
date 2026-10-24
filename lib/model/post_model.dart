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
  final bool isSaved;

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
    this.isSaved = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    return PostModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${author['id'] ?? json['user_id'] ?? 0}') ?? 0,
      username: (author['username'] ?? json['username'] ?? 'Pengguna')
          .toString(),
      avatarUrl: resolveImageUrl(
        (author['avatar'] ?? json['avatar_url'] ?? '').toString(),
      ),
      imageUrl: resolveImageUrl((json['image'] ?? '').toString()),
      caption: (json['caption'] ?? '').toString(),
      likesCount: int.tryParse('${json['like_count'] ?? 0}') ?? 0,
      commentsCount: int.tryParse('${json['comment_count'] ?? 0}') ?? 0,
      createdAt: (json['create_date'] ?? json['created_at'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      isLiked:
          json['is_liked'] == true ||
          json['is_liked'] == 1 ||
          json['is_liked'] == '1',
      isSaved:
          json['is_saved'] == true ||
          json['is_saved'] == 1 ||
          json['is_saved'] == '1',
    );
  }

  PostModel copyWith({
    String? caption,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      imageUrl: imageUrl,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
      location: location,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
