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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
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
    return ConversationModel(
      conversationId: json['conversation_id'] is int
          ? json['conversation_id']
          : int.tryParse(json['conversation_id']?.toString() ?? '0') ?? 0,
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: json['last_message_time']?.toString(),
      peer: PeerModel.fromJson(
        json['peer'] is Map<String, dynamic>
            ? json['peer']
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

  const RepliedMessageSnippet({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
  });

  factory RepliedMessageSnippet.fromJson(Map<String, dynamic> json) {
    return RepliedMessageSnippet(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      senderName: json['sender_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'message': message,
  };
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final int? replyToMessageId;
  final RepliedMessageSnippet? replyMessage;
  final String message;
  final String createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.replyToMessageId,
    this.replyMessage,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawReply = json['reply_message'];
    return ChatMessageModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      conversationId: json['conversation_id'] is int
          ? json['conversation_id']
          : int.tryParse(json['conversation_id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      replyToMessageId: json['reply_to_message_id'] != null
          ? (json['reply_to_message_id'] is int
                ? json['reply_to_message_id']
                : int.tryParse(json['reply_to_message_id']?.toString() ?? ''))
          : null,
      replyMessage: rawReply is Map<String, dynamic>
          ? RepliedMessageSnippet.fromJson(rawReply)
          : (rawReply is Map
                ? RepliedMessageSnippet.fromJson(
                    Map<String, dynamic>.from(rawReply),
                  )
                : null),
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'reply_to_message_id': replyToMessageId,
    'reply_message': replyMessage?.toJson(),
    'message': message,
    'created_at': createdAt,
  };
}
