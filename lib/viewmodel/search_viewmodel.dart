import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/user_profile_model.dart';

/// ViewModel untuk fitur Search Account.
///
/// Mengelola pencarian pengguna berdasarkan username atau nama,
/// termasuk loading state, error state, dan debounce request.
class SearchViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  SearchViewModel(this._apiClient);

  // ─── State ───────────────────────────────────────────────────────────
  List<UserSummaryModel> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentKeyword = '';

  // Debounce timer — mencegah request terlalu sering saat mengetik
  Timer? _debounce;

  // Token untuk mencegah hasil request lama menimpa hasil terbaru
  int _requestToken = 0;
  bool _isDisposed = false;

  List<UserSummaryModel> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentKeyword => _currentKeyword;

  /// Membuat instance terpisah dengan [ApiClient] yang sama
  /// agar fitur modal/bottom sheet tidak mengubah state tab Search global.
  SearchViewModel createScopedCopy() => SearchViewModel(_apiClient);

  // ─── Public API ───────────────────────────────────────────────────────

  /// Dipanggil setiap kali TextField berubah.
  /// Menerapkan debounce 400 ms sebelum mengirim request.
  void onKeywordChanged(String keyword, {required int viewerId}) {
    if (_isDisposed) return;

    _currentKeyword = keyword.trim();

    _debounce?.cancel();

    // Kosongkan hasil jika keyword dikosongkan
    if (_currentKeyword.isEmpty) {
      _results = [];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(keyword: _currentKeyword, viewerId: viewerId);
    });
  }

  /// Bersihkan semua state (misalnya saat halaman di-dispose).
  void clearSearch() {
    if (_isDisposed) return;

    _debounce?.cancel();
    _results = [];
    _errorMessage = null;
    _isLoading = false;
    _currentKeyword = '';
    _requestToken++;
    notifyListeners();
  }

  // ─── Private ─────────────────────────────────────────────────────────

  Future<void> _search({required String keyword, required int viewerId}) async {
    if (_isDisposed) return;

    // Token baru untuk membatalkan hasil request sebelumnya jika sudah
    // ada request baru yang lebih relevan
    final token = ++_requestToken;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url =
          '${ApiConstants.searchUsers}'
          '?keyword=${Uri.encodeQueryComponent(keyword)}'
          '&viewer_id=$viewerId';

      final response = await _apiClient.get(url);

      // Abaikan jika sudah di-dispose atau ada request yang lebih baru
      if (_isDisposed || token != _requestToken) return;

      final raw = response['data'];
      if (raw is! List) {
        _results = [];
      } else {
        _results = raw
            .map((item) {
              if (item is! Map) return null;
              return UserSummaryModel.fromJson(Map<String, dynamic>.from(item));
            })
            .whereType<UserSummaryModel>()
            .toList();
      }
    } catch (e) {
      if (_isDisposed || token != _requestToken) return;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _results = [];
    } finally {
      if (!_isDisposed && token == _requestToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestToken++;
    _debounce?.cancel();
    super.dispose();
  }
}
