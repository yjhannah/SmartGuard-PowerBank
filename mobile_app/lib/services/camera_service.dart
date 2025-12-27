import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import '../core/storage/storage_service.dart';

class CameraService {
  dynamic _controller; // Web平台不支持CameraController
  bool _isInitialized = false;
  Timer? _captureTimer;
  int _captureInterval = 10; // 默认10秒
  bool _isMonitoring = false;
  String? _currentPatientId;
  String? _currentCameraId;
  final StorageService _storageService = StorageService();

  /// 初始化摄像头
  Future<bool> initialize() async {
    // Web平台不支持摄像头
    if (kIsWeb) {
      return false;
    }

    if (_isInitialized && _controller != null) {
      return true;
    }

    // Web平台不支持，直接返回false
    return false;
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    await _storageService.init();
    final interval = _storageService.getInt('camera_capture_interval');
    if (interval != null && interval > 0) {
      _captureInterval = interval;
    }
  }

  /// 保存设置
  Future<void> saveSettings(int interval) async {
    await _storageService.init();
    await _storageService.setInt('camera_capture_interval', interval);
    _captureInterval = interval;
    
    // 如果正在监控，重启定时器
    if (_isMonitoring && _currentPatientId != null) {
      final patientId = _currentPatientId!;
      final cameraId = _currentCameraId;
      stopMonitoring();
      startMonitoring(patientId, cameraId: cameraId);
    }
  }

  /// 获取当前设置
  int getCaptureInterval() => _captureInterval;

  /// 开始监控（定时拍摄）
  /// 需要传入patientId用于上传
  Future<void> startMonitoring(String patientId, {String? cameraId}) async {
    // Web平台不支持摄像头
    if (kIsWeb) {
      return;
    }

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        return; // Web平台不支持，直接返回
      }
    }

    if (_isMonitoring) {
      return; // 已经在监控中
    }

    _currentPatientId = patientId;
    _currentCameraId = cameraId;
    _isMonitoring = true;
    _captureTimer = Timer.periodic(
      Duration(seconds: _captureInterval),
      (timer) {
        if (_currentPatientId != null) {
          _captureAndUpload(_currentPatientId!, cameraId: _currentCameraId);
        }
      },
    );
  }

  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 拍摄并上传
  Future<void> _captureAndUpload(String patientId, {String? cameraId}) async {
    // Web平台不支持摄像头
    if (kIsWeb) {
      return;
    }
    
    try {
      // 拍摄照片并上传
      await captureAndUpload(patientId, cameraId: cameraId);
    } catch (e) {
      // 忽略单次拍摄错误，继续监控
    }
  }

  /// 拍摄一张照片并上传
  Future<String?> captureAndUpload(String patientId, {String? cameraId}) async {
    // Web平台不支持摄像头
    if (kIsWeb) {
      return null;
    }

    // Web平台不支持，直接返回null
    return null;
  }

  /// 获取摄像头预览Widget（用于显示预览）
  Widget? getPreviewWidget() {
    // Web平台不支持摄像头预览
    if (kIsWeb) {
      return null;
    }
    return null;
  }

  /// 释放资源
  Future<void> dispose() async {
    stopMonitoring();
    if (_controller != null) {
      try {
        await _controller?.dispose();
      } catch (e) {
        // 忽略释放错误
      }
    }
    _controller = null;
    _isInitialized = false;
  }

  /// 检查是否正在监控
  bool get isMonitoring => _isMonitoring;
}
