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
}
