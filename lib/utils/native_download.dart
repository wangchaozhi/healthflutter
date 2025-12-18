import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';

/// 请求Android存储权限
/// 注意：Android 10+ 对公共存储目录的写入有严格限制
/// 即使有权限，直接写入 /storage/emulated/0/Download 也可能失败
/// 建议使用应用专属目录，或者使用MediaStore API
Future<bool> requestStoragePermission() async {
  if (!Platform.isAndroid) {
    return true; // 非Android平台不需要权限
  }

  try {
    // 先检查是否已有权限
    bool hasPermission = false;
    
    // Android 10-12 (API 29-32) 需要存储权限才能写入公共目录
    // WRITE_EXTERNAL_STORAGE 是写入权限
    if (await Permission.storage.isGranted) {
      hasPermission = true;
    }
    
    // Android 13+ (API 33+) 的媒体权限主要用于读取
    // 写入公共下载目录仍然需要 WRITE_EXTERNAL_STORAGE 或使用 MediaStore API
    // 但某些设备可能允许，所以我们也可以检查
    if (await Permission.videos.isGranted ||
        await Permission.photos.isGranted ||
        await Permission.audio.isGranted) {
      // 注意：这些权限主要用于读取，写入可能仍然需要 storage 权限
      // 但某些情况下可能允许写入
      hasPermission = true;
    }
    
    if (hasPermission) {
      return true;
    }

    // 请求权限
    List<Permission> permissionsToRequest = [];
    
    // 优先请求存储权限（这是写入公共目录的主要权限）
    permissionsToRequest.add(Permission.storage);
    
    // Android 13+ 也请求媒体权限（虽然主要用于读取，但某些设备可能允许写入）
    permissionsToRequest.add(Permission.videos);
    permissionsToRequest.add(Permission.photos);
    permissionsToRequest.add(Permission.audio);
    
    Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();

    // 检查是否有任一权限被授予
    bool granted = statuses[Permission.storage]?.isGranted == true ||
        statuses[Permission.videos]?.isGranted == true ||
        statuses[Permission.photos]?.isGranted == true ||
        statuses[Permission.audio]?.isGranted == true;
    
    if (granted) {
      return true;
    }

    // 检查是否有权限被永久拒绝
    bool permanentlyDenied = statuses[Permission.storage]?.isPermanentlyDenied == true ||
        statuses[Permission.videos]?.isPermanentlyDenied == true ||
        statuses[Permission.photos]?.isPermanentlyDenied == true ||
        statuses[Permission.audio]?.isPermanentlyDenied == true;
    
    if (permanentlyDenied) {
      debugPrint('存储权限被永久拒绝，用户需要在设置中手动授予');
      // 可以在这里提示用户去设置中开启权限
      // await openAppSettings();
    }

    return false;
  } catch (e) {
    debugPrint('请求存储权限失败: $e');
    return false;
  }
}

/// 移动端和桌面端下载文件（带进度回调）
/// 返回下载文件的完整路径
Future<String> downloadFileNativeWithProgress(
  String url,
  String token,
  String fileName,
  Function(double progress) onProgress,
) async {
  if (kIsWeb) {
    throw UnsupportedError('此方法仅在移动和桌面平台可用');
  }

  try {
    // 获取下载目录
    Directory? downloadDir;
    
    if (Platform.isAndroid) {
      // Android: 由于作用域存储（Scoped Storage）的限制
      // Android 11+ 不允许直接写入 /storage/emulated/0/Download
      // 即使有权限也可能失败
      // 推荐使用应用专属目录，不需要额外权限且更可靠
      
      // 使用应用专属外部存储目录
      // 路径类似：/storage/emulated/0/Android/data/cn.wangchaozhi.healthflutter/files/Download
      // 这个目录不需要存储权限，用户可以通过"打开目录"按钮访问
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        downloadDir = Directory('${externalDir.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        debugPrint('使用应用专属下载目录: ${downloadDir.path}');
      } else {
        // 如果无法获取外部存储目录，使用应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${appDir.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        debugPrint('使用应用文档下载目录: ${downloadDir.path}');
      }
      
      // 注意：如果需要写入公共下载目录 /storage/emulated/0/Download
      // 需要使用 MediaStore API 或 MANAGE_EXTERNAL_STORAGE 权限
      // 但这些方法比较复杂或需要用户手动在设置中授予权限
      // 使用应用专属目录是最简单可靠的方法
    } else if (Platform.isIOS) {
      // iOS: 使用应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      downloadDir = Directory('${appDir.path}/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
    } else if (Platform.isWindows) {
      // Windows: 使用用户下载目录
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null) {
        downloadDir = Directory('$userProfile\\Downloads');
        if (!await downloadDir.exists()) {
          // 如果Downloads目录不存在，使用应用文档目录
          final appDir = await getApplicationDocumentsDirectory();
          downloadDir = Directory('${appDir.path}\\Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${appDir.path}\\Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      // Linux/macOS: 使用用户下载目录
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        downloadDir = Directory('$homeDir/Downloads');
        if (!await downloadDir.exists()) {
          // 如果Downloads目录不存在，使用应用文档目录
          final appDir = await getApplicationDocumentsDirectory();
          downloadDir = Directory('${appDir.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${appDir.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
      }
    } else {
      throw UnsupportedError('不支持的操作系统');
    }

    if (downloadDir == null) {
      throw Exception('无法获取下载目录');
    }

    // 构建文件路径
    final separator = Platform.isWindows ? '\\' : '/';
    final filePath = '${downloadDir.path}$separator$fileName';
    final file = File(filePath);

    // 使用流式下载以支持进度回调
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    
    final streamedResponse = await request.send();
    
    if (streamedResponse.statusCode != 200) {
      throw Exception('下载失败: ${streamedResponse.statusCode}');
    }

    // 从实际的响应头中获取文件大小
    final totalBytes = streamedResponse.contentLength ?? 0;
    debugPrint('文件总大小: $totalBytes bytes');

    // 保存文件并监听进度
    final sink = file.openWrite();
    int downloadedBytes = 0;
    
    await for (var chunk in streamedResponse.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      
      // 更新进度
      if (totalBytes > 0) {
        final progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
        onProgress(progress);
      } else {
        // 如果不知道总大小，显示不确定的进度（使用下载的字节数作为参考）
        // 这种情况下不显示具体百分比，只显示loading动画
        onProgress(0.0);
      }
    }
    
    await sink.close();
    
    debugPrint('下载完成，总共下载: $downloadedBytes bytes');
    
    // 确保进度达到100%
    onProgress(1.0);

    debugPrint('文件下载成功: $filePath');
    
    // 如果是Android平台且是视频文件，尝试保存到相册
    if (Platform.isAndroid && _isVideoFile(fileName)) {
      try {
        await saveVideoToGallery(filePath);
        // 保存到相册成功后，删除原文件以节省空间
        // 因为视频已经在相册中，用户可以通过相册访问
        try {
          await file.delete();
          debugPrint('原视频文件已删除: $filePath');
        } catch (e) {
          debugPrint('删除原文件失败（不影响功能）: $e');
        }
      } catch (e) {
        debugPrint('保存到相册失败: $e');
        // 保存到相册失败时，保留原文件，继续返回文件路径
      }
    }
    
    return filePath;
  } catch (e) {
    throw Exception('下载文件失败: $e');
  }
}

/// 移动端和桌面端下载文件（不带进度回调，向后兼容）
/// 返回下载文件的完整路径
Future<String> downloadFileNative(String url, String token, String fileName) async {
  return downloadFileNativeWithProgress(url, token, fileName, (_) {});
}

/// 判断是否为视频文件
bool _isVideoFile(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;
  final videoExts = ['mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'm4v'];
  return videoExts.contains(ext);
}

/// 保存视频到系统相册
Future<void> saveVideoToGallery(String filePath) async {
  if (kIsWeb) {
    return; // Web平台不支持
  }
  
  try {
    // 检查是否有相册访问权限
    bool hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      // 请求相册访问权限
      await Gal.requestAccess();
      // 再次检查
      hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        debugPrint('用户拒绝了相册访问权限');
        return;
      }
    }

    // 保存视频到相册
    await Gal.putVideo(filePath);
    debugPrint('✅ 视频已成功保存到系统相册: $filePath');
  } on GalException catch (e) {
    debugPrint('❌ 保存到相册失败: ${e.type}');
    rethrow;
  } catch (e) {
    debugPrint('保存到相册时发生错误: $e');
    rethrow;
  }
}

/// 打开文件管理器并定位到指定目录
Future<void> openDownloadDirectory(String filePath) async {
  try {
    final file = File(filePath);
    final directory = file.parent;
    
    if (Platform.isAndroid) {
      // Android: 使用平台通道调用原生代码打开文件管理器
      try {
        const platform = MethodChannel('cn.wangchaozhi.healthflutter/file_manager');
        await platform.invokeMethod('openDirectory', {'path': directory.path});
        return;
      } catch (e) {
        debugPrint('使用平台通道打开文件管理器失败: $e');
        // 如果平台通道失败，尝试使用content://协议打开公共下载目录
        try {
          // 优先尝试打开公共下载目录
          final publicDownloadUri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
          if (await canLaunchUrl(publicDownloadUri)) {
            await launchUrl(publicDownloadUri, mode: LaunchMode.externalApplication);
            return;
          }
          
          // 如果公共下载目录打开失败，尝试打开当前目录
          String relativePath = directory.path;
          if (relativePath.startsWith('/storage/emulated/0/')) {
            relativePath = relativePath.substring('/storage/emulated/0/'.length);
            final contentUri = Uri.parse('content://com.android.externalstorage.documents/document/primary:$relativePath');
            if (await canLaunchUrl(contentUri)) {
              await launchUrl(contentUri, mode: LaunchMode.externalApplication);
              return;
            }
          }
        } catch (e2) {
          debugPrint('使用content://协议打开失败: $e2');
        }
      }
    } else if (Platform.isWindows) {
      // Windows: 使用explorer打开目录
      await Process.run('explorer', [directory.path]);
    } else if (Platform.isLinux) {
      // Linux: 使用xdg-open打开目录
      await Process.run('xdg-open', [directory.path]);
    } else if (Platform.isMacOS) {
      // macOS: 使用open打开目录
      await Process.run('open', [directory.path]);
    } else if (Platform.isIOS) {
      // iOS: 无法直接打开文件管理器，但可以分享文件
      // 这里暂时不实现，因为iOS限制较多
      debugPrint('iOS不支持直接打开文件管理器');
    }
  } catch (e) {
    debugPrint('打开下载目录失败: $e');
  }
}

