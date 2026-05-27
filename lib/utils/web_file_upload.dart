// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Web platform file upload utilities
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 打开 Web 原生文件选择器。
///
/// Android 手机浏览器上，尽量让 input.click() 贴近用户点击事件触发，
/// 比先走异步 token/权限逻辑后再打开选择器更稳定。
Future<dynamic> pickWebFile() async {
  final input = html.FileUploadInputElement()
    ..multiple = false
    ..accept = '*/*'
    ..style.display = 'none';
  input.removeAttribute('capture');

  html.document.body?.append(input);

  try {
    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) {
      return null;
    }
    return files.first;
  } finally {
    input.remove();
  }
}

Future<List<int>> _readFileBytes(html.File file) async {
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);

  await reader.onLoadEnd.first;

  final result = reader.result;
  if (result is ByteBuffer) {
    return Uint8List.view(result);
  }
  if (result is Uint8List) {
    return result;
  }
  if (result is List<int>) {
    return result;
  }

  throw StateError('无法读取文件内容');
}

/// Web端上传文件
Future<Map<String, dynamic>> uploadWebFile(
  dynamic file,
  String token,
  String baseUrl,
) async {
  try {
    final htmlFile = file as html.File;
    final bytes = await _readFileBytes(htmlFile);
    final fileName = htmlFile.name;

    // 创建multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/file/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    // 发送请求
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': data['success'] == true,
        'message': data['success'] == true
            ? '上传成功: $fileName'
            : (data['message'] ?? '上传失败'),
      };
    } else {
      return {'success': false, 'message': '上传失败'};
    }
  } catch (e) {
    return {'success': false, 'message': '上传失败: $e'};
  }
}
