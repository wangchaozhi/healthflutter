import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/douyin_parser_screen.dart';
import 'screens/file_transfer_screen.dart';
import 'screens/music_player_screen.dart';
import 'screens/music_share_screen.dart';
import 'screens/shared_music_player_screen.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';

void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化缓存服务
  await CacheService().init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '健康管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/douyin': (context) => const DouyinParserScreen(),
        '/file_transfer': (context) => const FileTransferScreen(),
        '/music_player': (context) => const MusicPlayerScreen(),
        '/music_shares': (context) => const MusicShareScreen(),
      },
      onGenerateRoute: (settings) {
        // 处理动态路由，如 /share/:token
        if (settings.name != null && settings.name!.startsWith('/share/')) {
          final token = settings.name!.substring(7); // 去掉 '/share/' 前缀
          return MaterialPageRoute(
            builder: (context) => SharedMusicPlayerScreen(shareToken: token),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    if (token != null) {
      final result = await ApiService.getProfile();
      if (result['success'] == true) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        return;
      }
    }
    setState(() {
      _isAuthenticated = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
  }
}
