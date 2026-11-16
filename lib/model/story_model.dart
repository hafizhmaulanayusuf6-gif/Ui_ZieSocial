import 'package:ziesocial/core/constants.dart';

class StoryItemModel {
  final int id;
  final int userId;
  final String mediaUrl;
  final String? caption;
  final String createdAt;
  final String expiresAt;
  final bool isViewed;
  final int viewsCount;

  const StoryItemModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.isViewed = false,
    this.viewsCount = 0,
  });

  factory StoryItemModel.fromJson(Map<String, dynamic> json) {
    return StoryItemModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      mediaUrl: resolveStoryUrl((json['media_url'] ?? '').toString()),
      caption: json['caption']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      expiresAt: (json['expires_at'] ?? '').toString(),
      isViewed:
          json['is_viewed'] == true ||
          json['is_viewed'] == 1 ||
          json['is_viewed'] == '1',
      viewsCount: int.tryParse('${json['views_count'] ?? 0}') ?? 0,
    );
  }

  StoryItemModel copyWith({
    int? id,
    int? userId,
    String? mediaUrl,
    String? caption,
    String? createdAt,
    String? expiresAt,
    bool? isViewed,
    int? viewsCount,
  }) {
    return StoryItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isViewed: isViewed ?? this.isViewed,
      viewsCount: viewsCount ?? this.viewsCount,
    );
  }

  static String resolveStoryUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConstants.serverRoot}/$normalizedPath';
  }
}

class StoryGroupModel {
  final int userId;
  final String username;
  final String name;
  final String avatarUrl;
  final bool isMine;
  final bool allViewed;
  final List<StoryItemModel> stories;

  const StoryGroupModel({
    required this.userId,
    required this.username,
    required this.name,
    required this.avatarUrl,
    this.isMine = false,
    this.allViewed = false,
    required this.stories,
  });

  factory StoryGroupModel.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'] as List? ?? [];
    final parsedStories = rawStories
        .whereType<Map<String, dynamic>>()
        .map((item) => StoryItemModel.fromJson(item))
        .toList();

    return StoryGroupModel(
      userId: int.tryParse('${json['user_id'] ?? 0}') ?? 0,
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      avatarUrl: StoryItemModel.resolveStoryUrl(
        (json['avatar'] ?? json['avatar_url'] ?? '').toString(),
      ),
      isMine:
          json['is_mine'] == true ||
          json['is_mine'] == 1 ||
          json['is_mine'] == '1',
      allViewed:
          json['all_viewed'] == true ||
          json['all_viewed'] == 1 ||
          json['all_viewed'] == '1',
      stories: parsedStories,
    );
  }

  StoryGroupModel copyWith({
    int? userId,
    String? username,
    String? name,
    String? avatarUrl,
    bool? isMine,
    bool? allViewed,
    List<StoryItemModel>? stories,
  }) {
    return StoryGroupModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMine: isMine ?? this.isMine,
      allViewed: allViewed ?? this.allViewed,
      stories: stories ?? this.stories,
    );
  }
}
