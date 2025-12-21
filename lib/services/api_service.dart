import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  
  // 获取token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  // 保存token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
  
  // 清除token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
  
  // 注册
  static Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 登录
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 获取用户信息
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 登出
  static Future<void> logout() async {
    await clearToken();
    // 不清除记住的密码，保持用户选择
  }
  
  // 保存记住的用户名和密码
  static Future<void> saveRememberedCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remembered_username', username);
    await prefs.setString('remembered_password', password);
    await prefs.setBool('remember_password', true);
  }
  
  // 获取记住的用户名和密码
  static Future<Map<String, String?>> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRemember = prefs.getBool('remember_password') ?? false;
    if (shouldRemember) {
      return {
        'username': prefs.getString('remembered_username'),
        'password': prefs.getString('remembered_password'),
      };
    }
    return {'username': null, 'password': null};
  }
  
  // 清除记住的用户名和密码
  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remembered_username');
    await prefs.remove('remembered_password');
    await prefs.setBool('remember_password', false);
  }
  
  // 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) {
      return false;
    }
    // 验证token是否有效
    final result = await getProfile();
    return result['success'] == true;
  }
  
  // 创建健康活动记录
  static Future<Map<String, dynamic>> createActivity({
    required String recordDate,
    required String recordTime,
    required int duration,
    String remark = '',
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'record_date': recordDate,
          'record_time': recordTime,
          'duration': duration,
          'remark': remark,
        }),
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 获取健康活动记录列表
  static Future<Map<String, dynamic>> getActivities() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 删除健康活动记录
  static Future<Map<String, dynamic>> deleteActivity(int id) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 获取健康活动统计
  static Future<Map<String, dynamic>> getActivityStats() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/activities/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 抖音解析
  static Future<Map<String, dynamic>> douyinParsing(String text) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/douyin/parsing'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text}),
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 获取抖音文件列表
  static Future<Map<String, dynamic>> getDouyinFileList() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '未登录'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/douyin/files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }
  
  // 获取下载URL（用于直接下载）
  static Future<String> getDownloadUrl(int id) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    // 返回带token的下载URL
    return '$baseUrl/douyin/download?id=$id';
  }
}

