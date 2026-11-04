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

  final Map<int, void Function(ChatMessageModel message)> _messageListeners =
      {};

  Future<void> init({required int currentUserId}) async {
    _currentUserId = currentUserId;

    if (_isInitialized) return;

    try {
      await _pusher.init(
        apiKey: ApiConstants.pusherAppKey,
        cluster: ApiConstants.pusherCluster,
        onAuthorizer: _handleAuthorizer,
        onEvent: _handleGlobalEvent,
        onError: (String message, int? code, dynamic error) {
          debugPrint('Pusher Error: $message (code: $code, error: $error)');
        },
        onSubscriptionError: (String message, dynamic error) {
          debugPrint('Pusher Subscription Error: $message, error: $error');
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('Pusher State: $previousState -> $currentState');
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

  void _handleGlobalEvent(PusherEvent event) {
    if (event.eventName != 'new-message' &&
        !event.eventName.endsWith('new-message')) {
      return;
    }

    try {
      final dynamic raw = event.data;
      final Map<String, dynamic> data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);

      final message = ChatMessageModel.fromJson(data);
      final listener = _messageListeners[message.conversationId];
      if (listener != null) {
        listener(message);
      }
    } catch (e) {
      debugPrint('Failed to parse Pusher message event: $e');
    }
  }

  Future<void> subscribeToConversation(
    int conversationId,
    void Function(ChatMessageModel message) onMessageReceived,
  ) async {
    _messageListeners[conversationId] = onMessageReceived;
    final channelName = 'private-chat.$conversationId';

    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      debugPrint('Pusher subscribe warning for $channelName: $e');
    }
  }

  Future<void> unsubscribeFromConversation(int conversationId) async {
    _messageListeners.remove(conversationId);
    final channelName = 'private-chat.$conversationId';

    try {
      await _pusher.unsubscribe(channelName: channelName);
    } catch (e) {
      debugPrint('Pusher unsubscribe warning for $channelName: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _pusher.disconnect();
      _isInitialized = false;
      _messageListeners.clear();
    } catch (e) {
      debugPrint('Pusher disconnect warning: $e');
    }
  }
}
