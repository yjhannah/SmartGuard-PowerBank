import 'dart:async';
import '../core/storage/storage_service.dart';
import 'dart:convert';

class MedicationService {
  final StorageService _storageService = StorageService();
  Timer? _checkTimer;

  /// 初始化存储服务
  Future<void> init() async {
    await _storageService.init();
  }

  /// 获取用药计划
  Future<List<Map<String, dynamic>>> getMedications() async {
    await init();
    final medicationsJson = _storageService.getString('medications');
    if (medicationsJson == null || medicationsJson.isEmpty) {
      // 返回示例数据（Demo）
      return [
        {
          'id': '1',
          'name': '蓝色降压药',
          'time': '15:00',
          'quantity': 2,
          'unit': '片',
          'description': '下午三点服用',
        },
        {
          'id': '2',
          'name': '维生素',
          'time': '08:00',
          'quantity': 1,
          'unit': '粒',
          'description': '早上八点服用',
        },
      ];
    }
    
    try {
      final List<dynamic> medications = jsonDecode(medicationsJson);
      return medications.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 保存用药计划
  Future<void> saveMedications(List<Map<String, dynamic>> medications) async {
    await init();
    await _storageService.setString('medications', jsonEncode(medications));
  }

  /// 获取下一个用药时间
  Future<Map<String, dynamic>?> getNextMedication() async {
    final medications = await getMedications();
    if (medications.isEmpty) return null;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 找到下一个用药时间
    Map<String, dynamic>? nextMedication;
    String? nextTime;

    for (var medication in medications) {
      final time = medication['time'] as String;
      if (time.compareTo(currentTime) > 0) {
        if (nextTime == null || time.compareTo(nextTime!) < 0) {
          nextTime = time;
          nextMedication = medication;
        }
      }
    }

    // 如果今天没有，找明天最早的
    if (nextMedication == null && medications.isNotEmpty) {
      medications.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
      nextMedication = medications[0];
    }

    return nextMedication;
  }

  /// 检查当前时间是否需要用药
  Future<bool> shouldTakeMedicationNow() async {
    final medications = await getMedications();
    if (medications.isEmpty) return false;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (var medication in medications) {
      final time = medication['time'] as String;
      if (time == currentTime) {
        // 检查今天是否已经提醒过
        final lastReminder = _storageService.getString('last_medication_reminder_${medication['id']}');
        final today = now.toIso8601String().split('T')[0];
        if (lastReminder != today) {
          // 标记今天已提醒
          await _storageService.setString('last_medication_reminder_${medication['id']}', today);
          return true;
        }
      }
    }

    return false;
  }

  /// 获取当前需要用药的药品
  Future<Map<String, dynamic>?> getCurrentMedication() async {
    final medications = await getMedications();
    if (medications.isEmpty) return null;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (var medication in medications) {
      final time = medication['time'] as String;
      if (time == currentTime) {
        return medication;
      }
    }

    return null;
  }

  /// 开始定时检查用药时间
  void startChecking(Function(Map<String, dynamic>) onMedicationTime) {
    _checkTimer?.cancel();
    // 每分钟检查一次
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final medication = await getCurrentMedication();
      if (medication != null) {
        onMedicationTime(medication);
      }
    });
  }

  /// 停止定时检查
  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }
}

