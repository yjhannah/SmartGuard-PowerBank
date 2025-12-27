import 'dart:async';
import '../core/network/api_service.dart';

class ActivityService {
  final ApiService _apiService = ApiService();
  Timer? _checkTimer;
  DateTime? _lastActivityTime;
  bool _isSedentary = false;

  /// 开始检查活动状态
  void startChecking(String patientId, Function(bool isSedentary) onSedentaryDetected) {
    _checkTimer?.cancel();
    // 每30分钟检查一次
    _checkTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      await _checkActivityStatus(patientId, onSedentaryDetected);
    });
    
    // 立即检查一次
    _checkActivityStatus(patientId, onSedentaryDetected);
  }

  /// 检查活动状态
  Future<void> _checkActivityStatus(String patientId, Function(bool) onSedentaryDetected) async {
    try {
      final response = await _apiService.get('/patients/$patientId/activity?hours=2');
      final isSedentary = response['is_sedentary'] as bool? ?? false;
      
      if (isSedentary && !_isSedentary) {
        // 刚检测到久坐/久卧
        _isSedentary = true;
        onSedentaryDetected(true);
      } else if (!isSedentary) {
        _isSedentary = false;
      }
    } catch (e) {
      // 忽略检查错误
    }
  }

  /// 停止检查
  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }
}

