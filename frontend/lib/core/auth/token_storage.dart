import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  const TokenStorage({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  static const _tokenKey = 'access_token';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveToken(String token) {
    return _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() {
    return _secureStorage.delete(key: _tokenKey);
  }
}
