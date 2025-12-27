import '../core/storage/storage_service.dart';
import 'camera_service.dart';

class MonitoringService {
  final StorageService _storageService = StorageService();
  final CameraService _cameraService = CameraService();
  
  bool _isMonitoringEnabled = false;

  /// 初始化
  Future<void> init() async {
    await _storageService.init();
    _isMonitoringEnabled = _storageService.getBool('monitoring_enabled') ?? false;
  }

  /// 开启监控
  Future<void> enableMonitoring(String patientId, {String? cameraId}) async {
    await init();
    _isMonitoringEnabled = true;
    await _storageService.setBool('monitoring_enabled', true);
    
    // 启动摄像头监控（传入patientId）
    await _cameraService.startMonitoring(patientId, cameraId: cameraId);
  }

  /// 关闭监控
  Future<void> disableMonitoring() async {
    await init();
    _isMonitoringEnabled = false;
    await _storageService.setBool('monitoring_enabled', false);
    
    // 停止摄像头监控
    _cameraService.stopMonitoring();
  }

  /// 检查监控是否开启
  bool isMonitoringEnabled() {
    return _isMonitoringEnabled;
  }

  /// 设置拍摄频率
  Future<void> setCaptureInterval(int seconds) async {
    await _cameraService.saveSettings(seconds);
  }

  /// 获取拍摄频率
  int getCaptureInterval() {
    return _cameraService.getCaptureInterval();
  }

  /// 开始定时上传（由CameraService内部处理）
  void _startPeriodicUpload(String patientId, String? cameraId) {
    // CameraService的startMonitoring已经实现了定时拍摄
    // 这里可以添加额外的上传逻辑，比如批量上传
  }
  
  /// 手动触发一次拍摄和上传
  Future<String?> captureAndUpload(String patientId, {String? cameraId}) async {
    return await _cameraService.captureAndUpload(patientId, cameraId: cameraId);
  }

  /// 获取摄像头服务实例（用于获取预览Widget）
  CameraService getCameraService() {
    return _cameraService;
  }
}

