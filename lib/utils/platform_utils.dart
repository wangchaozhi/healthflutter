import 'package:flutter/foundation.dart' show kIsWeb;

// 条件导入：Web 平台导入 stub，其他平台导入实际实现
import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_stub.dart';

/// 检查是否为桌面平台（Windows/Linux/macOS）
bool get isDesktop => getIsDesktop();
