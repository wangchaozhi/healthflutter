import '../models/activity.dart';
import '../models/activity_stats.dart';
import '../models/api_result.dart';
import 'http_client.dart';
import 'token_storage.dart';

class ActivityRepository {
  ActivityRepository._();
  static final ActivityRepository instance = ActivityRepository._();

  Future<ApiResult<Activity>> create({
    required String recordDate,
    required String recordTime,
    required int duration,
    String remark = '',
    ActivityTag tag = ActivityTag.manual,
  }) async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.post(
        '/activities',
        body: {
          'record_date': recordDate,
          'record_time': recordTime,
          'duration': duration,
          'remark': remark,
          'tag': tag.wire,
        },
      );
      if (data['success'] == true) {
        return ApiResult.ok(
          Activity.fromJson(data['data'] as Map<String, dynamic>? ?? {}),
          (data['message'] as String?) ?? '',
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '记录失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<List<Activity>>> list() async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.get('/activities');
      if (data['success'] == true) {
        final rawList = (data['list'] as List?) ?? const [];
        final activities = rawList
            .whereType<Map<String, dynamic>>()
            .map(Activity.fromJson)
            .toList();
        return ApiResult.ok(activities);
      }
      return ApiResult.fail((data['message'] as String?) ?? '获取列表失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<void>> delete(int id) async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.delete('/activities/$id');
      if (data['success'] == true) {
        return ApiResult.ok(null, (data['message'] as String?) ?? '');
      }
      return ApiResult.fail((data['message'] as String?) ?? '删除失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }

  Future<ApiResult<ActivityStats>> stats() async {
    if (await TokenStorage.getToken() == null) {
      return const ApiResult.fail('未登录');
    }
    try {
      final data = await HttpClient.get('/activities/stats');
      if (data['success'] == true) {
        return ApiResult.ok(
          ActivityStats.fromJson(data['stats'] as Map<String, dynamic>? ?? {}),
        );
      }
      return ApiResult.fail((data['message'] as String?) ?? '获取统计失败');
    } on ApiException catch (e) {
      return ApiResult.fail(e.message);
    }
  }
}
