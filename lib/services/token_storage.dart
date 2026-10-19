import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'token';
  static const _kRememberedUsername = 'remembered_username';
  static const _kRememberedPassword = 'remembered_password';
  static const _kRememberPassword = 'remember_password';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String? _cachedToken;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _secureStorage.read(key: _kToken);
    } catch (error) {
      // 无可用钥匙串或 Web 非安全上下文时保持为仅内存会话。
      debugPrint('安全存储暂不可用: $error');
    }
    if (_cachedToken != null) return _cachedToken;

    // 一次性迁移旧版本存放在 SharedPreferences 中的 token。
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_kToken);
    if (_cachedToken != null) {
      try {
        await _secureStorage.write(key: _kToken, value: _cachedToken);
      } catch (error) {
        debugPrint('旧 token 仅迁移到当前内存会话: $error');
      }
      await prefs.remove(_kToken);
    }
    return _cachedToken;
  }

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _secureStorage.write(key: _kToken, value: token);
    } catch (error) {
      debugPrint('token 将仅保留在当前内存会话: $error');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    try {
      await _secureStorage.delete(key: _kToken);
    } catch (error) {
      debugPrint('清理安全存储失败: $error');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  static Future<void> saveRememberedUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRememberedUsername, username);
    await prefs.setBool(_kRememberPassword, true);
    // 旧版本曾明文保存密码，升级后立即清理。
    await prefs.remove(_kRememberedPassword);
  }

  static Future<String?> getRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRememberedPassword);
    final shouldRemember = prefs.getBool(_kRememberPassword) ?? false;
    if (!shouldRemember) return null;
    return prefs.getString(_kRememberedUsername);
  }

  static Future<void> clearRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRememberedUsername);
    await prefs.remove(_kRememberedPassword);
    await prefs.setBool(_kRememberPassword, false);
  }
}
