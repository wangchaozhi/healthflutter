import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// 条件导入：仅在Web平台导入dart:html
// 在非Web平台，这个导入会被忽略（因为dart:html不存在）
// 注意：Flutter Web会自动处理条件导入
import 'dart:html' as html if (dart.library.html) 'dart:html';

/// Web平台直接下载文件（使用HttpRequest，不加载到内存）
Future<void> downloadFileWebDirect(String url, String token, String fileName) async {
  if (!kIsWeb) {
    throw UnsupportedError('此方法仅在Web平台可用');
  }
  
  try {
    // 使用HttpRequest下载文件，避免将整个文件加载到内存
    final request = await html.HttpRequest.request(
      url,
      method: 'GET',
      requestHeaders: {
        'Authorization': 'Bearer $token',
      },
      responseType: 'blob',
    );
    
    if (request.status != 200) {
      throw Exception('下载失败: ${request.status} ${request.statusText}');
    }
    
    // 获取Blob对象（不加载到内存）
    final blob = request.response as html.Blob;
    
    // 创建对象URL
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    
    // 创建隐藏的a标签并触发下载
    final anchor = html.AnchorElement(href: objectUrl)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    // 添加到DOM并触发点击
    html.document.body?.append(anchor);
    anchor.click();
    
    // 延迟清理，确保下载开始
    Future.delayed(const Duration(seconds: 1), () {
      anchor.remove();
      html.Url.revokeObjectUrl(objectUrl);
    });
  } catch (e) {
    throw Exception('下载文件失败: $e');
  }
}

/// Web平台下载文件（从内存中的字节）
void downloadFileWeb(Uint8List bytes, String fileName) {
  if (!kIsWeb) {
    throw UnsupportedError('此方法仅在Web平台可用');
  }
  
  try {
    // 创建Blob对象
    final blob = html.Blob([bytes]);
    // 创建对象URL
    final url = html.Url.createObjectUrlFromBlob(blob);
    // 创建隐藏的a标签
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    // 添加到DOM并触发点击
    html.document.body?.append(anchor);
    anchor.click();
    // 清理
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    throw Exception('下载文件失败: $e');
  }
}

