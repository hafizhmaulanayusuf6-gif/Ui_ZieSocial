import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/views/chat_detail_view.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handler untuk background & terminated message.
  // Notifikasi Android dengan notification payload ditampilkan otomatis di system tray.
  debugPrint('FCM Background message: ${message.messageId}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Lazy getter: hanya diakses setelah Firebase Core selesai diinisialisasi
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  ApiClient? _apiClient;
  int? _currentUserId;
  String? _cachedToken;
  bool _isInitialized = false;
  bool _isFirebaseReady = false;

  Future<void> init(ApiClient apiClient) async {
    if (_isInitialized) return;
    _apiClient = apiClient;

    try {
      // 1. Inisialisasi Firebase Core secara aman jika belum siap
      try {
        await Firebase.initializeApp();
        _isFirebaseReady = true;
      } catch (e) {
        debugPrint('Firebase Core initializeApp warning: $e');
      }

      if (!_isFirebaseReady) {
        debugPrint(
          'FCM Service tidak dapat dilanjutkan karena Firebase Core belum siap.',
        );
        return;
      }

      // 2. Registrasi background handler
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        debugPrint('FCM onBackgroundMessage warning: $e');
      }

      // 3. Listener notifikasi dibuka saat aplikasi berada di background
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message);
        });
      } catch (e) {
        debugPrint('FCM onMessageOpenedApp warning: $e');
      }

      // 4. Listener notifikasi saat aplikasi berada di foreground
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint(
            'FCM Foreground message received: ${message.notification?.title}',
          );
        });
      } catch (e) {
        debugPrint('FCM onMessage warning: $e');
      }

      // 5. Tangani pesan ketika aplikasi dibuka dari kondisi Terminated
      // Dijadwalkan setelah frame pertama siap agar Navigator tersedia
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final initialMessage = await _fcm.getInitialMessage();
          if (initialMessage != null) {
            _handleNotificationClick(initialMessage);
          }
        } catch (e) {
          debugPrint('FCM getInitialMessage warning: $e');
        }
      });

      // 6. Tangani permintaan izin notifikasi dan pengambilan token secara asinkron
      _requestPermissionAndToken();

      _isInitialized = true;
    } catch (e) {
      debugPrint('FCM init top-level warning: $e');
    }
  }

  Future<void> _requestPermissionAndToken() async {
    try {
      // Minta izin notifikasi (wajib untuk Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Permission status: ${settings.authorizationStatus}');

      // Ambil token awal
      // ignore: deprecated_member_use
      _cachedToken = await _fcm.getToken();
      debugPrint('FCM Token: $_cachedToken');

      // Tangani event refresh token dari Firebase
      // ignore: deprecated_member_use
      _fcm.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        if (_currentUserId != null && _currentUserId! > 0) {
          _registerTokenToBackend(_currentUserId!, newToken);
        }
      });
    } catch (e) {
      debugPrint('FCM permission or token request warning: $e');
    }
  }

  /// Dipanggil saat user berhasil login
  Future<void> onUserLogin(int userId) async {
    _currentUserId = userId;
    if (!_isFirebaseReady) return;

    if (_cachedToken == null || _cachedToken!.isEmpty) {
      try {
        // ignore: deprecated_member_use
        _cachedToken = await _fcm.getToken();
      } catch (e) {
        debugPrint('FCM getToken on login warning: $e');
      }
    }

    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      await _registerTokenToBackend(userId, _cachedToken!);
    }
  }

  /// Dipanggil saat user logout
  Future<void> onUserLogout(int userId) async {
    if (_cachedToken != null &&
        _cachedToken!.isNotEmpty &&
        _apiClient != null) {
      try {
        await _apiClient!.post(
          ApiConstants.deviceRemoveToken,
          body: {'user_id': userId, 'token': _cachedToken},
        );
      } catch (e) {
        debugPrint('FCM remove token warning: $e');
      }
    }
    _currentUserId = null;
  }

  Future<void> _registerTokenToBackend(int userId, String token) async {
    if (_apiClient == null || userId < 1 || token.isEmpty) return;
    try {
      await _apiClient!.post(
        ApiConstants.deviceRegisterToken,
        body: {'user_id': userId, 'token': token, 'device_type': 'android'},
      );
      debugPrint(
        'FCM token berhasil didaftarkan ke backend untuk user $userId',
      );
    } catch (e) {
      debugPrint('FCM register token error: $e');
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final type = data['type']?.toString();
    if (type == 'chat') {
      final conversationId =
          int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '0') ?? 0;
      final senderName = data['sender_name']?.toString() ?? 'ZieSocial';

      if (conversationId > 0 && senderId > 0) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatDetailView(
                conversationId: conversationId,
                peer: PeerModel(
                  id: senderId,
                  username: senderName,
                  name: senderName,
                  avatar: null,
                ),
              ),
            ),
          );
        }
      }
    }
  }
}
