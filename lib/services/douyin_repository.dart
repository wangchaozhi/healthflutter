import '../config/api_config.dart';
import '../models/api_result.dart';
import '../models/douyin_file.dart';
import 'http_client.dart';
import 'token_storage.dart';

class DouyinRepository {
  DouyinRepository._();
  static final DouyinRepository instance = DouyinRepository._();

  Future<ApiResult<String>> parse(String text) async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.post(
        '/douyin/parsing',
        body: {'text': text},
      );
      if (data['success'] == true) {
        return ApiResult.ok(
          (data['data'] as String?) ?? '',
          (data['message'] as String?) ?? '',
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '解析失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<List<DouyinFile>>> list() async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.get('/douyin/files');
      if (data['success'] == true) {
        final rawList = (data['list'] as List?) ?? const [];
        final files = rawList
            .whereType<Map<String, dynamic>>()
            .map(DouyinFile.fromJson)
            .toList();
        return ApiResult.ok(files);
      }
      return ApiResult.fail((data['message'] as String?) ?? '获取列表失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<String> downloadUrl(int id) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw ApiException('未登录');
    return '${ApiConfig.baseUrl}/douyin/download?id=$id';
  }
}
