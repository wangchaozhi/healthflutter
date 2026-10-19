import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:healthflutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('未登录时显示登录页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('记住用户名'), findsOneWidget);
  });
}
