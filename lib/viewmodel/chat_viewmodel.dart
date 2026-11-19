import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/core/pusher_service.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/model/post_model.dart';

class ChatViewModel extends ChangeNotifier {
  static const String deleteForMe = 'me';
  static const String deleteForEveryone = 'everyone';
  static const int maxMessageLength = 2000;

  final ApiClient _apiClient;
  final PusherService _pusherService = PusherService();

  ChatViewModel(this._apiClient);

  List<ConversationModel> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  List<ChatMessageModel> _messages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool _isSending = false;
  bool _isMutatingMessage = false;
  bool _isSharingPost = false;
  int? _activeConversationId;
  int? _currentUserId;

  // Realtime Presence State: conversationId -> Set of online user_ids
  final Map<int, Set<int>> _presenceMembersByConversation = {};

  // Realtime Typing State: conversationId -> Set of user_ids who are typing
  final Map<int, Set<int>> _typingUsersByConversation = {};
  // Expiration timers untuk safety typing indicator: "convId-userId" -> Timer
  final Map<String, Timer> _typingExpirationTimers = {};

  // Client-side Typing Debounce (pengirim)
  Timer? _sendTypingStopTimer;
  bool _isCurrentlyTypingSent = false;

  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;

  List<ChatMessageModel> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isSending => _isSending;
  bool get isMutatingMessage => _isMutatingMessage;
  bool get isSharingPost => _isSharingPost;
  int? get activeConversationId => _activeConversationId;

  String getConversationPreviewText(ChatMessageModel message) {
    return message.conversationPreviewText;
  }

  void setActiveConversation(int? conversationId) {
    _activeConversationId = conversationId;
  }

  void clearMessages() {
    _messages = [];
    _messagesError = null;
    _activeConversationId = null;
    notifyListeners();
  }

  /// Inisialisasi callback realtime pada PusherService
  void initRealtime({required int currentUserId}) {
    _currentUserId = currentUserId;

    _pusherService.onPresenceSubscriptionSucceeded = (convId, userIds) {
      _handlePresenceSubscriptionSucceeded(convId, userIds);
    };

    _pusherService.onPresenceMemberAdded = (convId, userId) {
      _handlePresenceMemberAdded(convId, userId);
    };

    _pusherService.onPresenceMemberRemoved = (convId, userId) {
      _handlePresenceMemberRemoved(convId, userId);
    };

    _pusherService.onTypingStarted = (convId, userId) {
      _handleTypingStarted(convId, userId);
    };

    _pusherService.onTypingStopped = (convId, userId) {
      _handleTypingStopped(convId, userId);
    };

    _pusherService.onMessageReceivedGlobal = (message) {
      onMessageReceived(message);
    };

    _pusherService.onMessageEditedGlobal =
        ({
          required conversationId,
          required messageId,
          required message,
          editedAt,
          required isLastMessage,
        }) {
          onMessageEdited(
            conversationId: conversationId,
            messageId: messageId,
            message: message,
            editedAt: editedAt,
            isLastMessage: isLastMessage,
          );
        };

    _pusherService.onMessageDeletedGlobal =
        ({
          required conversationId,
          required messageId,
          deletedAt,
          required isLastMessage,
          lastMessage,
        }) {
          onMessageDeleted(
            conversationId: conversationId,
            messageId: messageId,
            deletedAt: deletedAt,
            isLastMessage: isLastMessage,
            lastMessage: lastMessage,
          );
        };
  }

  // ==================== PRESENCE HANDLERS ====================

  void _handlePresenceSubscriptionSucceeded(int convId, Set<int> userIds) {
    final currentSet = _presenceMembersByConversation[convId];
    if (currentSet == null || !setEquals(currentSet, userIds)) {
      _presenceMembersByConversation[convId] = Set<int>.from(userIds);
      notifyListeners();
    }
  }

  void _handlePresenceMemberAdded(int convId, int userId) {
    _presenceMembersByConversation.putIfAbsent(convId, () => <int>{});
    if (_presenceMembersByConversation[convId]!.add(userId)) {
      notifyListeners();
    }
  }

  void _handlePresenceMemberRemoved(int convId, int userId) {
    if (_presenceMembersByConversation[convId]?.remove(userId) == true) {
      notifyListeners();
    }
  }

  bool isPeerOnline(int conversationId, int peerId) {
    final members = _presenceMembersByConversation[conversationId];
    if (members != null && members.contains(peerId)) {
      return true;
    }
    // Cek juga apakah peer online di salah satu percakapan aktif yang diketahui
    return isUserOnlineAnywhere(peerId);
  }

  bool isUserOnlineAnywhere(int userId) {
    for (final members in _presenceMembersByConversation.values) {
      if (members.contains(userId)) {
        return true;
      }
    }
    return false;
  }

  // ==================== TYPING HANDLERS (PENERIMA) ====================

  void _handleTypingStarted(int convId, int userId) {
    if (_currentUserId != null && userId == _currentUserId) return;

    final key = '$convId-$userId';
    _typingExpirationTimers[key]?.cancel();

    // Safety timeout: 4 detik tanpa event baru maka typing otomatis dihentikan
    _typingExpirationTimers[key] = Timer(const Duration(seconds: 4), () {
      _typingExpirationTimers.remove(key);
      if (_typingUsersByConversation[convId]?.remove(userId) == true) {
        notifyListeners();
      }
    });

    _typingUsersByConversation.putIfAbsent(convId, () => <int>{});
    if (_typingUsersByConversation[convId]!.add(userId)) {
      notifyListeners();
    }
  }

  void _handleTypingStopped(int convId, int userId) {
    if (_currentUserId != null && userId == _currentUserId) return;

    final key = '$convId-$userId';
    _typingExpirationTimers[key]?.cancel();
    _typingExpirationTimers.remove(key);

    if (_typingUsersByConversation[convId]?.remove(userId) == true) {
      notifyListeners();
    }
  }

  bool isPeerTyping(int conversationId, int peerId) {
    return _typingUsersByConversation[conversationId]?.contains(peerId) ??
        false;
  }

  // ==================== TYPING MANAGEMENT (PENGIRIM) ====================

  void onUserTyping({
    required int conversationId,
    required int userId,
    required String currentText,
  }) {
    final clean = currentText.trim();
    if (clean.isEmpty) {
      // Input kosong: segera hentikan status typing jika sebelumnya aktif
      if (_isCurrentlyTypingSent) {
        _sendTypingStopTimer?.cancel();
        _sendTypingStopTimer = null;
        _isCurrentlyTypingSent = false;
        sendTypingStatus(
          conversationId: conversationId,
          userId: userId,
          isTyping: false,
        );
      }
      return;
    }

    // Input tidak kosong: kirim typing-started jika belum dikirim
    if (!_isCurrentlyTypingSent) {
      _isCurrentlyTypingSent = true;
      sendTypingStatus(
        conversationId: conversationId,
        userId: userId,
        isTyping: true,
      );
    }

    // Reset debounce timer: jika tidak ada input baru selama 1.8 detik, kirim typing-stopped
    _sendTypingStopTimer?.cancel();
    _sendTypingStopTimer = Timer(const Duration(milliseconds: 1800), () {
      _isCurrentlyTypingSent = false;
      sendTypingStatus(
        conversationId: conversationId,
        userId: userId,
        isTyping: false,
      );
    });
  }

  void stopTypingImmediately({
    required int conversationId,
    required int userId,
  }) {
    _sendTypingStopTimer?.cancel();
    _sendTypingStopTimer = null;
    if (_isCurrentlyTypingSent) {
      _isCurrentlyTypingSent = false;
      sendTypingStatus(
        conversationId: conversationId,
        userId: userId,
        isTyping: false,
      );
    }
  }

  Future<void> sendTypingStatus({
    required int conversationId,
    required int userId,
    required bool isTyping,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.chatTyping,
        body: {
          'conversation_id': conversationId,
          'user_id': userId,
          'is_typing': isTyping,
        },
      );
    } catch (e) {
      debugPrint('Error sending typing status: $e');
    }
  }

  // ==================== CONVERSATIONS & MESSAGES ====================

  Future<void> fetchConversations({required int userId}) async {
    _currentUserId = userId;
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

      // Pastikan listener terdaftar dan subscribe ke seluruh percakapan
      initRealtime(currentUserId: userId);
      final convIds = _conversations.map((c) => c.conversationId).toList();
      _pusherService.subscribeToConversations(convIds);
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
    _currentUserId = userId;
    try {
      final res = await _apiClient.post(
        ApiConstants.chatGetOrCreate,
        body: {'user_id': userId, 'target_user_id': targetUserId},
      );

      Map<String, dynamic>? convData;
      if (res['data'] is Map) {
        convData = Map<String, dynamic>.from(res['data'] as Map);
      } else if (res['conversation_id'] != null) {
        convData = Map<String, dynamic>.from(res);
      }

      if (convData == null) return null;

      final conversation = ConversationModel.fromJson(convData);
      if (conversation.conversationId < 1) return null;

      final existingIndex = _conversations.indexWhere(
        (c) => c.conversationId == conversation.conversationId,
      );
      if (existingIndex == -1) {
        _conversations.insert(0, conversation);
        notifyListeners();
      }

      _pusherService.subscribeToConversation(conversation.conversationId);
      return existingIndex != -1
          ? _conversations[existingIndex].copyWith(peer: conversation.peer)
          : conversation;
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
    _currentUserId = userId;
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
    String message = '',
    int? replyToMessageId,
    int? sharedPostId,
  }) async {
    final cleanMessage = message.trim();
    if (sharedPostId != null && sharedPostId < 1) {
      _messagesError = 'ID postingan tidak valid.';
      notifyListeners();
      return false;
    }

    final hasSharedPost = sharedPostId != null && sharedPostId > 0;
    if (!hasSharedPost && cleanMessage.isEmpty) return false;

    if (cleanMessage.runes.length > maxMessageLength) {
      _messagesError =
          'Pesan terlalu panjang (maksimal $maxMessageLength karakter).';
      notifyListeners();
      return false;
    }

    if (_isSending) return false;

    // Hentikan status typing lokal segera saat pesan dikirim
    stopTypingImmediately(conversationId: conversationId, userId: senderId);

    _isSending = true;
    _messagesError = null;
    notifyListeners();

    try {
      final Map<String, dynamic> body = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': cleanMessage,
      };
      if (replyToMessageId != null && replyToMessageId > 0) {
        body['reply_to_message_id'] = replyToMessageId;
      }
      if (hasSharedPost) {
        body['shared_post_id'] = sharedPostId;
      }

      final res = await _apiClient.post(ApiConstants.chatSend, body: body);

      if (res['data'] is Map) {
        final sent = ChatMessageModel.fromJson(
          Map<String, dynamic>.from(res['data'] as Map),
        );
        if (_activeConversationId == conversationId) {
          _appendMessageIfNotExists(sent);
        }
        _updateConversationLastMessage(
          conversationId: conversationId,
          lastMessage: getConversationPreviewText(sent),
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

  /// Orkestrasi berbagi postingan ke percakapan (lama maupun baru via get_or_create).
  /// Mengembalikan [ConversationModel] tujuan jika pengiriman benar-benar berhasil.
  Future<ConversationModel?> sharePostToChat({
    required int senderId,
    required int postId,
    int? conversationId,
    int? targetUserId,
    String note = '',
  }) async {
    if (_isSharingPost || _isSending) return null;

    if (senderId < 1 || postId < 1) {
      _messagesError = 'Data pengguna atau postingan tidak valid.';
      notifyListeners();
      return null;
    }

    final cleanNote = note.trim();
    if (cleanNote.runes.length > maxMessageLength) {
      _messagesError =
          'Catatan terlalu panjang (maksimal $maxMessageLength karakter).';
      notifyListeners();
      return null;
    }

    _isSharingPost = true;
    _messagesError = null;
    notifyListeners();

    try {
      ConversationModel? targetConversation;

      if (conversationId != null && conversationId > 0) {
        final existingIdx = _conversations.indexWhere(
          (c) => c.conversationId == conversationId,
        );
        if (existingIdx != -1) {
          targetConversation = _conversations[existingIdx];
        }
      } else if (targetUserId != null && targetUserId > 0) {
        if (targetUserId == senderId) {
          _messagesError = 'Tidak dapat membagikan postingan ke akun sendiri.';
          return null;
        }

        final existingIdx = _conversations.indexWhere(
          (c) => c.peer.id == targetUserId,
        );
        if (existingIdx != -1) {
          targetConversation = _conversations[existingIdx];
        } else {
          targetConversation = await getOrCreateConversation(
            userId: senderId,
            targetUserId: targetUserId,
          );
        }
      } else {
        _messagesError = 'Penerima tidak valid.';
        return null;
      }

      final resolvedConvId =
          targetConversation?.conversationId ?? conversationId ?? 0;
      if (resolvedConvId < 1) {
        _messagesError ??= 'Gagal menyiapkan percakapan tujuan.';
        return null;
      }

      final sent = await sendMessage(
        conversationId: resolvedConvId,
        senderId: senderId,
        message: cleanNote,
        sharedPostId: postId,
      );

      if (!sent) return null;

      final updatedIdx = _conversations.indexWhere(
        (c) => c.conversationId == resolvedConvId,
      );
      if (updatedIdx != -1) {
        return _conversations[updatedIdx];
      }
      return targetConversation;
    } finally {
      _isSharingPost = false;
      notifyListeners();
    }
  }

  Future<bool> editMessage({
    required int messageId,
    required String newMessage,
    int? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId ?? 0;
    if (effectiveUserId < 1 || messageId < 1) {
      _messagesError = 'Data pengguna atau pesan tidak valid.';
      notifyListeners();
      return false;
    }

    final cleanMessage = newMessage.trim();
    if (cleanMessage.isEmpty) {
      _messagesError = 'Pesan tidak boleh kosong.';
      notifyListeners();
      return false;
    }
    if (cleanMessage.runes.length > maxMessageLength) {
      _messagesError =
          'Pesan terlalu panjang (maksimal $maxMessageLength karakter).';
      notifyListeners();
      return false;
    }

    // Validasi awal lokal (backend tetap menjadi otoritas utama)
    final localIndex = _messages.indexWhere((m) => m.id == messageId);
    if (localIndex != -1) {
      final localMessage = _messages[localIndex];
      if (localMessage.senderId != effectiveUserId) {
        _messagesError = 'Anda hanya dapat mengedit pesan milik sendiri.';
        notifyListeners();
        return false;
      }
      if (localMessage.isDeletedForEveryone) {
        _messagesError = 'Pesan yang sudah dihapus tidak dapat diedit.';
        notifyListeners();
        return false;
      }
      if (localMessage.messageType != ChatMessageModel.typeText) {
        _messagesError = 'Hanya pesan teks biasa yang dapat diedit.';
        notifyListeners();
        return false;
      }
    }

    if (_isMutatingMessage) return false;

    _isMutatingMessage = true;
    _messagesError = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        ApiConstants.chatEdit,
        body: {
          'user_id': effectiveUserId,
          'message_id': messageId,
          'message': cleanMessage,
        },
      );

      if (res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final convId =
            int.tryParse('${data['conversation_id'] ?? ''}') ??
            _activeConversationId ??
            0;
        final updatedText = data['message']?.toString() ?? cleanMessage;
        final editedAt = data['edited_at']?.toString();
        final isLastMessage =
            data['is_last_message'] == true ||
            data['is_last_message'] == 1 ||
            data['is_last_message'] == '1';

        onMessageEdited(
          conversationId: convId,
          messageId: messageId,
          message: updatedText,
          editedAt: editedAt,
          isLastMessage: isLastMessage,
        );
        return true;
      }
      return false;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isMutatingMessage = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMessage({
    required int messageId,
    required String deleteFor,
    int? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId ?? 0;
    final normalizedMode = deleteFor.trim().toLowerCase();

    if (effectiveUserId < 1 || messageId < 1) {
      _messagesError = 'Data pengguna atau pesan tidak valid.';
      notifyListeners();
      return false;
    }
    if (normalizedMode != deleteForMe && normalizedMode != deleteForEveryone) {
      _messagesError = 'Mode hapus pesan tidak valid.';
      notifyListeners();
      return false;
    }

    if (normalizedMode == deleteForEveryone) {
      final localIndex = _messages.indexWhere((m) => m.id == messageId);
      if (localIndex != -1 &&
          _messages[localIndex].senderId != effectiveUserId) {
        _messagesError =
            'Hanya pengirim asli yang dapat menghapus pesan untuk semua orang.';
        notifyListeners();
        return false;
      }
    }

    if (_isMutatingMessage) return false;

    _isMutatingMessage = true;
    _messagesError = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        ApiConstants.chatDelete,
        body: {
          'user_id': effectiveUserId,
          'message_id': messageId,
          'delete_for': normalizedMode,
        },
      );

      if (normalizedMode == deleteForMe) {
        final beforeLength = _messages.length;
        _messages.removeWhere((m) => m.id == messageId);
        if (_messages.length != beforeLength) {
          notifyListeners();
        }
        return true;
      }

      if (res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final convId =
            int.tryParse('${data['conversation_id'] ?? ''}') ??
            _activeConversationId ??
            0;
        final deletedAt = data['deleted_at']?.toString();
        final isLastMessage =
            data['is_last_message'] == true ||
            data['is_last_message'] == 1 ||
            data['is_last_message'] == '1';
        final lastMessage = data['last_message']?.toString();

        onMessageDeleted(
          conversationId: convId,
          messageId: messageId,
          deletedAt: deletedAt,
          isLastMessage: isLastMessage,
          lastMessage: lastMessage,
        );
        return true;
      }

      return false;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isMutatingMessage = false;
      notifyListeners();
    }
  }

  Future<PostModel?> fetchPostDetail({required int postId, int? userId}) async {
    if (postId < 1) return null;
    final effectiveUserId = userId ?? _currentUserId ?? 0;

    try {
      final res = await _apiClient.get(
        '${ApiConstants.postDetail}?post_id=$postId&user_id=$effectiveUserId',
      );
      if (res['data'] is Map) {
        return PostModel.fromJson(
          Map<String, dynamic>.from(res['data'] as Map),
        );
      }
      return null;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  void onMessageReceived(ChatMessageModel message) {
    // Bersihkan status typing dari pengirim pesan ini
    final key = '${message.conversationId}-${message.senderId}';
    _typingExpirationTimers[key]?.cancel();
    _typingExpirationTimers.remove(key);
    _typingUsersByConversation[message.conversationId]?.remove(
      message.senderId,
    );

    if (_activeConversationId == message.conversationId) {
      _appendMessageIfNotExists(message);
    }

    _updateConversationLastMessage(
      conversationId: message.conversationId,
      lastMessage: getConversationPreviewText(message),
      lastMessageTime: message.createdAt,
    );
  }

  void onMessageEdited({
    required int conversationId,
    required int messageId,
    required String message,
    String? editedAt,
    bool isLastMessage = false,
  }) {
    bool isLatestLocal = false;

    if (_activeConversationId == conversationId && _messages.isNotEmpty) {
      isLatestLocal = _messages.last.id == messageId;
      bool changed = false;

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          message: message,
          isEdited: true,
          editedAt: editedAt ?? _messages[index].editedAt,
        );
        changed = true;
      }

      // Sinkronkan snippet reply lokal yang merujuk ke pesan yang diedit
      for (int i = 0; i < _messages.length; i++) {
        final item = _messages[i];
        if (item.replyToMessageId == messageId &&
            item.replyMessage != null &&
            !item.replyMessage!.isDeleted) {
          _messages[i] = item.copyWith(
            replyMessage: item.replyMessage!.copyWith(message: message),
          );
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
      }
    }

    if (isLastMessage || isLatestLocal) {
      _updateConversationLastMessageTextOnly(
        conversationId: conversationId,
        lastMessage: message,
      );
    }
  }

  void onMessageDeleted({
    required int conversationId,
    required int messageId,
    String? deletedAt,
    bool isLastMessage = false,
    String? lastMessage,
  }) {
    final previewText = (lastMessage != null && lastMessage.trim().isNotEmpty)
        ? lastMessage.trim()
        : ChatMessageModel.deletedPlaceholder;

    bool isLatestLocal = false;

    if (_activeConversationId == conversationId && _messages.isNotEmpty) {
      isLatestLocal = _messages.last.id == messageId;
      bool changed = false;

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          message: '',
          isDeletedForEveryone: true,
          deletedAt: deletedAt ?? _messages[index].deletedAt,
          isEdited: false,
          clearEditedAt: true,
          clearReplyToMessageId: true,
          clearReplyMessage: true,
          clearSharedPost: true,
        );
        changed = true;
      }

      // Sinkronkan snippet reply lokal yang merujuk ke pesan yang dihapus
      for (int i = 0; i < _messages.length; i++) {
        final item = _messages[i];
        if (item.replyToMessageId == messageId && item.replyMessage != null) {
          _messages[i] = item.copyWith(
            replyMessage: item.replyMessage!.copyWith(
              message: ChatMessageModel.deletedPlaceholder,
              isDeleted: true,
            ),
          );
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
      }
    }

    if (isLastMessage || isLatestLocal) {
      _updateConversationLastMessageTextOnly(
        conversationId: conversationId,
        lastMessage: previewText,
      );
    }
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

  void _updateConversationLastMessageTextOnly({
    required int conversationId,
    required String lastMessage,
  }) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conversationId,
    );

    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: lastMessage,
      );
      notifyListeners();
    }
  }

  /// Reset semua state dan timers (misal saat logout)
  void clear() {
    _sendTypingStopTimer?.cancel();
    _sendTypingStopTimer = null;
    _isCurrentlyTypingSent = false;

    for (final timer in _typingExpirationTimers.values) {
      timer.cancel();
    }
    _typingExpirationTimers.clear();

    _presenceMembersByConversation.clear();
    _typingUsersByConversation.clear();
    _conversations.clear();
    _messages.clear();
    _conversationsError = null;
    _messagesError = null;
    _isSending = false;
    _isMutatingMessage = false;
    _isSharingPost = false;
    _activeConversationId = null;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sendTypingStopTimer?.cancel();
    for (final timer in _typingExpirationTimers.values) {
      timer.cancel();
    }
    _typingExpirationTimers.clear();
    super.dispose();
  }
}
