class ApiConstants {
  static const String serverRoot =
      'https://unpitted-alana-overwarmed.ngrok-free.dev/ziesocial';

  static String get baseUrl => '$serverRoot/api';
  static String get login => '$baseUrl/auth/login.php';
  static String get register => '$baseUrl/auth/register.php';
  static String get createPost => '$baseUrl/posts/create.php';
  static String get posts => '$baseUrl/posts/read.php';
  static String get like => '$baseUrl/posts/like.php';
  static String get unlike => '$baseUrl/posts/unlike.php';
  static String get updatePost => '$baseUrl/posts/update.php';
  static String get deletePost => '$baseUrl/posts/delete.php';
  static String get createComment => '$baseUrl/comments/create.php';
  static String get readComments => '$baseUrl/comments/read.php';
  static String get deleteComment => '$baseUrl/comments/delete.php';
  static String get savePost => '$baseUrl/posts/save.php';
  static String get unsavePost => '$baseUrl/posts/unsave.php';
  static String get savedPosts => '$baseUrl/posts/saved.php';
  static String get userProfile => '$baseUrl/users/profile.php';
  static String get followUser => '$baseUrl/users/follow.php';
  static String get unfollowUser => '$baseUrl/users/unfollow.php';
  static String get followList => '$baseUrl/users/follow_list.php';
}
