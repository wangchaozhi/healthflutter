import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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
      
      // 设置托盘图标
      await _setTrayIcon();
      
      // 创建菜单
      await _createMenu();
      
      // 设置托盘工具提示
      await _systemTray!.setToolTip('健康管理');
      
      // 监听托盘点击事件
      _systemTray!.onTrayIconMouseDown.listen((event) {
        if (event.button == MouseButton.left) {
          _showOrHideWindow();
        }
      });

      _isInitialized = true;
      debugPrint('✅ 系统托盘初始化成功');
    } catch (e) {
      debugPrint('❌ 系统托盘初始化失败: $e');
    }
  }

  /// 设置托盘图标
  Future<void> _setTrayIcon() async {
    if (_systemTray == null) return;

    try {
      // system_tray 插件会自动使用应用图标
      // 如果需要自定义图标，可以在 assets 中添加图标文件
      // Windows: .ico 格式
      // macOS/Linux: .png 格式
      
      // 尝试加载自定义图标
      String iconPath = '';
      
      if (Platform.isWindows) {
        iconPath = 'assets/icons/tray_icon.ico';
      } else {
        iconPath = 'assets/icons/tray_icon.png';
      }
      
      try {
        // 检查资源文件是否存在
        await rootBundle.load(iconPath);
        await _systemTray!.setImage(iconPath);
        debugPrint('✅ 使用自定义托盘图标: $iconPath');
      } catch (e) {
        // 如果资源文件不存在，使用应用默认图标
        // system_tray 插件会尝试使用应用图标
        debugPrint('⚠️ 自定义托盘图标不存在，使用应用默认图标');
        // 不设置图标，让插件使用默认行为
      }
    } catch (e) {
      debugPrint('❌ 设置托盘图标失败: $e');
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
