import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// 条件导入：仅在Web平台导入dart:html
// 在非Web平台，这些函数不会被调用（因为kIsWeb检查）
// 但为了编译通过，我们需要使用条件导入
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

/// Web平台直接下载文件（带进度回调）
Future<void> downloadFileWebDirectWithProgress(
  String url, 
  String token, 
  String fileName,
  Function(double progress) onProgress,
) async {
  if (!kIsWeb) {
    throw UnsupportedError('此方法仅在Web平台可用');
  }
  
  try {
    // 创建HttpRequest并监听进度
    final request = html.HttpRequest();
    request.open('GET', url);
    request.setRequestHeader('Authorization', 'Bearer $token');
    request.responseType = 'blob';
    
    // 标记是否接收到进度更新
    bool hasProgress = false;
    
    // 监听下载开始
    request.onLoadStart.listen((html.ProgressEvent event) {
      debugPrint('Web下载开始');
      onProgress(0.1); // 设置初始进度为10%，表明下载已开始
    });
    
    // 监听下载进度
    request.onProgress.listen((html.ProgressEvent event) {
      debugPrint('Web下载进度事件: lengthComputable=${event.lengthComputable}, loaded=${event.loaded}, total=${event.total}');
      if (event.lengthComputable && event.total != null && event.total! > 0) {
        hasProgress = true;
        final loaded = event.loaded ?? 0;
        final progress = loaded / event.total!;
        final clampedProgress = progress.clamp(0.1, 0.95); // 保留5%给后续处理
        debugPrint('Web下载进度: ${(clampedProgress * 100).toStringAsFixed(1)}%');
        onProgress(clampedProgress);
      } else if (!hasProgress) {
        // 如果服务器没有发送Content-Length，显示不确定的进度
        onProgress(0.5); // 显示50%表示下载中
      }
    });
    
    // 监听下载完成
    request.onLoad.listen((html.ProgressEvent event) {
      debugPrint('Web下载完成事件触发');
      if (!hasProgress) {
        // 如果没有收到进度更新，设置为95%
        debugPrint('未收到进度更新，设置为95%');
        onProgress(0.95);
      }
    });
    
    // 发送请求
    request.send();
    
    // 等待请求完成
    await request.onLoadEnd.first;
    
    if (request.status != 200) {
      throw Exception('下载失败: ${request.status} ${request.statusText}');
    }
    
    debugPrint('Web下载请求完成，状态: ${request.status}');
    
    // 获取Blob对象
    final blob = request.response as html.Blob;
    debugPrint('Web下载Blob大小: ${blob.size} bytes');
    
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
    
    // 确保进度达到100%
    onProgress(1.0);
    debugPrint('Web下载完成，进度100%');
  } catch (e) {
    debugPrint('Web下载异常: $e');
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

