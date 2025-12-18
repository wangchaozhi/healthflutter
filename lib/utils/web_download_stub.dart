// Stub file for non-web platforms
// This file provides stub implementations for web_download functions

import 'dart:typed_data';

/// Stub for downloadFileWebDirect (non-web platforms)
Future<void> downloadFileWebDirect(String url, String token, String fileName) async {
  throw UnsupportedError('downloadFileWebDirect is only available on web platform');
}

/// Stub for downloadFileWeb (non-web platforms)
void downloadFileWeb(Uint8List bytes, String fileName) {
  throw UnsupportedError('downloadFileWeb is only available on web platform');
}

/// Stub for downloadFileNative (when imported by web platform as stub)
Future<String> downloadFileNative(String url, String token, String fileName) async {
  throw UnsupportedError('downloadFileNative is not available on web platform');
}

/// Stub for openDownloadDirectory (when imported by web platform as stub)
Future<void> openDownloadDirectory(String filePath) async {
  throw UnsupportedError('openDownloadDirectory is not available on web platform');
}
