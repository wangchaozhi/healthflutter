import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'token';
  static const _kRememberedUsername = 'remembered_username';
  static const _kRememberedPassword = 'remembered_password';
  static const _kRememberPassword = 'remember_password';

  static String? _cachedToken;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_kToken);
    return _cachedToken;
  }

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  static Future<void> saveRememberedCredentials(
      String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRememberedUsername, username);
    await prefs.setString(_kRememberedPassword, password);
    await prefs.setBool(_kRememberPassword, true);
  }

  static Future<({String? username, String? password})>
      getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRemember = prefs.getBool(_kRememberPassword) ?? false;
    if (!shouldRemember) return (username: null, password: null);
    return (
      username: prefs.getString(_kRememberedUsername),
      password: prefs.getString(_kRememberedPassword),
    );
  }

  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRememberedUsername);
    await prefs.remove(_kRememberedPassword);
    await prefs.setBool(_kRememberPassword, false);
  }
}
