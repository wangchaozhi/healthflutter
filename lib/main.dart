import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'services/activity_store.dart';
import 'services/cache_service.dart';
import 'services/http_client.dart';
import 'services/single_instance_service.dart';
import 'services/theme_service.dart';
import 'services/token_storage.dart';
import 'services/tray_service.dart';
import 'utils/platform_utils.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    final singleInstance = SingleInstanceService();
    final isFirstInstance = await singleInstance.ensureSingleInstance();
    if (!isFirstInstance) {
      debugPrint('检测到已有实例运行，退出当前实例');
      exit(0);
    }
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }

  await CacheService().init();
  await ThemeService().init();

  if (isDesktop) {
    await TrayService().init();
  }

  HttpClient.onUnauthorized = _handleUnauthorized;

  runApp(const MyApp());
}

Future<void> _handleUnauthorized() async {
  await TokenStorage.clearToken();
  ActivityStore.instance.clear();
  appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
    AppRoutes.login,
    (_) => false,
  );
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      SingleInstanceService().dispose();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final themeService = ThemeService();
        return MaterialApp(
          title: '健康管理',
          theme: themeService.themeData,
          navigatorKey: appNavigatorKey,
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
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
