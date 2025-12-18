// Stub for non-Web platforms
import 'package:http/http.dart' as http;

/// Stub for Web file upload
Future<Map<String, dynamic>> uploadWebFile(
  dynamic file,
  String token,
  String baseUrl,
) async {
  return {
    'success': false,
    'message': 'Web文件上传仅在Web平台可用',
  };
}

