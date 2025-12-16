import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static const String baseUrl = ApiConfig.baseUrl;
  
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
}

