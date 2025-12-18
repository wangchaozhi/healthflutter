// Platform utilities for non-Web platforms
import 'dart:io';

bool isDesktop() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

String getPathSeparator() {
  return Platform.isWindows ? '\\' : '/';
}

