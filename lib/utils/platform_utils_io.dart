import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 非 Web 平台的实现
bool getIsDesktop() {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
