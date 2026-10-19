import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthflutter/services/http_client.dart';
import 'package:healthflutter/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TokenStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('迁移旧 token 并删除明文密码', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'legacy-token',
        'remembered_username': 'alice',
        'remembered_password': 'plain-password',
        'remember_password': true,
      });

      expect(await TokenStorage.getToken(), 'legacy-token');
      expect(await TokenStorage.getRememberedUsername(), 'alice');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('token'), isFalse);
      expect(prefs.containsKey('remembered_password'), isFalse);

      await TokenStorage.clearToken();
    });

    test('只记住用户名，不保存密码', () async {
      await TokenStorage.saveRememberedUsername('bob');
      expect(await TokenStorage.getRememberedUsername(), 'bob');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('remembered_password'), isFalse);
    });
  });

  group('HttpClient response decoding', () {
    test('非 JSON 错误保留状态码和服务端消息', () {
      expect(
        () => HttpClient.decodeResponseForTest(
          http.Response('service unavailable', 503),
          auth: false,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', 'service unavailable'),
        ),
      );
    });

    test('401 触发未授权回调', () {
      var called = false;
      HttpClient.onUnauthorized = () => called = true;

      expect(
        () => HttpClient.decodeResponseForTest(http.Response('{}', 401)),
        throwsA(isA<ApiException>()),
      );
      expect(called, isTrue);
      HttpClient.onUnauthorized = null;
    });

    test('成功响应必须是有效 JSON', () {
      expect(
        () => HttpClient.decodeResponseForTest(
          http.Response('<html>', 200),
          auth: false,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '服务器返回了无效数据'),
        ),
      );
    });
  });
}
