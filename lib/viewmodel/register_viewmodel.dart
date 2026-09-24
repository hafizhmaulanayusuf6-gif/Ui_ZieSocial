import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';

class RegisterViewmodel extends ChangeNotifier{
  final ApiClient _apiClient;

  RegisterViewmodel(this._apiClient);

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {

      await _apiClient.post(
        ApiConstants.register,
        body: {
          'name': name,
          'username': username,
          'email': email,
          'password': password,
        },
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '',);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

