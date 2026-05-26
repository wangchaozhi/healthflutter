import '../models/api_result.dart';
import '../models/user.dart';
import 'http_client.dart';
import 'token_storage.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  Future<ApiResult<User>> register(String username, String password) async {
    try {
      final data = await HttpClient.post(
        '/register',
        body: {'username': username, 'password': password},
        auth: false,
      );
      if (data['success'] == true) {
        if (data['token'] != null) {
          await TokenStorage.saveToken(data['token'] as String);
        }
        return ApiResult.ok(
          User.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
          (data['message'] as String?) ?? '',
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '注册失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<User>> login(String username, String password) async {
    try {
      final data = await HttpClient.post(
        '/login',
        body: {'username': username, 'password': password},
        auth: false,
      );
      if (data['success'] == true) {
        if (data['token'] != null) {
          await TokenStorage.saveToken(data['token'] as String);
        }
        return ApiResult.ok(
          User.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
          (data['message'] as String?) ?? '',
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '登录失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<User>> getProfile() async {
    final token = await TokenStorage.getToken();
    if (token == null) return const ApiResult.fail('未登录');
    try {
      final data = await HttpClient.get('/profile');
      if (data['success'] == true) {
        return ApiResult.ok(
          User.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '获取用户信息失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    if (token == null) return false;
    final result = await getProfile();
    return result.isOk;
  }

  Future<void> logout() async {
    await TokenStorage.clearToken();
  }
}
