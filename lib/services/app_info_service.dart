import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  AppInfoService._();

  static Future<PackageInfo>? _cachedInfo;

  static Future<PackageInfo> get info =>
      _cachedInfo ??= PackageInfo.fromPlatform();

  @visibleForTesting
  static void clearCache() {
    _cachedInfo = null;
  }
}
