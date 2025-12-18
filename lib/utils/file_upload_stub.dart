// File upload utilities stub for Web platform
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

// Web平台不支持从路径上传
Future<http.MultipartFile> createMultipartFileFromPath(String path) async {
  throw UnsupportedError('File path upload is not supported on Web platform');
}

// Web平台不支持 PlatformFile.path
Future<void> uploadFileFromPlatformFile(
  PlatformFile platformFile,
  String token,
  String baseUrl,
  Function(bool success, String message) callback,
) async {
  callback(false, 'Web平台不支持此上传方式');
}

// Web平台不支持拖拽上传
Future<void> uploadFileFromDragPath(
  String path,
  String token,
  String baseUrl,
  Function(bool success, String message) callback,
) async {
  callback(false, 'Web平台不支持拖拽上传');
}

// Web平台无法检查文件是否存在
bool checkFileExists(String path) {
  return false;
}

