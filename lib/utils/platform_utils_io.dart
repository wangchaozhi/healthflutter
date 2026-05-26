import 'dart:io';

bool getIsDesktop() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool getIsMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

String getPathSeparator() => Platform.isWindows ? '\\' : '/';
