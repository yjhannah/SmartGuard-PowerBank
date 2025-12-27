import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

/// 视频监控服务 - 支持三种方式：
/// 1. 拍摄上传 - 拍照后上传
/// 2. 视频上传 - 录制视频后上传
/// 3. 视频流 - 实时视频流传输
/// 
/// 注意：Web平台的摄像头功能需要通过JavaScript互操作实现
/// 当前版本提供简化的HTTP上传接口
class VideoMonitoringService {
  Timer? _captureTimer;
  bool _isStreaming = false;
  String? _currentPatientId;
  bool _isInitialized = false;

  /// 输出日志
  void _log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [$level] [VideoMonitoringService] $message');
  }

  // 用于存储捕获回调
  Future<Uint8List?> Function()? _captureCallback;

  /// 设置捕获回调（由外部Widget提供）
  void setCaptureCallback(Future<Uint8List?> Function() callback) {
    _captureCallback = callback;
  }

  /// 初始化（简化版本）
  Future<bool> initialize() async {
    _isInitialized = true;
    return true;
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 方式1: 上传图片数据
  Future<Map<String, dynamic>?> uploadImage(
    String patientId,
    Uint8List imageBytes, {
    String? filename,
  }) async {
    _log('开始上传图片（视频监控服务）');
    _log('AppConfig.baseUrl = ${AppConfig.baseUrl}');
    _log('AppConfig.apiBaseUrl = ${AppConfig.apiBaseUrl}');
    _log('患者ID: $patientId');
    _log('图片大小: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');
    
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/analysis/analyze?patient_id=$patientId');
      _log('完整请求URL: $url');
      
      final request = http.MultipartRequest('POST', url);
      final fname = filename ?? 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fname,
        ),
      );
      _log('文件名: $fname');

      _log('发送请求...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      _log('响应状态码: ${response.statusCode}');
      _log('响应体长度: ${responseBody.length}');

      if (response.statusCode == 200) {
        _log('✅ 上传成功');
        return {
          'success': true,
          'result_id': responseBody,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      _log('❌ 上传失败: ${response.statusCode}', level: 'ERROR');
      return {'success': false, 'error': '上传失败: ${response.statusCode}'};
    } catch (e) {
      _log('❌ 上传异常: $e', level: 'ERROR');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 方式2: 上传视频数据
  Future<Map<String, dynamic>?> uploadVideo(
    String patientId,
    Uint8List videoBytes, {
    String? filename,
  }) async {
    _log('开始上传视频');
    _log('AppConfig.apiBaseUrl = ${AppConfig.apiBaseUrl}');
    _log('患者ID: $patientId');
    _log('视频大小: ${(videoBytes.length / 1024).toStringAsFixed(2)} KB');
    
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/analysis/upload-video?patient_id=$patientId');
      _log('完整请求URL: $url');
      
      final request = http.MultipartRequest('POST', url);
      final fname = filename ?? 'video_${DateTime.now().millisecondsSinceEpoch}.webm';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoBytes,
          filename: fname,
        ),
      );
      _log('文件名: $fname');

      _log('发送请求...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      _log('响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('✅ 上传成功');
        return {
          'success': true,
          'result_id': responseBody,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      _log('❌ 上传失败: ${response.statusCode}', level: 'ERROR');
      return {'success': false, 'error': '上传失败: ${response.statusCode}'};
    } catch (e) {
      _log('❌ 上传异常: $e', level: 'ERROR');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 方式3: 开启定时上传（视频流模式）
  Future<bool> startPeriodicCapture(
    String patientId, {
    Duration interval = const Duration(seconds: 10),
  }) async {
    if (_isStreaming) {
      return true;
    }

    _currentPatientId = patientId;
    _isStreaming = true;

    // 定时触发捕获
    _captureTimer = Timer.periodic(interval, (timer) async {
      if (_captureCallback != null && _currentPatientId != null) {
        final bytes = await _captureCallback!();
        if (bytes != null) {
          await uploadImage(_currentPatientId!, bytes);
        }
      }
    });

    return true;
  }

  /// 停止定时上传
  void stopPeriodicCapture() {
    _isStreaming = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 释放资源
  void dispose() {
    stopPeriodicCapture();
    _captureCallback = null;
    _isInitialized = false;
  }

  /// 检查是否正在流式传输
  bool get isStreaming => _isStreaming;

  /// 获取当前患者ID
  String? get currentPatientId => _currentPatientId;
}
