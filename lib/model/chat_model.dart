import 'package:ziesocial/model/post_model.dart';

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

int _parseInt(dynamic value, {int fallback = 0}) {
  return _parseNullableInt(value) ?? fallback;
}

bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == '1' || normalized == 'true') return true;
  if (normalized == '0' || normalized == 'false') return false;
  return fallback;
}

class PeerModel {
  final int id;
  final String username;
  final String name;
  final String? avatar;

  const PeerModel({
    required this.id,
    required this.username,
    required this.name,
    this.avatar,
  });

  factory PeerModel.fromJson(Map<String, dynamic> json) {
    return PeerModel(
      id: _parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'avatar': avatar,
  };
}

class ConversationModel {
  final int conversationId;
  final String? lastMessage;
  final String? lastMessageTime;
  final PeerModel peer;

  const ConversationModel({
    required this.conversationId,
    this.lastMessage,
    this.lastMessageTime,
    required this.peer,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawPeer = json['peer'];
    return ConversationModel(
      conversationId: _parseInt(json['conversation_id']),
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: json['last_message_time']?.toString(),
      peer: PeerModel.fromJson(
        rawPeer is Map
            ? Map<String, dynamic>.from(rawPeer)
            : <String, dynamic>{},
      ),
    );
  }

  ConversationModel copyWith({
    int? conversationId,
    String? lastMessage,
    String? lastMessageTime,
    PeerModel? peer,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      peer: peer ?? this.peer,
    );
  }
}

class RepliedMessageSnippet {
  final int id;
  final int senderId;
  final String senderName;
  final String message;
  final bool isDeleted;

  const RepliedMessageSnippet({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.isDeleted = false,
  });

  factory RepliedMessageSnippet.fromJson(Map<String, dynamic> json) {
    return RepliedMessageSnippet(
      id: _parseInt(json['id']),
      senderId: _parseInt(json['sender_id']),
      senderName: json['sender_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isDeleted: _parseBool(json['is_deleted']),
    );
  }

  RepliedMessageSnippet copyWith({
    int? id,
    int? senderId,
    String? senderName,
    String? message,
    bool? isDeleted,
  }) {
    return RepliedMessageSnippet(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'message': message,
    'is_deleted': isDeleted,
  };
}

class SharedPostPreviewModel {
  final int? id;
  final int? userId;
  final String username;
  final String name;
  final String avatarUrl;
  final String imageUrl;
  final String caption;
  final String createdAt;
  final bool isAvailable;

  const SharedPostPreviewModel({
    this.id,
    this.userId,
    this.username = '',
    this.name = '',
    this.avatarUrl = '',
    this.imageUrl = '',
    this.caption = '',
    this.createdAt = '',
    this.isAvailable = false,
  });

  /// Hanya postingan yang tersedia dan memiliki ID valid yang boleh dibuka.
  bool get canOpen => isAvailable && id != null && id! > 0;

  factory SharedPostPreviewModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : <String, dynamic>{};

    final parsedId = _parseNullableInt(json['id']);
    final parsedUserId = _parseNullableInt(json['user_id'] ?? author['id']);
    final rawAvailable = json.containsKey('is_available')
        ? _parseBool(json['is_available'])
        : (parsedId != null && parsedId > 0);
    final available = rawAvailable && parsedId != null && parsedId > 0;

    final rawAvatar =
        (json['avatar'] ?? author['avatar'] ?? json['avatar_url'] ?? '')
            .toString();
    final rawImage = (json['image'] ?? '').toString();

    return SharedPostPreviewModel(
      id: available ? parsedId : null,
      userId: available ? parsedUserId : null,
      username: available
          ? (json['username'] ?? author['username'] ?? '').toString()
          : '',
      name: available ? (json['name'] ?? author['name'] ?? '').toString() : '',
      avatarUrl: available ? PostModel.resolveImageUrl(rawAvatar) : '',
      imageUrl: available ? PostModel.resolveImageUrl(rawImage) : '',
      caption: available ? (json['caption'] ?? '').toString() : '',
      createdAt: available
          ? (json['create_date'] ?? json['created_at'] ?? '').toString()
          : '',
      isAvailable: available,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'username': username,
    'name': name,
    'avatar': avatarUrl,
    'image': imageUrl,
    'caption': caption,
    'create_date': createdAt,
    'is_available': isAvailable,
  };
}

class ChatMessageModel {
  static const String typeText = 'text';
  static const String typeSharedPost = 'shared_post';
  static const String deletedPlaceholder = 'Pesan ini telah dihapus';
  static const String sharedPostFallbackPreview = 'Membagikan postingan';

  final int id;
  final int conversationId;
  final int senderId;
  final int? replyToMessageId;
  final RepliedMessageSnippet? replyMessage;
  final String messageType;
  final int? sharedPostId;
  final SharedPostPreviewModel? sharedPost;
  final String message;
  final bool isEdited;
  final String? editedAt;
  final bool isDeletedForEveryone;
  final String? deletedAt;
  final String createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.replyToMessageId,
    this.replyMessage,
    this.messageType = typeText,
    this.sharedPostId,
    this.sharedPost,
    required this.message,
    this.isEdited = false,
    this.editedAt,
    this.isDeletedForEveryone = false,
    this.deletedAt,
    required this.createdAt,
  });

  bool get isSharedPost => messageType == typeSharedPost;

  /// Teks preview yang aman untuk daftar percakapan.
  String get conversationPreviewText {
    if (isDeletedForEveryone) {
      return deletedPlaceholder;
    }
    if (isSharedPost) {
      final note = message.trim();
      return note.isNotEmpty ? note : sharedPostFallbackPreview;
    }
    return message;
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final isDeleted = _parseBool(json['is_deleted_for_everyone']);
    final rawType = (json['message_type'] ?? typeText).toString().trim();
    final normalizedType = rawType.isNotEmpty ? rawType : typeText;

    final rawReply = json['reply_message'];
    final parsedReply = !isDeleted && rawReply is Map
        ? RepliedMessageSnippet.fromJson(Map<String, dynamic>.from(rawReply))
        : null;

    final rawSharedPost = json['shared_post'];
    final parsedSharedPost = !isDeleted && rawSharedPost is Map
        ? SharedPostPreviewModel.fromJson(
            Map<String, dynamic>.from(rawSharedPost),
          )
        : null;

    final parsedSharedPostId = isDeleted
        ? null
        : _parseNullableInt(json['shared_post_id']) ?? parsedSharedPost?.id;

    return ChatMessageModel(
      id: _parseInt(json['id'] ?? json['message_id']),
      conversationId: _parseInt(json['conversation_id']),
      senderId: _parseInt(json['sender_id']),
      replyToMessageId: isDeleted
          ? null
          : _parseNullableInt(json['reply_to_message_id']),
      replyMessage: parsedReply,
      messageType: normalizedType,
      sharedPostId: parsedSharedPostId,
      sharedPost: parsedSharedPost,
      message: isDeleted ? '' : (json['message']?.toString() ?? ''),
      isEdited: isDeleted ? false : _parseBool(json['is_edited']),
      editedAt: isDeleted ? null : json['edited_at']?.toString(),
      isDeletedForEveryone: isDeleted,
      deletedAt: json['deleted_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  ChatMessageModel copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    int? replyToMessageId,
    bool clearReplyToMessageId = false,
    RepliedMessageSnippet? replyMessage,
    bool clearReplyMessage = false,
    String? messageType,
    int? sharedPostId,
    bool clearSharedPost = false,
    SharedPostPreviewModel? sharedPost,
    String? message,
    bool? isEdited,
    String? editedAt,
    bool clearEditedAt = false,
    bool? isDeletedForEveryone,
    String? deletedAt,
    bool clearDeletedAt = false,
    String? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      replyToMessageId: clearReplyToMessageId
          ? null
          : (replyToMessageId ?? this.replyToMessageId),
      replyMessage: clearReplyMessage
          ? null
          : (replyMessage ?? this.replyMessage),
      messageType: messageType ?? this.messageType,
      sharedPostId: clearSharedPost
          ? null
          : (sharedPostId ?? this.sharedPostId),
      sharedPost: clearSharedPost ? null : (sharedPost ?? this.sharedPost),
      message: message ?? this.message,
      isEdited: isEdited ?? this.isEdited,
      editedAt: clearEditedAt ? null : (editedAt ?? this.editedAt),
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'reply_to_message_id': replyToMessageId,
    'reply_message': replyMessage?.toJson(),
    'message_type': messageType,
    'shared_post_id': sharedPostId,
    'shared_post': sharedPost?.toJson(),
    'message': message,
    'is_edited': isEdited,
    'edited_at': editedAt,
    'is_deleted_for_everyone': isDeletedForEveryone,
    'deleted_at': deletedAt,
    'created_at': createdAt,
  };
}
