import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class HttpClient {
  static String get _baseUrl => ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 20);

  /// Called when an authenticated request returns 401.
  /// Wire this in app startup to clear stores and redirect to login.
  static void Function()? onUnauthorized;

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await TokenStorage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _decode(
    http.Response response, {
    required bool auth,
  }) {
    final body = utf8.decode(response.bodyBytes);
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
    }

    if (auth && response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('登录已过期，请重新登录', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = decoded is Map
          ? decoded['message']?.toString()
          : body.trim().isNotEmpty
          ? body.trim()
          : null;
      throw ApiException(
        serverMessage ?? response.reasonPhrase ?? '请求失败',
        statusCode: response.statusCode,
      );
    }
    if (body.isEmpty) return {};
    if (decoded == null) {
      throw ApiException('服务器返回了无效数据', statusCode: response.statusCode);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  @visibleForTesting
  static Map<String, dynamic> decodeResponseForTest(
    http.Response response, {
    bool auth = true,
  }) => _decode(response, auth: auth);

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: await _headers(auth: auth))
          .timeout(_timeout);
      return _decode(response, auth: auth);
    } on TimeoutException {
      throw ApiException('请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络错误: $e');
    }
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(response, auth: auth);
    } on TimeoutException {
      throw ApiException('请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络错误: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(_timeout);
      return _decode(response, auth: auth);
    } on TimeoutException {
      throw ApiException('请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络错误: $e');
    }
  }
}
