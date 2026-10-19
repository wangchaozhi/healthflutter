import 'package:flutter/foundation.dart';

class ApiConfig {
  // API基础URL配置
  // 开发环境：本地IP或localhost

  // static const String _devBaseUrl = 'http://192.168.31.252:8080/api';
  static const String _devBaseUrl = 'http://127.0.0.1:8080/api';
  // 生产环境：公网服务器IP
  static const String _prodBaseUrl = 'http://107.182.17.20:8080/api';

  // 可通过 --dart-define=API_BASE_URL=https://example.com/api 覆盖。
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  // 自动选择URL：Debug模式使用开发环境，Release模式使用生产环境
  static String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (kReleaseMode ? _prodBaseUrl : _devBaseUrl);

  // 其他环境配置（可选）
  // Android 模拟器: http://10.0.2.2:8080/api
  // iOS 模拟器: http://localhost:8080/api
}
