import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic>? data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      try {
        final decoded = jsonDecode(response.body);
        // 如果返回的是List，直接返回List；否则返回Map
        return decoded;
      } catch (e) {
        // 如果解析失败，返回原始响应体
        return {'message': response.body};
      }
    } else {
      // 处理错误响应
      String errorMessage = '请求失败 (${response.statusCode})';
      try {
        if (response.body.isNotEmpty) {
          final error = jsonDecode(response.body);
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (e) {
        // 如果响应体不是JSON，使用状态码对应的默认消息
        if (response.statusCode == 401) {
          errorMessage = '用户名或密码错误';
        } else if (response.statusCode == 403) {
          errorMessage = '没有权限访问';
        } else if (response.statusCode == 404) {
          errorMessage = '资源不存在';
        } else if (response.statusCode >= 500) {
          errorMessage = '服务器错误，请稍后重试';
        }
      }
      throw Exception(errorMessage);
    }
  }
  
  Future<List<dynamic>> getList(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return [];
        }
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        }
        return [];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '请求失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }
}

