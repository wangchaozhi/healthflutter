import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 系统托盘服务
class TrayService {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  SystemTray? _systemTray;
  Menu? _menu;
  bool _isInitialized = false;
  VoidCallback? _onShowWindow;
  VoidCallback? _onQuit;

  /// 初始化托盘
  Future<void> init({
    VoidCallback? onShowWindow,
    VoidCallback? onQuit,
  }) async {
    if (_isInitialized) return;
    
    // 只在桌面平台初始化
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    _onShowWindow = onShowWindow;
    _onQuit = onQuit;

    try {
      _systemTray = SystemTray();
      
      // 获取图标路径
      final iconPath = await _getTrayIconPath();
      
      // 初始化系统托盘（必须提供图标路径）
      await _systemTray!.initSystemTray(
        title: '健康管理',
        iconPath: iconPath,
      );
      
      // 创建菜单
      await _createMenu();
      
      // 监听托盘点击事件
      _systemTray!.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          // 左键点击：显示/隐藏窗口
          _showOrHideWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          // 右键点击：显示上下文菜单（由 setContextMenu 自动处理）
          // 这里不需要额外处理
        }
      });

      _isInitialized = true;
      debugPrint('✅ 系统托盘初始化成功');
    } catch (e) {
      debugPrint('❌ 系统托盘初始化失败: $e');
    }
  }

  /// 获取托盘图标路径
  Future<String> _getTrayIconPath() async {
    // 首先尝试加载自定义图标
    String assetIconPath = '';
    
    if (Platform.isWindows) {
      assetIconPath = 'assets/icons/tray_icon.ico';
    } else {
      assetIconPath = 'assets/icons/tray_icon.png';
    }
    
    try {
      // 检查资源文件是否存在
      await rootBundle.load(assetIconPath);
      debugPrint('✅ 找到自定义托盘图标: $assetIconPath');
      return assetIconPath;
    } catch (e) {
      // 如果资源文件不存在，使用应用可执行文件路径（Windows）或应用包路径
      debugPrint('⚠️ 自定义托盘图标不存在，尝试使用应用图标');
      
      if (Platform.isWindows) {
        // Windows: 使用可执行文件路径（包含图标资源）
        final executablePath = Platform.resolvedExecutable;
        debugPrint('📁 Windows 可执行文件路径: $executablePath');
        return executablePath; // Windows 会从 exe 文件中提取图标
      } else if (Platform.isMacOS) {
        // macOS: 使用应用包中的图标
        try {
          final appDir = await getApplicationSupportDirectory();
          // macOS 应用通常在 Contents/Resources 目录中
          // 这里返回应用包路径，让插件自动查找
          final bundlePath = appDir.path.replaceAll('/Library/Application Support', '');
          debugPrint('📁 macOS 应用路径: $bundlePath');
          // 返回应用包路径，system_tray 会自动查找图标
          return bundlePath;
        } catch (e) {
          debugPrint('❌ 获取 macOS 应用路径失败: $e');
          // 如果失败，返回可执行文件路径
          return Platform.resolvedExecutable;
        }
      } else {
        // Linux: 使用可执行文件路径或应用图标
        final executablePath = Platform.resolvedExecutable;
        debugPrint('📁 Linux 可执行文件路径: $executablePath');
        return executablePath;
      }
    }
  }

  /// 创建托盘菜单
  Future<void> _createMenu() async {
    if (_systemTray == null) return;

    try {
      _menu = Menu();
      
      // 显示窗口
      await _menu!.buildFrom([
        MenuItemLabel(
          label: '显示窗口',
          onClicked: (menuItem) {
            _showOrHideWindow();
          },
        ),
        MenuItemLabel(
          label: '---', // 分隔线
        ),
        MenuItemLabel(
          label: '退出',
          onClicked: (menuItem) {
            _quit();
          },
        ),
      ]);

      await _systemTray!.setContextMenu(_menu!);
    } catch (e) {
      debugPrint('❌ 创建托盘菜单失败: $e');
    }
  }

  /// 显示或隐藏窗口
  Future<void> _showOrHideWindow() async {
    try {
      if (await windowManager.isVisible()) {
        // 如果窗口可见，则隐藏
        await windowManager.hide();
      } else {
        // 如果窗口隐藏，则显示并聚焦
        await windowManager.show();
        await windowManager.focus();
      }
      
      _onShowWindow?.call();
    } catch (e) {
      debugPrint('❌ 显示/隐藏窗口失败: $e');
    }
  }

  /// 退出应用
  void _quit() {
    _onQuit?.call();
    exit(0);
  }

  /// 销毁托盘
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      // system_tray 插件会自动清理资源
      _isInitialized = false;
      debugPrint('✅ 系统托盘已销毁');
    } catch (e) {
      debugPrint('❌ 销毁系统托盘失败: $e');
    }
  }
}
