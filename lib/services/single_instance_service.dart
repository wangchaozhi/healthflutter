import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// 单实例服务 - 确保桌面应用只能运行一个实例
class SingleInstanceService {
  static final SingleInstanceService _instance = SingleInstanceService._internal();
  factory SingleInstanceService() => _instance;
  SingleInstanceService._internal();

  File? _lockFile;
  ServerSocket? _serverSocket;
  bool _isFirstInstance = false;
  static const int _lockPort = 54321; // 用于IPC通信的端口

  /// 检查并锁定单实例
  /// 返回 true 表示是第一个实例，false 表示已有实例在运行
  Future<bool> ensureSingleInstance() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      // 非桌面平台，直接返回 true
      return true;
    }

    try {
      // 方法1: 尝试创建文件锁
      _isFirstInstance = await _tryFileLock();
      
      if (!_isFirstInstance) {
        // 已有实例运行，尝试通知它显示窗口
        await _notifyExistingInstance();
        return false;
      }

      // 方法2: 创建本地服务器监听IPC消息（作为备用）
      await _startIPCServer();

      return true;
    } catch (e) {
      debugPrint('单实例检查失败: $e');
      // 出错时允许继续运行（避免阻止应用启动）
      return true;
    }
  }

  /// 尝试创建文件锁
  Future<bool> _tryFileLock() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final lockFilePath = '${tempDir.path}/healthflutter_instance.lock';
      _lockFile = File(lockFilePath);

      // 检查文件是否存在
      if (await _lockFile!.exists()) {
        // 文件存在，尝试通过端口检查是否有实例在运行
        // 如果端口被占用，说明已有实例运行
        try {
          final testSocket = await Socket.connect('127.0.0.1', _lockPort, timeout: const Duration(milliseconds: 100));
          await testSocket.close();
          // 连接成功，说明已有实例在监听
          debugPrint('检测到已有实例运行（端口 $_lockPort 已被占用）');
          return false;
        } catch (e) {
          // 连接失败，可能是旧锁文件，删除它
          try {
            await _lockFile!.delete();
            debugPrint('删除旧锁文件');
          } catch (_) {}
        }
      }

      // 创建新的锁文件（使用时间戳作为标识）
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _lockFile!.writeAsString(timestamp);
      debugPrint('创建单实例锁文件: $lockFilePath');
      
      return true;
    } catch (e) {
      debugPrint('创建文件锁失败: $e');
      return false;
    }
  }

  /// 通知已存在的实例显示窗口
  Future<void> _notifyExistingInstance() async {
    try {
      // 尝试通过TCP连接通知已存在的实例
      final socket = await Socket.connect('127.0.0.1', _lockPort, timeout: const Duration(seconds: 1));
      socket.write('show_window\n');
      await socket.flush();
      socket.destroy();
      debugPrint('已通知已存在的实例显示窗口');
    } catch (e) {
      debugPrint('通知已存在实例失败: $e');
      // 如果通知失败，尝试使用 window_manager 的 bringToFront
      try {
        // 这里我们无法直接操作另一个实例的窗口
        // 但可以通过其他方式（如命名管道、共享内存等）
        // 目前先记录日志
        debugPrint('无法通过IPC通知，请手动激活已存在的窗口');
      } catch (_) {}
    }
  }

  /// 启动IPC服务器，监听来自新实例的显示窗口请求
  Future<void> _startIPCServer() async {
    try {
      _serverSocket = await ServerSocket.bind('127.0.0.1', _lockPort);
      debugPrint('IPC服务器已启动，监听端口: $_lockPort');

      _serverSocket!.listen((Socket socket) {
        socket.listen(
          (data) {
            final message = String.fromCharCodes(data).trim();
            if (message == 'show_window') {
              debugPrint('收到显示窗口请求');
              _showWindow();
            }
          },
          onDone: () => socket.destroy(),
          onError: (error) {
            debugPrint('IPC连接错误: $error');
            socket.destroy();
          },
        );
      });
    } catch (e) {
      debugPrint('启动IPC服务器失败: $e');
      // 端口可能已被占用（另一个实例），这是正常的
    }
  }

  /// 显示并激活窗口
  Future<void> _showWindow() async {
    try {
      if (await windowManager.isVisible()) {
        await windowManager.show();
        await windowManager.focus();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
      debugPrint('窗口已显示并激活');
    } catch (e) {
      debugPrint('显示窗口失败: $e');
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    try {
      // 删除锁文件
      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
        debugPrint('已删除单实例锁文件');
      }

      // 关闭IPC服务器
      await _serverSocket?.close();
      _serverSocket = null;
      debugPrint('IPC服务器已关闭');
    } catch (e) {
      debugPrint('清理单实例资源失败: $e');
    }
  }
}
