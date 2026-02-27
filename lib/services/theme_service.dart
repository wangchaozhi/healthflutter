import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_themes.dart';

/// 主题服务：管理主题切换与持久化
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  AppThemeId _themeId = AppThemeId.teal;
  bool _initialized = false;

  AppThemeId get themeId => _themeId;
  bool get isInitialized => _initialized;

  AppThemeColors get colors => AppThemes.colorsFor(_themeId);
  ThemeData get themeData => AppThemes.themeFor(_themeId);

  /// 初始化：从本地读取已保存的主题
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(AppThemes.storageKey);
      if (key != null) {
        _themeId = AppThemeId.fromKey(key);
      }
    } catch (e) {
      debugPrint('ThemeService init error: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  /// 切换主题
  Future<void> setTheme(AppThemeId id) async {
    if (_themeId == id) return;
    _themeId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppThemes.storageKey, id.key);
    } catch (e) {
      debugPrint('ThemeService setTheme error: $e');
    }
    notifyListeners();
  }
}
