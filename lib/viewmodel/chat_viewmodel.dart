import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/chat_model.dart';

class ChatViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  ChatViewModel(this._apiClient);

  List<ConversationModel> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  List<ChatMessageModel> _messages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool _isSending = false;
  int? _activeConversationId;

  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;

  List<ChatMessageModel> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isSending => _isSending;
  int? get activeConversationId => _activeConversationId;

  void setActiveConversation(int? conversationId) {
    _activeConversationId = conversationId;
  }

  void clearMessages() {
    _messages = [];
    _messagesError = null;
    _activeConversationId = null;
    notifyListeners();
  }

  Future<void> fetchConversations({required int userId}) async {
    _isLoadingConversations = true;
    _conversationsError = null;
    notifyListeners();

    try {
      final res = await _apiClient.get(
        '${ApiConstants.chatConversations}?user_id=$userId',
      );

      final List data = res['data'] ?? [];
      _conversations = data
          .map(
            (item) =>
                ConversationModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      _conversationsError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<ConversationModel?> getOrCreateConversation({
    required int userId,
    required int targetUserId,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiConstants.chatGetOrCreate,
        body: {'user_id': userId, 'target_user_id': targetUserId},
      );

      if (res['data'] != null) {
        final convData = Map<String, dynamic>.from(res['data']);
        return ConversationModel.fromJson(convData);
      }
      return null;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchMessages({
    required int conversationId,
    required int userId,
  }) async {
    _activeConversationId = conversationId;
    _isLoadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      final res = await _apiClient.get(
        '${ApiConstants.chatMessages}?conversation_id=$conversationId&user_id=$userId',
      );

      final List data = res['data'] ?? [];
      _messages = data
          .map(
            (item) =>
                ChatMessageModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required int conversationId,
    required int senderId,
    required String message,
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty || _isSending) return false;

    _isSending = true;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        ApiConstants.chatSend,
        body: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message': cleanMessage,
        },
      );

      if (res['data'] != null) {
        final sent = ChatMessageModel.fromJson(
          Map<String, dynamic>.from(res['data']),
        );
        _appendMessageIfNotExists(sent);
        _updateConversationLastMessage(
          conversationId: conversationId,
          lastMessage: sent.message,
          lastMessageTime: sent.createdAt,
        );
        return true;
      }
      return false;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void onMessageReceived(ChatMessageModel message) {
    if (_activeConversationId == message.conversationId) {
      _appendMessageIfNotExists(message);
    }

    _updateConversationLastMessage(
      conversationId: message.conversationId,
      lastMessage: message.message,
      lastMessageTime: message.createdAt,
    );
  }

  void _appendMessageIfNotExists(ChatMessageModel message) {
    final exists = _messages.any((m) => m.id == message.id);
    if (!exists) {
      _messages.add(message);
      notifyListeners();
    }
  }

  void _updateConversationLastMessage({
    required int conversationId,
    required String lastMessage,
    required String lastMessageTime,
  }) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conversationId,
    );

    if (index != -1) {
      final old = _conversations[index];
      final updated = old.copyWith(
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
      );
      _conversations.removeAt(index);
      _conversations.insert(0, updated);
      notifyListeners();
    }
  }
}
