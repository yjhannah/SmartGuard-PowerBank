import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

// Web平台专用导入
import 'dart:html' as html if (dart.library.html) 'dart:html';

/// 视频监控服务 - 支持三种方式：
/// 1. 拍摄上传 - 拍照后上传
/// 2. 视频上传 - 录制视频后上传
/// 3. 视频流 - 实时视频流传输
class VideoMonitoringService {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  Timer? _captureTimer;
  bool _isStreaming = false;
  String? _currentPatientId;

  /// 初始化摄像头（Web平台）
  Future<bool> initializeCamera() async {
    if (!kIsWeb) {
      return false;
    }

    try {
      // 获取用户媒体（摄像头）
      _mediaStream = await html.window.navigator.getUserMedia(
        video: {'facingMode': 'user'}, // 前置摄像头
      );

      // 创建video元素用于预览
      _videoElement = html.VideoElement()
        ..srcObject = _mediaStream
        ..autoplay = true
        ..playsInline = true
        ..style.width = '100%'
        ..style.height = '100%';

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 方式1: 拍摄照片并上传
  Future<Map<String, dynamic>?> captureAndUpload(String patientId) async {
    if (!kIsWeb || _videoElement == null) {
      return null;
    }

    try {
      // 创建canvas元素用于拍照
      final canvas = html.CanvasElement(
        width: _videoElement!.videoWidth,
        height: _videoElement!.videoHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(_videoElement!, 0, 0);

      // 转换为blob
      final blob = await canvas.toBlob('image/jpeg', 0.8);
      final bytes = await blobToUint8List(blob);

      // 上传到后端
      final url = Uri.parse('${AppConfig.apiBaseUrl}/analysis/analyze?patient_id=$patientId');
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return {
          'success': true,
          'result_id': responseBody,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      return {'success': false, 'error': '上传失败'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 方式2: 录制视频并上传
  Future<Map<String, dynamic>?> recordAndUpload(
    String patientId, {
    Duration duration = const Duration(seconds: 10),
  }) async {
    if (!kIsWeb || _videoElement == null) {
      return null;
    }

    try {
      final recorder = html.MediaRecorder(_mediaStream!);
      final chunks = <Blob>[];

      recorder.onDataAvailable.listen((event) {
        if (event.data != null) {
          chunks.add(event.data!);
        }
      });

      final completer = Completer<Map<String, dynamic>>();
      recorder.onStop.listen((event) async {
        try {
          // 合并所有chunks
          final videoBlob = html.Blob(chunks, 'video/webm');
          final bytes = await blobToUint8List(videoBlob);

          // 上传到后端
          final url = Uri.parse('${AppConfig.apiBaseUrl}/analysis/upload-video?patient_id=$patientId');
          final request = http.MultipartRequest('POST', url);
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: 'video_${DateTime.now().millisecondsSinceEpoch}.webm',
            ),
          );

          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 200) {
            completer.complete({
              'success': true,
              'result_id': responseBody,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } else {
            completer.complete({'success': false, 'error': '上传失败'});
          }
        } catch (e) {
          completer.complete({'success': false, 'error': e.toString()});
        }
      });

      // 开始录制
      recorder.start();
      await Future.delayed(duration);
      recorder.stop();

      return await completer.future;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 方式3: 开启视频流（实时传输）
  Future<bool> startVideoStream(String patientId) async {
    if (!kIsWeb) {
      return false;
    }

    if (_isStreaming) {
      return true;
    }

    try {
      if (_mediaStream == null) {
        final initialized = await initializeCamera();
        if (!initialized) {
          return false;
        }
      }

      _currentPatientId = patientId;
      _isStreaming = true;

      // 定时发送视频帧（每10秒发送一帧）
      _captureTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (_videoElement != null && _currentPatientId != null) {
          await captureAndUpload(_currentPatientId!);
        }
      });

      return true;
    } catch (e) {
      _isStreaming = false;
      return false;
    }
  }

  /// 停止视频流
  void stopVideoStream() {
    _isStreaming = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 获取视频预览元素（用于在HTML中显示）
  html.VideoElement? getVideoElement() {
    return _videoElement;
  }

  /// 释放资源
  void dispose() {
    stopVideoStream();
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
    _videoElement = null;
  }

  /// 检查是否正在流式传输
  bool get isStreaming => _isStreaming;

  /// Blob转Uint8List
  Future<Uint8List> blobToUint8List(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;
    return reader.result as Uint8List;
  }
}

