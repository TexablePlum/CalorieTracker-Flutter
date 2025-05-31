import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class TokenStorage {
  static const _accessKey = 'accessToken';
  static const _refreshKey = 'refreshToken';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Zapisuje oba tokeny
  Future<void> save(String access, String refresh) async {
    try {
      await Future.wait([
        _storage.write(key: _accessKey, value: access),
        _storage.write(key: _refreshKey, value: refresh),
      ]);
      debugPrint('TokenStorage: Tokens saved successfully');
    } catch (e) {
      debugPrint('TokenStorage: Error saving tokens: $e');
      rethrow;
    }
  }

  /// Pobiera access token
  Future<String?> get access async {
    try {
      final token = await _storage.read(key: _accessKey);
      return token?.isNotEmpty == true ? token : null;
    } catch (e) {
      debugPrint('TokenStorage: Error reading access token: $e');
      return null;
    }
  }

  /// Pobiera refresh token
  Future<String?> get refresh async {
    try {
      final token = await _storage.read(key: _refreshKey);
      return token?.isNotEmpty == true ? token : null;
    } catch (e) {
      debugPrint('TokenStorage: Error reading refresh token: $e');
      return null;
    }
  }

  /// Sprawdza czy użytkownik jest zalogowany (ma oba tokeny)
  Future<bool> get isLoggedIn async {
    try {
      final accessToken = await access;
      final refreshToken = await refresh;
      return accessToken != null && refreshToken != null;
    } catch (e) {
      debugPrint('TokenStorage: Error checking login status: $e');
      return false;
    }
  }

  /// Sprawdza czy ma tylko refresh token (access wygasł)
  Future<bool> get hasOnlyRefreshToken async {
    try {
      final accessToken = await access;
      final refreshToken = await refresh;
      return accessToken == null && refreshToken != null;
    } catch (e) {
      debugPrint('TokenStorage: Error checking token status: $e');
      return false;
    }
  }

  /// Czyści wszystkie tokeny
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
      debugPrint('TokenStorage: All tokens cleared');
    } catch (e) {
      debugPrint('TokenStorage: Error clearing tokens: $e');
      // Nie rethrow - lepiej kontynuować mimo błędu czyszczenia
    }
  }

  /// Czyści tylko access token (zostawia refresh)
  Future<void> clearAccessToken() async {
    try {
      await _storage.delete(key: _accessKey);
      debugPrint('TokenStorage: Access token cleared');
    } catch (e) {
      debugPrint('TokenStorage: Error clearing access token: $e');
    }
  }
}