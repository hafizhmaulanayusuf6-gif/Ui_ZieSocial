class ApiConstants {
  // Base URL backend melalui ngrok.
  static const String serverRoot =
      'https://unpitted-alana-overwarmed.ngrok-free.dev/BackEnd_ziesocial';

  // Base URL API.
  static String get baseUrl => '$serverRoot/api';

  // Authentication
  static String get login => '$baseUrl/auth/login.php';
  static String get register => '$baseUrl/auth/register.php';

  // Posts
  static String get createPost => '$baseUrl/posts/create.php';
  static String get posts => '$baseUrl/posts/read.php';
  static String get like => '$baseUrl/posts/like.php';
  static String get unlike => '$baseUrl/posts/unlike.php';
  static String get updatePost => '$baseUrl/posts/update.php';
  static String get deletePost => '$baseUrl/posts/delete.php';
  static String get savePost => '$baseUrl/posts/save.php';
  static String get unsavePost => '$baseUrl/posts/unsave.php';
  static String get savedPosts => '$baseUrl/posts/saved.php';

  // Comments
  static String get createComment => '$baseUrl/comments/create.php';
  static String get readComments => '$baseUrl/comments/read.php';
  static String get deleteComment => '$baseUrl/comments/delete.php';

  // Users
  static String get userProfile => '$baseUrl/users/profile.php';
  static String get followUser => '$baseUrl/users/follow.php';
  static String get unfollowUser => '$baseUrl/users/unfollow.php';
  static String get followList => '$baseUrl/users/follow_list.php';
  static String get searchUsers => '$baseUrl/users/search.php';

  // Chat / Direct Message Endpoints
  static String get chatConversations => '$baseUrl/chat/conversations.php';
  static String get chatGetOrCreate => '$baseUrl/chat/get_or_create.php';
  static String get chatMessages => '$baseUrl/chat/messages.php';
  static String get chatSend => '$baseUrl/chat/send.php';
  static String get chatAuthChannel => '$baseUrl/chat/auth_channel.php';

  // Pusher Client Configuration
  static const String pusherAppKey = '7773b9e0277a3e998164';
  static const String pusherCluster = 'ap1';
}
