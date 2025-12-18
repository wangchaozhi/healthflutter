// File upload utilities for non-Web platforms
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

// 从文件路径上传文件
Future<http.MultipartFile> createMultipartFileFromPath(String path) async {
  return await http.MultipartFile.fromPath('file', path);
}

// 从 PlatformFile 创建 File 对象并上传
Future<void> uploadFileFromPlatformFile(
  PlatformFile platformFile,
  String token,
  String baseUrl,
  Function(bool success, String message) callback,
) async {
  if (platformFile.path == null) {
    callback(false, '文件路径为空');
    return;
  }
  
  final file = File(platformFile.path!);
  if (!file.existsSync()) {
    callback(false, '文件不存在');
    return;
  }
  
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/file/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', platformFile.path!),
    );
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    callback(response.statusCode == 200, response.statusCode == 200 ? '上传成功' : '上传失败');
  } catch (e) {
    callback(false, '上传失败: $e');
  }
}

// 从拖拽的路径创建 File 并上传
Future<void> uploadFileFromDragPath(
  String path,
  String token,
  String baseUrl,
  Function(bool success, String message) callback,
) async {
  final file = File(path);
  if (!file.existsSync()) {
    callback(false, '文件不存在');
    return;
  }
  
  final separator = Platform.isWindows ? '\\' : '/';
  final fileName = path.split(separator).last;
  
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/file/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', path),
    );
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    callback(response.statusCode == 200, response.statusCode == 200 ? '上传成功: $fileName' : '上传失败');
  } catch (e) {
    callback(false, '上传失败: $e');
  }
}

// 检查文件是否存在
bool checkFileExists(String path) {
  final file = File(path);
  return file.existsSync();
}

