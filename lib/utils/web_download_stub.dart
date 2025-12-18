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
