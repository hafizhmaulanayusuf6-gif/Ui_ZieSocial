import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/model/chat_model.dart';

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _isInitialized = false;
  int? _currentUserId;

  final Set<String> _subscribedChannels = {};
  final Map<int, void Function(ChatMessageModel message)> _messageListeners =
      {};

  // Presence Callbacks
  void Function(int conversationId, int userId)? onPresenceMemberAdded;
  void Function(int conversationId, int userId)? onPresenceMemberRemoved;
  void Function(int conversationId, Set<int> memberUserIds)?
  onPresenceSubscriptionSucceeded;

  // Typing Callbacks
  void Function(int conversationId, int userId)? onTypingStarted;
  void Function(int conversationId, int userId)? onTypingStopped;

  // Global Chat Message Callback
  void Function(ChatMessageModel message)? onMessageReceivedGlobal;
  void Function({
    required int conversationId,
    required int messageId,
    required String message,
    String? editedAt,
    required bool isLastMessage,
  })?
  onMessageEditedGlobal;
  void Function({
    required int conversationId,
    required int messageId,
    String? deletedAt,
    required bool isLastMessage,
    String? lastMessage,
  })?
  onMessageDeletedGlobal;

  // Connection State Callback
  void Function(String currentState, String previousState)?
  onConnectionStateChanged;

  // Realtime listeners untuk posts & feed
  void Function(Map<String, dynamic> data)? onPostCreated;
  void Function(int postId)? onPostDeleted;
  void Function(int postId, int userId, int likesCount)? onPostLiked;
  void Function(int postId, int userId, int likesCount)? onPostUnliked;
  void Function(int postId, Map<String, dynamic> comment, int commentCount)?
  onCommentCreated;
  void Function(int postId, int commentId, int commentCount)? onCommentDeleted;

  // Realtime listeners untuk stories
  void Function(Map<String, dynamic> data)? onStoryCreated;
  void Function(int storyId, int userId)? onStoryDeleted;

  int? get currentUserId => _currentUserId;
  bool get isInitialized => _isInitialized;

  Future<void> init({required int currentUserId}) async {
    _currentUserId = currentUserId;

    if (_isInitialized) return;

    try {
      await _pusher.init(
        apiKey: ApiConstants.pusherAppKey,
        cluster: ApiConstants.pusherCluster,
        onAuthorizer: _handleAuthorizer,
        onEvent: _handleGlobalEvent,
        onMemberAdded: _handleMemberAdded,
        onMemberRemoved: _handleMemberRemoved,
        onSubscriptionSucceeded: _handleSubscriptionSucceeded,
        onError: (String message, int? code, dynamic error) {
          debugPrint('Pusher Error: $message (code: $code, error: $error)');
        },
        onSubscriptionError: (String message, dynamic error) {
          debugPrint('Pusher Subscription Error: $message, error: $error');
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('Pusher State: $previousState -> $currentState');
          onConnectionStateChanged?.call(currentState, previousState);
          if (currentState.toUpperCase() == 'CONNECTED') {
            _resubscribeAll();
          }
        },
      );

      await _pusher.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Pusher init/connect warning: $e');
    }
  }

  Future<dynamic> _handleAuthorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatAuthChannel),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: {
          'socket_id': socketId,
          'channel_name': channelName,
          'user_id': _currentUserId?.toString() ?? '',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
          'Pusher Auth error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Pusher Auth exception: $e');
      return null;
    }
  }

  void _handleMemberAdded(String channelName, PusherMember member) {
    if (channelName.startsWith('presence-chat.')) {
      final convId = int.tryParse(
        channelName.replaceFirst('presence-chat.', ''),
      );
      final uid = int.tryParse(member.userId);
      if (convId != null && uid != null) {
        onPresenceMemberAdded?.call(convId, uid);
      }
    }
  }

  void _handleMemberRemoved(String channelName, PusherMember member) {
    if (channelName.startsWith('presence-chat.')) {
      final convId = int.tryParse(
        channelName.replaceFirst('presence-chat.', ''),
      );
      final uid = int.tryParse(member.userId);
      if (convId != null && uid != null) {
        onPresenceMemberRemoved?.call(convId, uid);
      }
    }
  }

  void _handleSubscriptionSucceeded(String channelName, dynamic data) {
    if (channelName.startsWith('presence-chat.')) {
      final convId = int.tryParse(
        channelName.replaceFirst('presence-chat.', ''),
      );
      if (convId != null) {
        final userIds = <int>{};
        try {
          final dynamic decoded = data is Map
              ? data
              : (data is String && data.isNotEmpty ? jsonDecode(data) : null);
          if (decoded is Map && decoded['presence'] is Map) {
            final hash = decoded['presence']['hash'];
            if (hash is Map) {
              for (final key in hash.keys) {
                final parsed = int.tryParse(key.toString());
                if (parsed != null) userIds.add(parsed);
              }
            }
            final ids = decoded['presence']['ids'];
            if (ids is List) {
              for (final id in ids) {
                final parsed = int.tryParse(id.toString());
                if (parsed != null) userIds.add(parsed);
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing presence subscription succeeded: $e');
        }

        // Ambil data members dari channel jika tersedia
        final channel = _pusher.getChannel(channelName);
        if (channel != null && channel.members.isNotEmpty) {
          for (final key in channel.members.keys) {
            final parsed = int.tryParse(key);
            if (parsed != null) userIds.add(parsed);
          }
        }

        onPresenceSubscriptionSucceeded?.call(convId, userIds);
      }
    }
  }

  void _handleGlobalEvent(PusherEvent event) {
    try {
      final dynamic raw = event.data;
      final Map<String, dynamic> data = raw is String
          ? (raw.isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : {})
          : (raw is Map ? Map<String, dynamic>.from(raw) : {});

      // Handle chat messages & typing events
      if (event.channelName.startsWith('private-chat.')) {
        final convId = int.tryParse(
          event.channelName.replaceFirst('private-chat.', ''),
        );

        if (event.eventName == 'new-message' ||
            event.eventName.endsWith('new-message')) {
          final message = ChatMessageModel.fromJson(data);
          final listener = _messageListeners[message.conversationId];
          if (listener != null) {
            listener(message);
          }
          onMessageReceivedGlobal?.call(message);
        } else if (event.eventName == 'message-edited' ||
            event.eventName.endsWith('message-edited')) {
          final targetConvId =
              int.tryParse('${data['conversation_id'] ?? ''}') ?? convId;
          final messageId = int.tryParse(
            '${data['message_id'] ?? data['id'] ?? ''}',
          );
          if (targetConvId != null && messageId != null && messageId > 0) {
            final isLastMessage =
                data['is_last_message'] == true ||
                data['is_last_message'] == 1 ||
                data['is_last_message'] == '1';
            onMessageEditedGlobal?.call(
              conversationId: targetConvId,
              messageId: messageId,
              message: data['message']?.toString() ?? '',
              editedAt: data['edited_at']?.toString(),
              isLastMessage: isLastMessage,
            );
          }
        } else if (event.eventName == 'message-deleted' ||
            event.eventName.endsWith('message-deleted')) {
          final targetConvId =
              int.tryParse('${data['conversation_id'] ?? ''}') ?? convId;
          final messageId = int.tryParse(
            '${data['message_id'] ?? data['id'] ?? ''}',
          );
          if (targetConvId != null && messageId != null && messageId > 0) {
            final isLastMessage =
                data['is_last_message'] == true ||
                data['is_last_message'] == 1 ||
                data['is_last_message'] == '1';
            onMessageDeletedGlobal?.call(
              conversationId: targetConvId,
              messageId: messageId,
              deletedAt: data['deleted_at']?.toString(),
              isLastMessage: isLastMessage,
              lastMessage: data['last_message']?.toString(),
            );
          }
        } else if (event.eventName == 'typing-started' ||
            event.eventName.endsWith('typing-started')) {
          final targetConvId =
              int.tryParse('${data['conversation_id']}') ?? convId;
          final userId = int.tryParse('${data['user_id']}');
          if (targetConvId != null && userId != null) {
            onTypingStarted?.call(targetConvId, userId);
          }
        } else if (event.eventName == 'typing-stopped' ||
            event.eventName.endsWith('typing-stopped')) {
          final targetConvId =
              int.tryParse('${data['conversation_id']}') ?? convId;
          final userId = int.tryParse('${data['user_id']}');
          if (targetConvId != null && userId != null) {
            onTypingStopped?.call(targetConvId, userId);
          }
        }
      }

      // Handle posts channel
      if (event.channelName == 'posts') {
        switch (event.eventName) {
          case 'post-created':
            onPostCreated?.call(data);
            break;
          case 'post-deleted':
            final postId = int.tryParse('${data['post_id']}');
            if (postId != null) onPostDeleted?.call(postId);
            break;
          case 'post-liked':
            final postId = int.tryParse('${data['post_id']}');
            final userId = int.tryParse('${data['user_id']}');
            final count = int.tryParse('${data['likes_count']}');
            if (postId != null && userId != null && count != null) {
              onPostLiked?.call(postId, userId, count);
            }
            break;
          case 'post-unliked':
            final postId = int.tryParse('${data['post_id']}');
            final userId = int.tryParse('${data['user_id']}');
            final count = int.tryParse('${data['likes_count']}');
            if (postId != null && userId != null && count != null) {
              onPostUnliked?.call(postId, userId, count);
            }
            break;
          case 'comment-created':
            final postId = int.tryParse('${data['post_id']}');
            final comment = data['comment'] is Map
                ? Map<String, dynamic>.from(data['comment'] as Map)
                : null;
            final count = int.tryParse('${data['comment_count']}');
            if (postId != null && comment != null && count != null) {
              onCommentCreated?.call(postId, comment, count);
            }
            break;
          case 'comment-deleted':
            final postId = int.tryParse('${data['post_id']}');
            final commentId = int.tryParse('${data['comment_id']}');
            final count = int.tryParse('${data['comment_count']}');
            if (postId != null && commentId != null && count != null) {
              onCommentDeleted?.call(postId, commentId, count);
            }
            break;
        }
      }

      // Handle stories channel
      if (event.channelName == 'stories') {
        switch (event.eventName) {
          case 'story-created':
            onStoryCreated?.call(data);
            break;
          case 'story-deleted':
            final storyId = int.tryParse('${data['story_id']}');
            final userId = int.tryParse('${data['user_id']}');
            if (storyId != null && userId != null) {
              onStoryDeleted?.call(storyId, userId);
            }
            break;
        }
      }
    } catch (e) {
      debugPrint('Failed to parse Pusher event: $e');
    }
  }

  Future<void> subscribeToFeed() async {
    try {
      if (!_subscribedChannels.contains('posts')) {
        await _pusher.subscribe(channelName: 'posts');
        _subscribedChannels.add('posts');
      }
      if (!_subscribedChannels.contains('stories')) {
        await _pusher.subscribe(channelName: 'stories');
        _subscribedChannels.add('stories');
      }
    } catch (e) {
      debugPrint('Pusher subscribe to feed warning: $e');
    }
  }

  Future<void> unsubscribeFromFeed() async {
    try {
      if (_subscribedChannels.contains('posts')) {
        await _pusher.unsubscribe(channelName: 'posts');
        _subscribedChannels.remove('posts');
      }
      if (_subscribedChannels.contains('stories')) {
        await _pusher.unsubscribe(channelName: 'stories');
        _subscribedChannels.remove('stories');
      }
    } catch (e) {
      debugPrint('Pusher unsubscribe from feed warning: $e');
    }
  }

  Future<void> subscribeToConversation(
    int conversationId, [
    void Function(ChatMessageModel message)? onMessageReceived,
  ]) async {
    if (onMessageReceived != null) {
      _messageListeners[conversationId] = onMessageReceived;
    }
    final privateChannel = 'private-chat.$conversationId';
    final presenceChannel = 'presence-chat.$conversationId';

    try {
      if (!_subscribedChannels.contains(privateChannel)) {
        await _pusher.subscribe(channelName: privateChannel);
        _subscribedChannels.add(privateChannel);
      }
      if (!_subscribedChannels.contains(presenceChannel)) {
        await _pusher.subscribe(channelName: presenceChannel);
        _subscribedChannels.add(presenceChannel);
      }
    } catch (e) {
      debugPrint(
        'Pusher subscribe warning for conversation $conversationId: $e',
      );
    }
  }

  Future<void> subscribeToConversations(List<int> conversationIds) async {
    for (final id in conversationIds) {
      await subscribeToConversation(id);
    }
  }

  void registerMessageListener(
    int conversationId,
    void Function(ChatMessageModel message) listener,
  ) {
    _messageListeners[conversationId] = listener;
  }

  void unregisterMessageListener(int conversationId) {
    _messageListeners.remove(conversationId);
  }

  Future<void> unsubscribeFromConversation(int conversationId) async {
    _messageListeners.remove(conversationId);
    final privateChannel = 'private-chat.$conversationId';
    final presenceChannel = 'presence-chat.$conversationId';

    try {
      if (_subscribedChannels.contains(privateChannel)) {
        await _pusher.unsubscribe(channelName: privateChannel);
        _subscribedChannels.remove(privateChannel);
      }
      if (_subscribedChannels.contains(presenceChannel)) {
        await _pusher.unsubscribe(channelName: presenceChannel);
        _subscribedChannels.remove(presenceChannel);
      }
    } catch (e) {
      debugPrint(
        'Pusher unsubscribe warning for conversation $conversationId: $e',
      );
    }
  }

  Future<void> _resubscribeAll() async {
    final channels = Set<String>.from(_subscribedChannels);
    for (final channel in channels) {
      try {
        await _pusher.subscribe(channelName: channel);
      } catch (e) {
        debugPrint('Pusher resubscribe warning for $channel: $e');
      }
    }
  }

  Future<void> disconnect() async {
    try {
      await _pusher.disconnect();
      _isInitialized = false;
      _currentUserId = null;
      _subscribedChannels.clear();
      _messageListeners.clear();
      onPresenceMemberAdded = null;
      onPresenceMemberRemoved = null;
      onPresenceSubscriptionSucceeded = null;
      onTypingStarted = null;
      onTypingStopped = null;
      onMessageReceivedGlobal = null;
      onMessageEditedGlobal = null;
      onMessageDeletedGlobal = null;
      onConnectionStateChanged = null;
      onPostCreated = null;
      onPostDeleted = null;
      onPostLiked = null;
      onPostUnliked = null;
      onCommentCreated = null;
      onCommentDeleted = null;
      onStoryCreated = null;
      onStoryDeleted = null;
    } catch (e) {
      debugPrint('Pusher disconnect warning: $e');
    }
  }
}
