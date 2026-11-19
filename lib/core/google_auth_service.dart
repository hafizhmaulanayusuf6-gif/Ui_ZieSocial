import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ziesocial/core/constants.dart';

class GoogleAuthResult {
  final String? firebaseIdToken;
  final bool isCancelled;
  final String? errorMessage;

  const GoogleAuthResult._({
    this.firebaseIdToken,
    this.isCancelled = false,
    this.errorMessage,
  });

  factory GoogleAuthResult.success(String firebaseIdToken) {
    return GoogleAuthResult._(firebaseIdToken: firebaseIdToken);
  }

  factory GoogleAuthResult.cancelled() {
    return const GoogleAuthResult._(isCancelled: true);
  }

  factory GoogleAuthResult.failure(String message) {
    return GoogleAuthResult._(errorMessage: message);
  }

  bool get isSuccess =>
      firebaseIdToken != null && firebaseIdToken!.isNotEmpty && !isCancelled;
}

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  Future<void>? _googleInitFuture;

  Future<void> _ensureInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    _googleInitFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: ApiConstants.googleServerClientId,
    );

    try {
      await _googleInitFuture;
    } catch (_) {
      // Reset agar percobaan berikutnya bisa mencoba inisialisasi ulang jika sebelumnya gagal
      _googleInitFuture = null;
      rethrow;
    }
  }

  /// Menampilkan Google Account Picker (google_sign_in 7.2.0),
  /// melakukan autentikasi ke Firebase Auth, lalu mengembalikan Firebase ID Token.
  Future<GoogleAuthResult> signInAndGetFirebaseIdToken() async {
    try {
      await _ensureInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return GoogleAuthResult.failure(
          'Perangkat ini tidak mendukung Google Sign-In interaktif.',
        );
      }

      // 1. Tampilkan Google Account Picker via API google_sign_in 7.2.0
      final GoogleSignInAccount googleAccount = await GoogleSignIn.instance
          .authenticate();

      // 2. Ambil Google ID Token (sinkron pada google_sign_in 7.x)
      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;
      final String? googleIdToken = googleAuth.idToken;

      if (googleIdToken == null || googleIdToken.isEmpty) {
        return GoogleAuthResult.failure(
          'Gagal memperoleh kredensial dari Google. Pastikan konfigurasi OAuth benar.',
        );
      }

      // 3. Autentikasi ke Firebase Authentication
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        await signOut();
        return GoogleAuthResult.failure(
          'Autentikasi Firebase gagal. Silakan coba lagi.',
        );
      }

      // 4. Ambil Firebase ID Token untuk diverifikasi oleh backend PHP
      final String? firebaseIdToken = await firebaseUser.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        await signOut();
        return GoogleAuthResult.failure(
          'Gagal memperoleh Firebase ID Token. Silakan coba lagi.',
        );
      }

      return GoogleAuthResult.success(firebaseIdToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleAuthResult.cancelled();
      }
      debugPrint('GoogleSignInException: code=${e.code}');
      return GoogleAuthResult.failure(_mapGoogleSignInError(e));
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: code=${e.code}');
      return GoogleAuthResult.failure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('GoogleAuthService unexpected error: ${e.runtimeType}');
      return GoogleAuthResult.failure(
        'Gagal masuk dengan Google. Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
  }

  /// Membersihkan sesi Firebase Auth dan Google Sign-In (dipanggil saat logout atau rollback error backend).
  Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('FirebaseAuth signOut warning: ${e.runtimeType}');
    }

    try {
      if (_googleInitFuture != null) {
        await _googleInitFuture;
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('GoogleSignIn signOut warning: ${e.runtimeType}');
    }
  }

  String _mapGoogleSignInError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Konfigurasi Google Sign-In belum sesuai. Hubungi pengembang.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Proses masuk dengan Google terganggu. Silakan coba lagi.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Layar pemilihan akun Google tidak tersedia saat ini.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Akun Google tidak sesuai. Silakan pilih akun kembali.';
      default:
        return 'Gagal masuk dengan Google. Periksa koneksi internet Anda.';
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Koneksi internet terputus. Periksa jaringan Anda lalu coba lagi.';
      case 'user-disabled':
        return 'Akun Google ini sedang dinonaktifkan.';
      case 'invalid-credential':
      case 'account-exists-with-different-credential':
        return 'Kredensial Google tidak valid atau bentrok dengan metode login lain.';
      case 'operation-not-allowed':
        return 'Metode login Google belum diaktifkan pada server autentikasi.';
      default:
        return 'Autentikasi Firebase gagal. Silakan coba lagi.';
    }
  }
}
