import 'package:flutter/material.dart';
import '../screens/ariang_screen.dart';
import '../screens/auth_wrapper.dart';
import '../screens/douyin_parser_screen.dart';
import '../screens/file_transfer_screen.dart';
import '../screens/filebrowser_screen.dart';
import '../screens/frps_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/music_player_screen.dart';
import '../screens/music_share_screen.dart';
import '../screens/register_screen.dart';
import '../screens/shared_music_player_screen.dart';
import '../screens/tools_menu_screen.dart';
import '../screens/webview_menu_screen.dart';
import '../screens/xui_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final Map<String, WidgetBuilder> _builders = {
    AppRoutes.root: (_) => const AuthWrapper(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.douyin: (_) => const DouyinParserScreen(),
    AppRoutes.fileTransfer: (_) => const FileTransferScreen(),
    AppRoutes.musicPlayer: (_) => const MusicPlayerScreen(),
    AppRoutes.musicShares: (_) => const MusicShareScreen(),
    AppRoutes.webviewMenu: (_) => const WebViewMenuScreen(),
    AppRoutes.toolsMenu: (_) => const ToolsMenuScreen(),
    AppRoutes.ariang: (_) => const AriaNgScreen(),
    AppRoutes.filebrowser: (_) => const FileBrowserScreen(),
    AppRoutes.xui: (_) => const XuiScreen(),
    AppRoutes.frps: (_) => const FrpsScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;

    if (name.startsWith(AppRoutes.sharePrefix)) {
      final token = name.substring(AppRoutes.sharePrefix.length);
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => SharedMusicPlayerScreen(shareToken: token),
      );
    }

    final builder = _builders[name];
    if (builder == null) return null;
    return MaterialPageRoute(settings: settings, builder: builder);
  }
}
