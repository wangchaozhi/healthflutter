import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayService extends WindowListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  SystemTray? _systemTray;
  bool _isInitialized = false;
  bool _isWindowVisible = true;

  /// 初始化托盘
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 初始化窗口管理器
      await windowManager.ensureInitialized();

      // 设置窗口选项 - 关闭窗口时不退出应用
      WindowOptions windowOptions = const WindowOptions(
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // 设置阻止窗口关闭，由我们自定义处理
      await windowManager.setPreventClose(true);
      
      // 添加窗口监听器
      windowManager.addListener(this);

      // 初始化系统托盘
      _systemTray = SystemTray();
      
      // 尝试初始化托盘，如果图标不存在则使用空字符串
      String? iconPath = await _getIconPath();
      bool trayInitialized = false;
      
      if (iconPath != null && iconPath.isNotEmpty) {
        try {
          await _systemTray!.initSystemTray(
            title: "健康管理",
            iconPath: iconPath,
          );
          trayInitialized = true;
        } catch (e) {
          debugPrint('使用自定义图标失败: $e');
        }
      }
      
      // 如果使用自定义图标失败，尝试使用应用图标
      if (!trayInitialized) {
        try {
          // 尝试使用应用的可执行文件路径（Windows）或应用包路径（macOS/Linux）
          String? appIconPath = _getAppIconPath();
          if (appIconPath != null) {
            await _systemTray!.initSystemTray(
              title: "健康管理",
              iconPath: appIconPath,
            );
            trayInitialized = true;
          } else {
            // 如果无法获取应用图标，尝试空字符串
            await _systemTray!.initSystemTray(
              title: "健康管理",
              iconPath: "",
            );
            trayInitialized = true;
          }
        } catch (e) {
          debugPrint('初始化托盘完全失败，将跳过托盘功能: $e');
          // 如果完全失败，返回但不影响应用运行
          return;
        }
      }

      // 创建托盘菜单
      try {
        final Menu menu = Menu();
        await menu.buildFrom([
          MenuItemLabel(
            label: '显示/隐藏',
            onClicked: (menuItem) => _toggleWindow(),
          ),
          MenuSeparator(),
          MenuItemLabel(
            label: '退出',
            onClicked: (menuItem) => _exitApp(),
          ),
        ]);

        // 设置托盘菜单
        await _systemTray!.setContextMenu(menu);

        // 监听托盘图标点击事件
        _systemTray!.registerSystemTrayEventHandler((eventName) {
          if (eventName == kSystemTrayEventClick) {
            // 左键点击：切换窗口显示/隐藏
            _toggleWindow();
          } else if (eventName == kSystemTrayEventRightClick) {
            // 右键点击：显示上下文菜单
            // Windows 需要手动调用 popUpContextMenu
            if (Platform.isWindows) {
              _systemTray!.popUpContextMenu();
            }
            // Linux 和 macOS 通常会自动显示菜单
          }
        });
      } catch (e) {
        debugPrint('设置托盘菜单失败: $e');
        // 即使菜单设置失败，也标记为已初始化（至少窗口管理功能可用）
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
    }
  }

  /// 获取托盘图标路径
  /// 尝试从 assets 加载图标并复制到临时目录
  Future<String?> _getIconPath() async {
    try {
      // 确定图标文件名
      String iconFileName;
      String assetPath;
      
      if (Platform.isWindows) {
        iconFileName = 'tray_icon.ico';
        assetPath = 'assets/icons/tray_icon.ico';
      } else {
        iconFileName = 'tray_icon.png';
        assetPath = 'assets/icons/tray_icon.png';
      }
      
      // 尝试从 assets 加载图标
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final Directory tempDir = await getTemporaryDirectory();
        final String iconPath = '${tempDir.path}/$iconFileName';
        final File iconFile = File(iconPath);
        await iconFile.writeAsBytes(data.buffer.asUint8List());
        return iconFile.path;
      } catch (e) {
        // 如果 assets 中没有图标，返回 null 使用默认图标
        debugPrint('从 assets 加载图标失败: $e');
        return null;
      }
    } catch (e) {
      debugPrint('获取图标路径失败: $e');
      return null;
    }
  }

  /// 切换窗口显示/隐藏
  Future<void> _toggleWindow() async {
    try {
      if (_isWindowVisible) {
        await windowManager.hide();
        _isWindowVisible = false;
      } else {
        await windowManager.show();
        await windowManager.focus();
        _isWindowVisible = true;
      }
    } catch (e) {
      debugPrint('切换窗口失败: $e');
    }
  }

  /// 退出应用
  Future<void> _exitApp() async {
    try {
      if (_systemTray != null) {
        await _systemTray!.destroy();
      }
      exit(0);
    } catch (e) {
      debugPrint('退出应用失败: $e');
      exit(0);
    }
  }

  /// 窗口关闭事件处理
  @override
  void onWindowClose() {
    // 隐藏窗口而不是退出应用
    windowManager.hide().then((_) {
      _isWindowVisible = false;
    });
  }

  /// 获取应用图标路径
  String? _getAppIconPath() {
    try {
      if (Platform.isWindows) {
        // Windows: 使用可执行文件路径
        final String exePath = Platform.resolvedExecutable;
        return exePath;
      } else if (Platform.isMacOS) {
        // macOS: 使用应用包路径
        final String bundlePath = Platform.resolvedExecutable;
        // macOS 应用通常在 .app/Contents/MacOS/ 目录下
        return bundlePath;
      } else if (Platform.isLinux) {
        // Linux: 尝试使用应用图标
        // 通常位于 /usr/share/pixmaps/ 或应用目录
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('获取应用图标路径失败: $e');
      return null;
    }
  }

  /// 销毁托盘
  Future<void> destroy() async {
    if (!_isInitialized || _systemTray == null) return;
    try {
      // 移除窗口监听器
      windowManager.removeListener(this);
      await _systemTray!.destroy();
      _isInitialized = false;
    } catch (e) {
      debugPrint('销毁托盘失败: $e');
    }
  }
}
