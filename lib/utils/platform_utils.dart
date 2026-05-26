// 条件导入：Web 平台导入 stub，其他平台导入实际实现
import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_stub.dart';

/// 桌面平台（Windows/Linux/macOS）
bool get isDesktop => getIsDesktop();

/// 移动平台（Android/iOS）
bool get isMobile => getIsMobile();

/// 当前平台的路径分隔符
String get pathSeparator => getPathSeparator();
