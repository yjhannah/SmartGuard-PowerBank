import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/storage/storage_service.dart';

/// 图片上传服务 - 用于患者端上传监护现场图片
class ImageUploadService {
  final StorageService _storageService = StorageService();
  
  /// 输出日志（使用debugPrint确保在Release模式下不会输出）
  void _log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [$level] [ImageUploadService] $message');
  }
  
  /// 生成分隔线
  String _separator() => List.filled(60, '=').join('');

  /// 上传图片并进行分析
  /// 
  /// [imageBytes] 图片字节数据
  /// [patientId] 患者ID
  /// [cameraId] 摄像头ID（可选）
  /// [timestampMs] 时间戳（毫秒，可选）
  /// 
  /// 返回分析结果
  Future<Map<String, dynamic>> uploadAndAnalyze({
    required Uint8List imageBytes,
    required String patientId,
    String? cameraId,
    int? timestampMs,
  }) async {
    final startTime = DateTime.now();
    final imageSizeKB = (imageBytes.length / 1024).toStringAsFixed(2);
    
    _log(_separator());
    _log('开始上传图片并进行分析');
    _log(_separator());
    _log('📋 配置信息:');
    _log('  AppConfig.baseUrl = ${AppConfig.baseUrl}');
    _log('  AppConfig.apiBaseUrl = ${AppConfig.apiBaseUrl}');
    _log('📋 请求参数:');
    _log('  图片大小: ${imageSizeKB} KB (${imageBytes.length} bytes)');
    _log('  患者ID: $patientId');
    _log('  摄像头ID: ${cameraId ?? "未提供"}');
    _log('  时间戳: ${timestampMs ?? DateTime.now().millisecondsSinceEpoch}');
    
    try {
      // 构建URL和查询参数
      // 注意：AppConfig.apiBaseUrl 已经包含了 /api 前缀
      final baseUri = Uri.parse('${AppConfig.apiBaseUrl}/analysis/analyze');
      _log('基础URL: ${baseUri.toString()}');
      
      final queryParams = <String, String>{
        'patient_id': patientId,
      };
      
      if (cameraId != null && cameraId.isNotEmpty) {
        queryParams['camera_id'] = cameraId;
      }
      
      if (timestampMs != null) {
        queryParams['timestamp_ms'] = timestampMs.toString();
      }
      
      final url = baseUri.replace(queryParameters: queryParams);
      _log('完整请求URL: $url');
      _log('查询参数: $queryParams');
      
      // 创建multipart请求
      final request = http.MultipartRequest('POST', url);
      
      // 添加图片文件
      final filename = 'monitoring_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ),
      );
      _log('已添加图片文件: $filename');
      
      // 添加token（如果有）
      await _storageService.init();
      final token = _storageService.getString('token');
      if (token != null && token.isNotEmpty) {
        final tokenPreview = '${token.substring(0, token.length > 10 ? 10 : token.length)}...';
        request.headers['Authorization'] = 'Bearer $token';
        _log('已添加Authorization token: $tokenPreview');
      } else {
        _log('未找到token，将使用无认证请求', level: 'WARN');
      }
      
      // 记录请求头
      _log('请求头: ${request.headers}');
      
      // 发送请求
      _log('正在发送请求...');
      final requestTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final requestDuration = DateTime.now().difference(requestTime);
      
      _log('请求完成，耗时: ${requestDuration.inMilliseconds}ms');
      _log('响应状态码: ${response.statusCode}');
      _log('响应头: ${response.headers}');
      _log('响应体大小: ${response.body.length} bytes');
      
      // 解析响应
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          
          // 记录分析结果的关键信息
          if (responseData is Map<String, dynamic>) {
            final overallStatus = responseData['overall_status'] as String?;
            final status = responseData['status'] as String?;
            final resultId = responseData['result_id'] as String?;
            
            _log('分析结果:');
            _log('  - 整体状态: ${overallStatus ?? "未知"}');
            _log('  - 状态: ${status ?? "未知"}');
            _log('  - 结果ID: ${resultId ?? "无"}');
            
            // 如果有detections，记录检测项
            final detections = responseData['detections'] as Map<String, dynamic>?;
            if (detections != null) {
              _log('  - 检测项: ${detections.keys.join(", ")}');
            }
          }
          
          final totalDuration = DateTime.now().difference(startTime);
          _log('✅ 上传和分析成功，总耗时: ${totalDuration.inMilliseconds}ms');
          _log(_separator());
          
          return {
            'success': true,
            'data': responseData,
          };
        } catch (e) {
          _log('JSON解析失败: $e', level: 'ERROR');
          _log('响应体前500字符: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
          throw Exception('响应解析失败: $e');
        }
      } else {
        String errorDetail = '未知错误';
        try {
          final errorData = jsonDecode(response.body);
          errorDetail = errorData['detail'] ?? errorData.toString();
          _log('错误响应: $errorData', level: 'ERROR');
        } catch (e) {
          _log('错误响应体: ${response.body}', level: 'ERROR');
        }
        
        final totalDuration = DateTime.now().difference(startTime);
        _log('❌ 上传失败 (状态码: ${response.statusCode})，总耗时: ${totalDuration.inMilliseconds}ms', level: 'ERROR');
        _log(_separator());
        
        throw Exception(errorDetail);
      }
    } catch (e, stackTrace) {
      final totalDuration = DateTime.now().difference(startTime);
      _log('❌ 异常发生，总耗时: ${totalDuration.inMilliseconds}ms', level: 'ERROR');
      _log('异常类型: ${e.runtimeType}', level: 'ERROR');
      _log('异常信息: $e', level: 'ERROR');
      _log('堆栈跟踪:', level: 'ERROR');
      _log(stackTrace.toString(), level: 'ERROR');
      _log(_separator());
      
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 获取分析历史记录
  Future<List<dynamic>> getAnalysisHistory({
    required String patientId,
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    final startTime = DateTime.now();
    _log('开始获取分析历史记录');
    _log('患者ID: $patientId');
    _log('开始日期: ${startDate ?? "未指定"}');
    _log('结束日期: ${endDate ?? "未指定"}');
    _log('限制数量: $limit');
    
    try {
      // 注意：AppConfig.apiBaseUrl 已经包含了 /api 前缀
      final baseUri = Uri.parse('${AppConfig.apiBaseUrl}/analysis/history/$patientId');
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }
      
      final url = baseUri.replace(queryParameters: queryParams);
      _log('请求URL: $url');
      
      // 获取token
      await _storageService.init();
      final token = _storageService.getString('token');
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        final tokenPreview = '${token.substring(0, token.length > 10 ? 10 : token.length)}...';
        headers['Authorization'] = 'Bearer $token';
        _log('已添加Authorization token: $tokenPreview');
      } else {
        _log('未找到token', level: 'WARN');
      }
      
      _log('正在发送GET请求...');
      final response = await http.get(url, headers: headers);
      final duration = DateTime.now().difference(startTime);
      
      _log('响应状态码: ${response.statusCode}');
      _log('响应耗时: ${duration.inMilliseconds}ms');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          _log('响应体为空，返回空列表');
          return [];
        }
        
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            _log('成功获取 ${decoded.length} 条历史记录');
            return decoded;
          } else {
            _log('响应不是列表格式: ${decoded.runtimeType}', level: 'WARN');
            return [];
          }
        } catch (e) {
          _log('JSON解析失败: $e', level: 'ERROR');
          _log('响应体: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
          return [];
        }
      } else {
        _log('请求失败，状态码: ${response.statusCode}', level: 'ERROR');
        _log('响应体: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _log('❌ 获取历史记录异常，耗时: ${duration.inMilliseconds}ms', level: 'ERROR');
      _log('异常类型: ${e.runtimeType}', level: 'ERROR');
      _log('异常信息: $e', level: 'ERROR');
      _log('堆栈跟踪:', level: 'ERROR');
      _log(stackTrace.toString(), level: 'ERROR');
      return [];
    }
  }
}

