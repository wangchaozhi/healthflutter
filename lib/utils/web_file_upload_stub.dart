// Stub for non-Web platforms

Future<dynamic> pickWebFile() async {
  throw UnsupportedError('Web file picker is only supported on Web platform');
}

/// Stub for Web file upload
Future<Map<String, dynamic>> uploadWebFile(
  dynamic file,
  String token,
  String baseUrl,
) async {
  return {'success': false, 'message': 'Web文件上传仅在Web平台可用'};
}
