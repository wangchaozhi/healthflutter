import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthflutter/screens/about_screen.dart';
import 'package:healthflutter/services/app_info_service.dart';
import 'package:healthflutter/widgets/version_badge.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'healthflutter',
      packageName: 'com.example.healthflutter',
      version: '0.3.17',
      buildNumber: '17',
      buildSignature: '',
    );
    AppInfoService.clearCache();
  });

  testWidgets('版本徽标显示动态版本号', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VersionBadge())),
    );
    await tester.pumpAndSettle();

    expect(find.text('v0.3.17'), findsOneWidget);
  });

  testWidgets('关于页面展示版本、构建号和项目入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('健康管理'), findsOneWidget);
    expect(find.text('v0.3.17'), findsOneWidget);
    expect(find.text('0.3.17'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('项目主页'), findsOneWidget);
    expect(find.text('版本发布'), findsOneWidget);
  });
}
