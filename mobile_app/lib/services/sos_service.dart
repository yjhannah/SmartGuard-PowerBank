import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'location_service.dart';
import 'contact_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'voice_service.dart';

class SosService {
  final LocationService _locationService = LocationService();
  final ContactService _contactService = ContactService();
  final VoiceService _voiceService = VoiceService();
  
  bool _isSosActive = false;
  Timer? _callTimer;
  int _currentCallIndex = 0;
  List<Map<String, dynamic>> _emergencyContacts = [];

  /// 触发SOS报警
  Future<void> triggerSos(String patientId, String userId) async {
    if (_isSosActive) {
      return; // 防止重复触发
    }

    _isSosActive = true;

    try {
      // 1. 获取位置信息（Web平台可能不支持）
      Map<String, dynamic>? location;
      if (!kIsWeb) {
        try {
          location = await _locationService.getCurrentLocation();
        } catch (e) {
          // 忽略位置获取错误
        }
      }
      
      // 2. 发送报警信息到后端
      try {
        var url = '${AppConfig.apiBaseUrl}/alerts/sos?patient_id=$patientId&user_id=$userId';
        if (location != null) {
          url += '&latitude=${location['latitude']}&longitude=${location['longitude']}';
          if (location['address'] != null) {
            url += '&address=${Uri.encodeComponent(location['address'])}';
          }
        }
        await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        // 忽略API错误，继续执行本地流程
      }

      // 3. 获取紧急联系人
      _emergencyContacts = await _contactService.getEmergencyContacts();
      _currentCallIndex = 0;

      // 4. 语音提示
      try {
        await _voiceService.init();
        await _voiceService.speak('已为您呼叫帮助，请保持镇定。');
      } catch (e) {
        // 忽略语音错误
      }

      // 5. 开始循环拨打电话（Web平台可能不支持）
      if (!kIsWeb) {
        _startCallingLoop();
      }
    } catch (e) {
      _isSosActive = false;
      rethrow;
    }
  }

  /// 循环拨打电话直到接通
  void _startCallingLoop() {
    if (_emergencyContacts.isEmpty) {
      _isSosActive = false;
      return;
    }

    _callNextContact();
  }

  /// 拨打下一个联系人
  Future<void> _callNextContact() async {
    if (_currentCallIndex >= _emergencyContacts.length) {
      // 所有联系人都拨打过了，重新开始
      _currentCallIndex = 0;
      // 等待30秒后重试
      _callTimer = Timer(const Duration(seconds: 30), () {
        _callNextContact();
      });
      return;
    }

    final contact = _emergencyContacts[_currentCallIndex];
    final phoneNumber = contact['phone'] as String?;

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        final url = Uri.parse('tel:$phoneNumber');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          // 等待一段时间后拨打下一个（假设未接通）
          _callTimer = Timer(const Duration(seconds: 15), () {
            _currentCallIndex++;
            _callNextContact();
          });
        } else {
          // 无法拨号，继续下一个
          _currentCallIndex++;
          _callNextContact();
        }
      } catch (e) {
        // 拨号失败，继续下一个
        _currentCallIndex++;
        _callNextContact();
      }
    } else {
      // 没有电话号码，继续下一个
      _currentCallIndex++;
      _callNextContact();
    }
  }

  /// 停止SOS流程
  void stopSos() {
    _isSosActive = false;
    _callTimer?.cancel();
    _callTimer = null;
    _currentCallIndex = 0;
  }

  /// 检查SOS是否激活
  bool get isSosActive => _isSosActive;
}
