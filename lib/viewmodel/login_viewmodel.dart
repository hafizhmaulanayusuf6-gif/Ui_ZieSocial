import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/fcm_service.dart';
import 'package:ziesocial/core/google_auth_service.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/core/pusher_service.dart';
import 'package:ziesocial/model/user_model.dart';

class LoginViewModel extends ChangeNotifier {
  final ApiClient _apiClient;
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  LoginViewModel(this._apiClient);

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _wasGoogleCancelled = false;
  String? _errorMessage;
  UserModel? _user;

  bool get isLoading => _isLoading;
  bool get isGoogleLoading => _isGoogleLoading;
  bool get wasGoogleCancelled => _wasGoogleCancelled;
  String? get errorMessage => _errorMessage;
  UserModel? get user => _user;

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _isGoogleLoading = false;
    _wasGoogleCancelled = false;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        body: {'email': email, 'password': password},
      );
      _user = UserModel.fromJson(response['user']);

      final uid = int.tryParse(_user?.id ?? '0') ?? 0;
      if (uid > 0) {
        FcmService().onUserLogin(uid);
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    if (_isLoading) return false;

    _isLoading = true;
    _isGoogleLoading = true;
    _wasGoogleCancelled = false;
    _errorMessage = null;
    notifyListeners();

    bool firebaseAuthenticated = false;

    try {
      final authResult = await _googleAuthService.signInAndGetFirebaseIdToken();

      if (authResult.isCancelled) {
        _wasGoogleCancelled = true;
        return false;
      }

      if (!authResult.isSuccess || authResult.firebaseIdToken == null) {
        _errorMessage =
            authResult.errorMessage ?? 'Gagal masuk dengan akun Google.';
        return false;
      }

      firebaseAuthenticated = true;

      final response = await _apiClient.post(
        ApiConstants.googleLogin,
        body: {'firebase_id_token': authResult.firebaseIdToken},
      );

      final rawUser = response['user'];
      if (rawUser is! Map) {
        throw const FormatException(
          'Data pengguna tidak ditemukan di respons.',
        );
      }

      final parsedUser = UserModel.fromJson(Map<String, dynamic>.from(rawUser));
      final uid = int.tryParse(parsedUser.id) ?? 0;
      if (uid < 1) {
        throw const FormatException('ID pengguna tidak valid.');
      }

      _user = parsedUser;
      FcmService().onUserLogin(uid);
      return true;
    } on SocketException {
      if (firebaseAuthenticated) {
        await _googleAuthService.signOut();
      }
      _errorMessage =
          'Koneksi internet terputus. Periksa jaringan Anda lalu coba lagi.';
      return false;
    } on http.ClientException {
      if (firebaseAuthenticated) {
        await _googleAuthService.signOut();
      }
      _errorMessage =
          'Tidak dapat terhubung ke server ZieSocial. Silakan coba lagi.';
      return false;
    } on FormatException {
      if (firebaseAuthenticated) {
        await _googleAuthService.signOut();
      }
      _errorMessage = 'Respons server tidak sesuai format. Silakan coba lagi.';
      return false;
    } catch (e) {
      if (firebaseAuthenticated) {
        await _googleAuthService.signOut();
      }
      final cleaned = e.toString().replaceFirst('Exception: ', '').trim();
      _errorMessage = cleaned.isNotEmpty
          ? cleaned
          : 'Login dengan Google gagal. Silakan coba lagi.';
      return false;
    } finally {
      _isLoading = false;
      _isGoogleLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    final uid = int.tryParse(_user?.id ?? '0') ?? 0;
    if (uid > 0) {
      FcmService().onUserLogout(uid);
    }
    PusherService().disconnect();
    unawaited(_googleAuthService.signOut());
    _user = null;

    notifyListeners();
  }
}
