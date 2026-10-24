import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/user_profile_model.dart';

class ProfileViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  ProfileViewModel(this._apiClient);

  // ─── State profil ────────────────────────────────────────────────────
  UserProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── State daftar followers / following ──────────────────────────────
  List<UserSummaryModel> _followList = [];
  bool _isLoadingFollowList = false;
  String? _followListError;

  List<UserSummaryModel> get followList => _followList;
  bool get isLoadingFollowList => _isLoadingFollowList;
  String? get followListError => _followListError;

  // ─── State tombol follow (mencegah double-tap) ───────────────────────
  bool _isTogglingFollow = false;
  bool get isTogglingFollow => _isTogglingFollow;

  // ─────────────────────────────────────────────────────────────────────
  /// Ambil profil pengguna beserta postingannya.
  /// [profileId]  : id profil yang ingin dilihat.
  /// [viewerId]   : id pengguna yang sedang login (untuk cek is_following).
  Future<void> fetchProfile({
    required int profileId,
    required int viewerId,
  }) async {
    if (profileId < 1) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.userProfile}?profile_id=$profileId&viewer_id=$viewerId',
      );

      _profile = UserProfileModel.fromJson(
        Map<String, dynamic>.from(response),
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  /// Toggle follow / unfollow pengguna.
  /// Mengembalikan [true] jika berhasil.
  Future<bool> toggleFollow({
    required int followerId,
    required int followingId,
  }) async {
    if (followerId < 1 || followingId < 1) return false;
    if (_isTogglingFollow) return false;

    if (_profile == null) return false;

    final willFollow = !_profile!.isFollowing;
    _isTogglingFollow = true;
    notifyListeners();

    try {
      final endpoint =
          willFollow ? ApiConstants.followUser : ApiConstants.unfollowUser;

      final response = await _apiClient.post(
        endpoint,
        body: {'follower_id': followerId, 'following_id': followingId},
      );

      final newIsFollowing =
          response['is_following'] == true ||
          response['is_following'] == 1 ||
          response['is_following'] == '1';

      final newFollowersCount =
          int.tryParse('${response['followers_count'] ?? ''}') ??
          (_profile!.followersCount + (willFollow ? 1 : -1)).clamp(0, 999999);

      _profile = _profile!.copyWith(
        isFollowing: newIsFollowing,
        followersCount: newFollowersCount,
      );

      // Sinkronisasi ke daftar follow jika ada
      final listIdx = _followList.indexWhere((u) => u.id == followingId);
      if (listIdx != -1) {
        _followList[listIdx] = _followList[listIdx].copyWith(
          isFollowing: newIsFollowing,
        );
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isTogglingFollow = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  /// Toggle follow untuk pengguna di dalam daftar followers/following.
  /// [currentUserId] : pengguna yang sedang login.
  /// [targetUserId]  : pengguna yang ingin di-follow/unfollow.
  Future<bool> toggleFollowInList({
    required int currentUserId,
    required int targetUserId,
  }) async {
    if (currentUserId < 1 || targetUserId < 1) return false;

    final idx = _followList.indexWhere((u) => u.id == targetUserId);
    if (idx == -1) return false;

    final willFollow = !_followList[idx].isFollowing;

    try {
      final endpoint =
          willFollow ? ApiConstants.followUser : ApiConstants.unfollowUser;

      final response = await _apiClient.post(
        endpoint,
        body: {'follower_id': currentUserId, 'following_id': targetUserId},
      );

      final newIsFollowing =
          response['is_following'] == true ||
          response['is_following'] == 1 ||
          response['is_following'] == '1';

      _followList[idx] = _followList[idx].copyWith(isFollowing: newIsFollowing);

      // Perbarui profil jika yang di-follow adalah pemilik profil aktif
      if (_profile != null && _profile!.id == targetUserId) {
        final newFollowersCount =
            int.tryParse('${response['followers_count'] ?? ''}') ??
            (_profile!.followersCount + (willFollow ? 1 : -1)).clamp(0, 999999);
        _profile = _profile!.copyWith(
          isFollowing: newIsFollowing,
          followersCount: newFollowersCount,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  /// Ambil daftar followers atau following.
  /// [type] : "followers" atau "following".
  Future<void> fetchFollowList({
    required int userId,
    required int viewerId,
    required String type,
  }) async {
    if (userId < 1) return;

    _isLoadingFollowList = true;
    _followListError = null;
    _followList = [];
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.followList}?user_id=$userId&viewer_id=$viewerId&type=$type',
      );

      final raw = response['data'];
      if (raw is! List) {
        throw const FormatException('Format data daftar tidak valid.');
      }

      _followList = raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Item data tidak valid.');
        }
        return UserSummaryModel.fromJson(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      _followListError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingFollowList = false;
      notifyListeners();
    }
  }

  /// Sinkronkan status like postingan di halaman profil
  void syncPostLike({
    required int postId,
    required bool isLiked,
    required int likesCount,
  }) {
    if (_profile == null) return;
    final updatedPosts = _profile!.posts.map((p) {
      if (p.id == postId) {
        return p.copyWith(isLiked: isLiked, likesCount: likesCount);
      }
      return p;
    }).toList();
    _profile = _profile!.copyWith(posts: updatedPosts);
    notifyListeners();
  }

  /// Sinkronkan status simpan postingan di halaman profil
  void syncPostSave({
    required int postId,
    required bool isSaved,
  }) {
    if (_profile == null) return;
    final updatedPosts = _profile!.posts.map((p) {
      if (p.id == postId) {
        return p.copyWith(isSaved: isSaved);
      }
      return p;
    }).toList();
    _profile = _profile!.copyWith(posts: updatedPosts);
    notifyListeners();
  }

  /// Reset state profil (saat berpindah ke profil lain).
  void resetProfile() {
    _profile = null;
    _errorMessage = null;
    _isLoading = false;
    _followList = [];
    _followListError = null;
    _isLoadingFollowList = false;
  }
}
