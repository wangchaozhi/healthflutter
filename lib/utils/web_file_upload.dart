// Web platform file upload utilities
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Web端上传文件
Future<Map<String, dynamic>> uploadWebFile(
  dynamic file,
  String token,
  String baseUrl,
) async {
  try {
    // 从HTML File对象读取字节
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    
    final bytes = reader.result as List<int>;
    final fileName = file.name as String;

    // 创建multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/file/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    // 发送请求
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': data['success'] == true,
        'message': data['success'] == true ? '上传成功: $fileName' : (data['message'] ?? '上传失败'),
      };
    } else {
      return {
        'success': false,
        'message': '上传失败',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': '上传失败: $e',
    };
  }
}

