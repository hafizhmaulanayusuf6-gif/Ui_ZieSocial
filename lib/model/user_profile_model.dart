import 'package:ziesocial/model/post_model.dart';

/// Model untuk data ringkas pengguna (dipakai di daftar followers/following).
class UserSummaryModel {
  final int id;
  final String username;
  final String name;
  final String avatarUrl;
  final String bio;
  final bool isFollowing;

  const UserSummaryModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    this.isFollowing = false,
  });

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      username: (json['username'] ?? 'Pengguna').toString(),
      name: (json['name'] ?? '').toString(),
      avatarUrl: PostModel.resolveImageUrl((json['avatar'] ?? '').toString()),
      bio: (json['bio'] ?? '').toString(),
      isFollowing:
          json['is_following'] == true ||
          json['is_following'] == 1 ||
          json['is_following'] == '1',
    );
  }

  UserSummaryModel copyWith({bool? isFollowing}) {
    return UserSummaryModel(
      id: id,
      username: username,
      name: name,
      avatarUrl: avatarUrl,
      bio: bio,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

/// Model lengkap untuk halaman profil pengguna.
class UserProfileModel {
  final int id;
  final String username;
  final String name;
  final String avatarUrl;
  final String bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final List<PostModel> posts;

  const UserProfileModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.posts,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};

    final rawPosts = json['posts'] is List ? json['posts'] as List : [];

    return UserProfileModel(
      id: int.tryParse('${userJson['id'] ?? 0}') ?? 0,
      username: (userJson['username'] ?? 'Pengguna').toString(),
      name: (userJson['name'] ?? '').toString(),
      avatarUrl: PostModel.resolveImageUrl(
        (userJson['avatar'] ?? '').toString(),
      ),
      bio: (userJson['bio'] ?? '').toString(),
      postsCount: int.tryParse('${userJson['posts_count'] ?? 0}') ?? 0,
      followersCount:
          int.tryParse('${userJson['followers_count'] ?? 0}') ?? 0,
      followingCount:
          int.tryParse('${userJson['following_count'] ?? 0}') ?? 0,
      isFollowing:
          userJson['is_following'] == true ||
          userJson['is_following'] == 1 ||
          userJson['is_following'] == '1',
      posts: rawPosts.map((item) {
        if (item is Map) {
          return PostModel.fromJson(Map<String, dynamic>.from(item));
        }
        return PostModel.fromJson({});
      }).toList(),
    );
  }

  UserProfileModel copyWith({
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    List<PostModel>? posts,
    int? postsCount,
  }) {
    return UserProfileModel(
      id: id,
      username: username,
      name: name,
      avatarUrl: avatarUrl,
      bio: bio,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      posts: posts ?? this.posts,
    );
  }
}
