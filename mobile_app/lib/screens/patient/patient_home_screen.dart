import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../../services/voice_service.dart';
import '../../services/websocket_service.dart';
import '../../services/medication_service.dart';
import '../../services/sos_service.dart';
import '../../services/contact_service.dart';
import '../../services/activity_service.dart';
import '../../services/video_monitoring_service.dart';
import '../../services/image_upload_service.dart';
import '../../widgets/simple_time_display.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/call_button.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/video_preview_widget.dart';
import '../../widgets/bear_logo.dart';
import '../../widgets/bear_alert_dialog.dart';
import 'contact_list_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final VoiceService _voiceService = VoiceService();
  final WebSocketService _wsService = WebSocketService();
  final MedicationService _medicationService = MedicationService();
  final SosService _sosService = SosService();
  final ContactService _contactService = ContactService();
  final ActivityService _activityService = ActivityService();
  final VideoMonitoringService _videoService = VideoMonitoringService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // 上传状态
  bool _isUploading = false;
  String? _uploadStatus;

  String? _patientId;
  String? _userId;
  String? _patientName;
  
  // 下一项待办
  Map<String, dynamic>? _nextTodo;
  
  // 视频监控状态
  bool _isVideoInitialized = false;
  bool _isVideoStreaming = false;
  String _videoStatusText = '点击开始监控';

  // 配色方案
  static const Color _backgroundColor = Color(0xFFF5F7FA); // 陶瓷白基底
  static const Color _medicalBlue = Color(0xFFE3F2FD); // 医疗蓝
  static const Color _accentBlue = Color(0xFF90CAF9); // 强调蓝
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _voiceService.init();
    } catch (e) {
      // 忽略语音初始化错误
    }
    
    try {
      await _medicationService.init();
    } catch (e) {
      // 忽略用药服务初始化错误
    }
    
    try {
      await _contactService.init();
    } catch (e) {
      // 忽略联系人服务初始化错误
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _patientId = authProvider.patientId;
    _userId = authProvider.userId;
    _patientName = authProvider.username;
    
    if (_patientId != null && _userId != null) {
      try {
        await _connectWebSocket();
      } catch (e) {
        // 忽略WebSocket连接错误
      }
      
      try {
        await _loadNextTodo();
      } catch (e) {
        // 忽略加载待办错误
      }
      
      try {
        _startMedicationChecking();
      } catch (e) {
        // 忽略用药检查启动错误
      }
      
      try {
        _startActivityChecking();
      } catch (e) {
        // 忽略活动检查启动错误
      }
      
      // 初始化视频监控服务
      try {
        final initialized = await _videoService.initialize();
        if (initialized && mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      } catch (e) {
        // 忽略视频初始化错误
      }
    }
  }

  Future<void> _connectWebSocket() async {
    if (_userId == null) return;

    try {
      debugPrint('[WebSocket] ========== 连接WebSocket ==========');
      debugPrint('[WebSocket] 用户ID: $_userId');
      await _wsService.connect(_userId!);
      debugPrint('[WebSocket] 连接成功');
      
      _wsService.messageStream?.listen((message) {
        final messageType = message['type'] as String?;
        debugPrint('[WebSocket] ========== 收到WebSocket消息 ==========');
        debugPrint('[WebSocket] 消息类型: $messageType');
        debugPrint('[WebSocket] 完整消息: $message');
        debugPrint('[WebSocket] ============================================');
        
        if (messageType == 'voice_alert') {
          debugPrint('[WebSocket] 处理voice_alert消息');
          _handleVoiceAlert(message);
        } else if (messageType == 'patient_alert') {
          debugPrint('[WebSocket] 处理patient_alert消息（患者端告警）');
          _handlePatientAlert(message);
        } else {
          debugPrint('[WebSocket] 未知消息类型: $messageType');
        }
      });
      debugPrint('[WebSocket] 消息监听器已设置');
    } catch (e) {
      debugPrint('[WebSocket] ❌ 连接失败: $e');
    }
  }

  void _handleVoiceAlert(Map<String, dynamic> message) {
    final alertType = message['alert_type'] as String?;
    final alertMessage = message['message'] as String?;

    if (alertMessage != null) {
      if (alertType == 'iv_drip') {
        _voiceService.speak(alertMessage);
      } else if (alertType == 'emotion_companion') {
        _voiceService.speak(alertMessage);
      } else if (alertType == 'medication') {
        _voiceService.speak(alertMessage);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alertMessage),
            backgroundColor: _accentBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// 处理患者端告警消息（显示3D小熊动画 + 萌童声音）
  Future<void> _handlePatientAlert(Map<String, dynamic> message) async {
    final alertType = message['alert_type'] as String?;
    final patientMessage = message['message'] as String?;  // 后端传来的患者友好消息（包含"爷爷"等称呼）
    final playMusic = message['play_music'] as bool? ?? false;
    final alertId = message['alert_id'] as String?;
    final severity = message['severity'] as String?;
    
    debugPrint('============================================================');
    debugPrint('[患者告警] ========== 收到WebSocket患者端告警 ==========');
    debugPrint('[患者告警] 告警ID: $alertId');
    debugPrint('[患者告警] 告警类型: $alertType');
    debugPrint('[患者告警] 严重程度: $severity');
    debugPrint('[患者告警] 患者消息: $patientMessage');
    debugPrint('[患者告警] 播放音乐: $playMusic');
    debugPrint('[患者告警] 完整消息: $message');
    debugPrint('[患者告警] ============================================');
    
    // 生命体征异常：播放温柔音乐，不打扰患者（不显示动画）
    if (playMusic) {
      debugPrint('[患者告警] 生命体征异常，播放温柔音乐，不显示动画');
      debugPrint('[TTS] 开始播报: "系统正在监测您的生命体征，请保持平静"');
      await _voiceService.speak('系统正在监测您的生命体征，请保持平静');
      debugPrint('[TTS] 播报完成');
      return; // 不显示动画
    }
    
    // 其他告警：显示3D小熊动画 + 萌童声音播报
    if (patientMessage != null && patientMessage.isNotEmpty) {
      debugPrint('[患者告警] ========== 准备显示告警 ==========');
      debugPrint('[患者告警] ✅ 收到患者消息: $patientMessage');
      debugPrint('[患者告警] ✅ 消息长度: ${patientMessage.length} 字符');
      debugPrint('[患者告警] ✅ 消息内容检查: ${patientMessage.contains("爷爷") ? "包含'爷爷'" : patientMessage.contains("奶奶") ? "包含'奶奶'" : patientMessage.contains("您") ? "包含'您'" : "未找到称呼"}');
      
      // 显示3D小熊动画对话框（不显示文字，等待语音完成后5秒关闭）
      if (mounted) {
        debugPrint('[患者告警] 显示3D小熊动画对话框（无文字，仅动画）');
        
        // 先显示动画对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (context) => BearAlertDialog(
            message: patientMessage, // 仅用于语音播报，不显示
            autoCloseAfterSpeech: true, // 启用语音完成后自动关闭模式
            onDismiss: () {
              debugPrint('[患者告警] 动画对话框已关闭');
            },
          ),
        );
        
        // 使用萌童声音播报消息（优先使用讯飞TTS，失败时回退到flutter_tts）
        debugPrint('[TTS] ========== 开始TTS播报 ==========');
        debugPrint('[TTS] 播报文本: $patientMessage');
        debugPrint('[TTS] 文本长度: ${patientMessage.length} 字符');
        debugPrint('[TTS] 优先使用: 讯飞TTS (真正的萌童声音)');
        debugPrint('[TTS] 备选方案: flutter_tts (模拟萌童声音)');
        final ttsStartTime = DateTime.now();
        
        // 等待语音播报完成（speak方法会等待播报完成）
        await _voiceService.speak(patientMessage);
        
        final ttsDuration = DateTime.now().difference(ttsStartTime);
        debugPrint('[TTS] ✅ 语音播报完成，耗时: ${ttsDuration.inMilliseconds}ms');
        debugPrint('[TTS] 动画将在5秒后自动关闭');
        debugPrint('[TTS] ============================================');
        
        // 语音完成后，延迟5秒关闭动画对话框
        if (mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              debugPrint('[患者告警] ✅ 动画对话框已自动关闭（语音完成后5秒）');
            }
          });
        }
      }
    } else {
      debugPrint('[患者告警] ⚠️ 患者消息为空，无法显示告警');
      debugPrint('[患者告警] ⚠️ 完整消息内容: $message');
    }
  }

  Future<void> _loadNextTodo() async {
    final medication = await _medicationService.getNextMedication();
    if (medication != null && mounted) {
      setState(() {
        _nextTodo = {
          'time': medication['time'] as String,
          'label': medication['name'] as String,
        };
      });
    }
  }

  void _startMedicationChecking() {
    _medicationService.startChecking((medication) {
      final name = medication['name'] as String;
      final time = medication['time'] as String;
      final quantity = medication['quantity'] as int;
      final unit = medication['unit'] as String;
      final greeting = _getGreeting();
      
      final message = '$greeting，$time到了，该吃$name了，一共$quantity$unit。';
      _voiceService.speak(message);
      
      if (mounted) {
        setState(() {
          _nextTodo = {
            'time': time,
            'label': '$name - 待服用',
          };
        });
      }
      
      Future.delayed(const Duration(seconds: 2), () {
        _loadNextTodo();
      });
    });
  }

  String _getGreeting() {
    return _patientName ?? '您好';
  }

  void _startActivityChecking() {
    if (_patientId == null) return;
    
    _activityService.startChecking(_patientId!, (isSedentary) {
      if (isSedentary) {
        _voiceService.speak('坐得有点久了，起来走动一下吧。');
      }
    });
  }

  /// 开启/停止视频流监控
  Future<void> _handleToggleVideoStream() async {
    if (_patientId == null || !_isVideoInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('视频服务未初始化'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    try {
      if (_isVideoStreaming) {
        _videoService.stopPeriodicCapture();
        setState(() {
          _isVideoStreaming = false;
          _videoStatusText = '监控已停止';
        });
      } else {
        final success = await _videoService.startPeriodicCapture(
          _patientId!,
          interval: const Duration(seconds: 10),
        );
        if (success && mounted) {
          setState(() {
            _isVideoStreaming = true;
            _videoStatusText = '监控中...每10秒上传';
          });
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _handleOneTouchCall() async {
    if (!mounted) return;
    
    final contacts = await _contactService.getContacts();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContactListScreen(
          contacts: contacts,
          onContactSelected: (contact) async {
            final phone = contact['phone'] as String?;
            if (phone != null && phone.isNotEmpty) {
              final url = Uri.parse('tel:$phone');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleSos() async {
    if (_patientId == null || _userId == null) return;
    
    try {
      await _sosService.triggerSos(_patientId!, _userId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SOS报警已触发，正在呼叫紧急联系人...'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 处理分析结果并触发警报
  /// 
  /// 注意：图片上传后，后端会：
  /// 1. 分析图片
  /// 2. 创建告警记录
  /// 3. 通过WebSocket发送patient_alert消息（包含完整的患者友好消息，如"爷爷，您摔倒了..."）
  /// 
  /// 因此，这里只显示分析结果，不立即触发告警
  /// 真正的告警（包含"爷爷"等称呼）会通过WebSocket的patient_alert消息触发
  Future<void> _handleAnalysisResult(Map<String, dynamic>? responseData) async {
    if (responseData == null) {
      debugPrint('[分析结果] 无响应数据');
      return;
    }

    debugPrint('============================================================');
    debugPrint('[分析结果] ========== 处理图片分析结果 ==========');
    debugPrint('[分析结果] 完整响应字段: ${responseData.keys.join(", ")}');
    
    // 后端返回格式: { status, result_id, analysis: { overall_status, detections, ... } }
    // 需要从 analysis 字段中提取分析结果
    final analysisData = responseData['analysis'] as Map<String, dynamic>?;
    
    if (analysisData == null) {
      debugPrint('[分析结果] analysis 字段为空');
      debugPrint('[分析结果] 响应数据: $responseData');
      debugPrint('[分析结果] ============================================');
      return;
    }

    final overallStatus = analysisData['overall_status'] as String? ?? '未知';
    final detections = analysisData['detections'] as Map<String, dynamic>? ?? {};
    final alertMessage = analysisData['alert_message'] as String?;
    
    debugPrint('[分析结果] 整体状态: $overallStatus');
    debugPrint('[分析结果] 检测项: ${detections.keys.join(", ")}');
    debugPrint('[分析结果] 告警消息: ${alertMessage ?? "无"}');
    debugPrint('[分析结果] ⚠️ 注意: 后端会通过WebSocket发送patient_alert消息');
    debugPrint('[分析结果] ⚠️ 注意: patient_alert消息包含完整的患者友好消息（如"爷爷，您摔倒了..."）');
    debugPrint('[分析结果] ⚠️ 注意: 这里不立即触发告警，等待WebSocket消息');
    
    // 不显示分析结果详情对话框，避免打扰患者
    // 告警会通过WebSocket的patient_alert消息触发（包含正确的"爷爷"等称呼）
    // await _showAnalysisResultDialog(analysisData);  // 已禁用，不弹出文本对话框
    debugPrint('[分析结果] ⚠️ 文本对话框已禁用，等待WebSocket推送小熊动画');
    
    debugPrint('[分析结果] ============================================');
  }

  /// 触发紧急警报（振动+声音+弹窗）
  /// 
  /// 注意：这个方法是在图片上传后直接调用的，不是通过WebSocket
  /// WebSocket的patient_alert消息会通过_handlePatientAlert处理
  Future<void> _triggerCriticalAlert(Map<String, dynamic> detections, String? message) async {
    debugPrint('============================================================');
    debugPrint('[警报] ========== 触发紧急警报（图片上传触发） ==========');
    debugPrint('[警报] 检测项: ${detections.keys.join(", ")}');
    debugPrint('[警报] 后端消息: $message');
    
    // 检查是否为生命体征异常（不打扰患者）
    final vitalSigns = detections['vital_signs'] as Map<String, dynamic>?;
    final isVitalSignsAlert = vitalSigns != null && 
        (vitalSigns['heart_rate_flat'] == true || 
         vitalSigns['heart_rate_slow'] == true ||
         vitalSigns['oxygen_low'] == true ||
         vitalSigns['critical_life_threat'] == true);
    
    debugPrint('[警报] 生命体征异常: $isVitalSignsAlert');
    
    // 生命体征异常：只播放音乐，不振动，不语音播报，不显示动画
    if (isVitalSignsAlert) {
      debugPrint('[警报] 生命体征异常，播放温柔音乐，不打扰患者');
      debugPrint('[TTS] 开始播报: "系统正在监测您的生命体征，请保持平静"');
      await _voiceService.speak('系统正在监测您的生命体征，请保持平静');
      debugPrint('[TTS] 播报完成');
      debugPrint('[警报] ============================================');
      return; // 不显示动画
    }
    
    // 其他紧急告警：显示3D小熊动画 + 萌童声音
    // 1. 振动（长振动模式）
    try {
      if (await Vibration.hasVibrator() ?? false) {
        debugPrint('[振动] 触发紧急振动模式');
        // 紧急模式：长-短-长振动
        await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
        debugPrint('[振动] 振动完成');
      }
    } catch (e) {
      debugPrint('[振动] 振动失败: $e');
    }
    
    // 2. 生成患者友好的消息
    // 注意：这里使用的是本地构建的消息，可能不包含"爷爷"等称呼
    // 真正的患者友好消息应该通过WebSocket的patient_alert消息获取
    final patientMessage = _buildPatientFriendlyMessage(detections);
    final alertText = patientMessage ?? message ?? _buildAlertMessage(detections);
    
    debugPrint('[警报] 本地构建的患者消息: $patientMessage');
    debugPrint('[警报] 后端消息: $message');
    debugPrint('[警报] 最终使用的消息: $alertText');
    debugPrint('[警报] ⚠️ 注意: 这是图片上传触发的告警，消息可能不包含"爷爷"等称呼');
    debugPrint('[警报] ⚠️ 建议: 等待WebSocket的patient_alert消息，其中包含完整的患者友好消息');
    
    // 3. 显示3D小熊动画对话框（不显示文字）
    if (mounted) {
      debugPrint('[警报] 显示3D小熊动画对话框');
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => BearAlertDialog(
          message: alertText,
          autoCloseAfterSpeech: true, // 语音完成后5秒自动关闭
        ),
      );
      
      // 4. 使用萌童声音播报
      debugPrint('[TTS] ========== 开始TTS播报 ==========');
      debugPrint('[TTS] 播报文本: $alertText');
      debugPrint('[TTS] 使用服务: flutter_tts (萌童声音模式)');
      final ttsStartTime = DateTime.now();
      await _voiceService.speak(alertText);
      final ttsDuration = DateTime.now().difference(ttsStartTime);
      debugPrint('[TTS] 播报完成，耗时: ${ttsDuration.inMilliseconds}ms');
      debugPrint('[TTS] ============================================');
      
      // 语音完成后，延迟5秒关闭动画对话框
      if (mounted) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            debugPrint('[警报] ✅ 动画对话框已自动关闭（语音完成后5秒）');
          }
        });
      }
    }
    debugPrint('[警报] ============================================');
  }

  /// 触发警告警报（短振动+3D小熊动画+萌童声音）
  /// 
  /// 注意：这个方法是在图片上传后直接调用的，不是通过WebSocket
  /// WebSocket的patient_alert消息会通过_handlePatientAlert处理
  Future<void> _triggerWarningAlert(Map<String, dynamic> detections, String? message) async {
    debugPrint('============================================================');
    debugPrint('[警报] ========== 触发警告警报（图片上传触发） ==========');
    debugPrint('[警报] 检测项: ${detections.keys.join(", ")}');
    debugPrint('[警报] 后端消息: $message');
    
    // 1. 振动（短振动）
    try {
      if (await Vibration.hasVibrator() ?? false) {
        debugPrint('[振动] 触发短振动');
        await Vibration.vibrate(duration: 300);
        debugPrint('[振动] 振动完成');
      }
    } catch (e) {
      debugPrint('[振动] 振动失败: $e');
    }
    
    // 2. 生成患者友好的消息
    // 注意：这里使用的是本地构建的消息，可能不包含"爷爷"等称呼
    // 真正的患者友好消息应该通过WebSocket的patient_alert消息获取
    final patientMessage = _buildPatientFriendlyMessage(detections);
    final alertText = patientMessage ?? message ?? _buildAlertMessage(detections);
    
    debugPrint('[警报] 本地构建的患者消息: $patientMessage');
    debugPrint('[警报] 后端消息: $message');
    debugPrint('[警报] 最终使用的消息: $alertText');
    debugPrint('[警报] ⚠️ 注意: 这是图片上传触发的告警，消息可能不包含"爷爷"等称呼');
    
    // 3. 显示3D小熊动画对话框（不显示文字）
    if (mounted) {
      debugPrint('[警报] 显示3D小熊动画对话框');
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => BearAlertDialog(
          message: alertText,
          autoCloseAfterSpeech: true, // 语音完成后5秒自动关闭
        ),
      );
      
      // 4. 使用萌童声音播报
      debugPrint('[TTS] ========== 开始TTS播报 ==========');
      debugPrint('[TTS] 播报文本: $alertText');
      debugPrint('[TTS] 使用服务: flutter_tts (萌童声音模式)');
      final ttsStartTime = DateTime.now();
      await _voiceService.speak(alertText);
      final ttsDuration = DateTime.now().difference(ttsStartTime);
      debugPrint('[TTS] 播报完成，耗时: ${ttsDuration.inMilliseconds}ms');
      debugPrint('[TTS] ============================================');
      
      // 语音完成后，延迟5秒关闭动画对话框
      if (mounted) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            debugPrint('[警报] ✅ 动画对话框已自动关闭（语音完成后5秒）');
          }
        });
      }
    }
    debugPrint('[警报] ============================================');
  }
  
  /// 构建患者友好的消息
  String? _buildPatientFriendlyMessage(Map<String, dynamic> detections) {
    final patientName = _patientName ?? '您';
    
    // 检查跌倒检测
    final fall = detections['fall'] as Map<String, dynamic>?;
    if (fall?['detected'] == true) {
      return '$patientName，您摔倒了，我已经发信息给您亲属。如果您还需要呼叫120，请您回复我。';
    }
    
    // 检查吊瓶监测
    final ivDrip = detections['iv_drip'] as Map<String, dynamic>?;
    if (ivDrip?['completely_empty'] == true) {
      return '$patientName，您的吊液已完全输完，我已经通知亲属，请您立即联系护士更换。';
    } else if (ivDrip?['bag_empty'] == true || ivDrip?['needs_replacement'] == true) {
      return '$patientName，您的吊液快输完了，我已经通知亲属，您可主动联系护士，避免耽误换液。';
    }
    
    // 其他情况返回null，使用默认消息
    return null;
  }

  /// 触发正常提示（无振动）
  Future<void> _triggerNormalAlert(Map<String, dynamic> detections) async {
    debugPrint('[警报] 正常状态，无需警报');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ 分析完成，一切正常'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// 构建警报消息
  String _buildAlertMessage(Map<String, dynamic> detections) {
    final alerts = <String>[];
    
    // 🚨 最高优先级：检查生命体征（心跳变平等）
    final vitalSigns = detections['vital_signs'] as Map<String, dynamic>?;
    if (vitalSigns?['heart_rate_flat'] == true) {
      alerts.add('心跳变平 - 濒临死亡！');
    } else if (vitalSigns?['heart_rate_slow'] == true) {
      alerts.add('心跳变缓');
    }
    if (vitalSigns?['oxygen_low'] == true) {
      alerts.add('血氧下降');
    }
    
    // 检查跌倒检测
    final fall = detections['fall'] as Map<String, dynamic>?;
    if (fall?['detected'] == true) {
      alerts.add('检测到跌倒');
    }
    
    // 检查离床检测
    final bedExit = detections['bed_exit'] as Map<String, dynamic>?;
    if (bedExit?['patient_in_bed'] == false) {
      alerts.add('患者已离床');
    }
    
    // 检查面部分析
    final facial = detections['facial_analysis'] as Map<String, dynamic>?;
    final expression = facial?['expression'] as String?;
    if (expression == '痛苦' || expression == '恐惧') {
      alerts.add('检测到$expression表情');
    }
    final skinColor = facial?['skin_color'] as String?;
    if (skinColor == '紫绀' || skinColor == '异常') {
      alerts.add('皮肤异常');
    }
    
    // 检查吊瓶监测
    final ivDrip = detections['iv_drip'] as Map<String, dynamic>?;
    if (ivDrip?['completely_empty'] == true) {
      alerts.add('吊瓶已打完');
    } else if (ivDrip?['bag_empty'] == true) {
      alerts.add('吊瓶袋子已空');
    }
    
    // 检查活动异常
    final activity = detections['activity'] as Map<String, dynamic>?;
    if (activity?['abnormal'] == true) {
      final activityType = activity?['type'] as String?;
      if (activityType != null && activityType != '正常') {
        alerts.add('活动异常: $activityType');
      }
    }
    
    if (alerts.isEmpty) {
      return '检测到异常情况';
    }
    
    return alerts.join('、');
  }

  /// 显示分析结果详情对话框
  Future<void> _showAnalysisResultDialog(Map<String, dynamic> analysisData) async {
    if (!mounted) return;
    
    final overallStatus = analysisData['overall_status'] as String? ?? '未知';
    final detections = analysisData['detections'] as Map<String, dynamic>? ?? {};
    final recommendedAction = analysisData['recommended_action'] as String?;
    final sceneType = analysisData['scene_type'] as String?;
    
    debugPrint('[对话框] 场景类型: ${sceneType ?? "未知"}');
    debugPrint('[对话框] 建议操作: ${recommendedAction ?? "无"}');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              overallStatus == '紧急' ? Icons.warning_amber_rounded :
              overallStatus == '注意' ? Icons.info_outline :
              Icons.check_circle_outline,
              color: overallStatus == '紧急' ? Colors.red :
                     overallStatus == '注意' ? Colors.orange :
                     Colors.green,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '分析结果 - $overallStatus',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 生命体征（最高优先级）
              if (detections['vital_signs'] != null)
                _buildDetectionItem('🚨 生命体征', detections['vital_signs']),
              
              // 其他检测项
              _buildDetectionItem('跌倒检测', detections['fall']),
              _buildDetectionItem('离床监测', detections['bed_exit']),
              _buildDetectionItem('活动分析', detections['activity']),
              _buildDetectionItem('面部分析', detections['facial_analysis']),
              _buildDetectionItem('吊瓶监测', detections['iv_drip']),
              
              // 建议操作
              if (recommendedAction != null) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: overallStatus == '紧急' ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: overallStatus == '紧急' ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '建议操作: $recommendedAction',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: overallStatus == '紧急' ? Colors.red.shade900 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建检测项显示
  Widget _buildDetectionItem(String title, dynamic data) {
    if (data == null) return const SizedBox.shrink();
    
    final detection = data as Map<String, dynamic>;
    final description = detection['description'] as String?;
    
    // 判断是否为异常情况（用于显示不同颜色）
    bool isAbnormal = false;
    if (title.contains('生命体征')) {
      isAbnormal = detection['heart_rate_flat'] == true || 
                   detection['heart_rate_slow'] == true || 
                   detection['oxygen_low'] == true ||
                   detection['critical_life_threat'] == true;
    } else if (title.contains('跌倒')) {
      isAbnormal = detection['detected'] == true;
    } else if (title.contains('离床')) {
      isAbnormal = detection['patient_in_bed'] == false;
    } else if (title.contains('面部')) {
      final expression = detection['expression'] as String?;
      final skinColor = detection['skin_color'] as String?;
      isAbnormal = expression == '痛苦' || expression == '恐惧' || 
                   skinColor == '紫绀' || skinColor == '异常';
    } else if (title.contains('吊瓶')) {
      isAbnormal = detection['bag_empty'] == true || 
                   detection['completely_empty'] == true;
    } else if (title.contains('活动')) {
      isAbnormal = detection['abnormal'] == true;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAbnormal 
              ? Colors.red.shade50 
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAbnormal 
                ? Colors.red.shade200 
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isAbnormal)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                if (isAbnormal) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isAbnormal ? Colors.red.shade900 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (description != null)
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isAbnormal ? Colors.red.shade700 : Colors.grey[700],
                ),
              )
            else
              Text(
                '无检测结果',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 处理图片上传
  Future<void> _handleImageUpload() async {
    if (_patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('患者信息未加载，请稍后再试'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 显示选择对话框
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      // 选择图片
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      // 读取图片数据
      final imageBytes = await image.readAsBytes();

      // 开始上传
      setState(() {
        _isUploading = true;
        _uploadStatus = '正在上传图片...';
      });

      // 上传并分析
      final result = await _imageUploadService.uploadAndAnalyze(
        imageBytes: Uint8List.fromList(imageBytes),
        patientId: _patientId!,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (result['success'] == true) {
          // 处理分析结果
          await _handleAnalysisResult(result['data'] as Map<String, dynamic>?);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('上传失败: ${result['error'] ?? '未知错误'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _medicationService.stopChecking();
    _activityService.stopChecking();
    _sosService.stopSos();
    _videoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏 - 简洁设计
            _buildTopBar(),
            
            // 主内容区域
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 大字体时间显示
                        const SimpleTimeDisplay(),
                        const SizedBox(height: 48),
                        
                        // 用药提醒卡片
                        _nextTodo != null
                            ? MedicationCard(
                                time: _nextTodo!['time'] as String,
                                label: _nextTodo!['label'] as String,
                              )
                            : const MedicationCard(
                                time: '--:--',
                                label: 'Medication',
                              ),
                        const SizedBox(height: 48),
                        
                        // 视频监控状态卡片（可选显示）
                        if (_isVideoInitialized && _isVideoStreaming)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: VideoPreviewWidget(
                              width: double.infinity,
                              height: 80,
                              isActive: _isVideoStreaming,
                              statusText: _videoStatusText,
                              onTap: _handleToggleVideoStream,
                            ),
                          ),
                        
                        if (_isVideoInitialized && _isVideoStreaming)
                          const SizedBox(height: 32),
                        
                        // Call 和 SOS 按钮
                        Row(
                          children: [
                            CallButton(onPressed: _handleOneTouchCall),
                            SosButton(
                              onSosTriggered: _handleSos,
                              longPressDuration: 3,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 底部小熊Logo
            _buildBottomLogo(),
          ],
        ),
      ),
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：上传图片按钮
          GestureDetector(
            onTap: _isUploading ? null : _handleImageUpload,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isUploading ? _hintColor.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF90CAF9)),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF90CAF9),
                      size: 24,
                    ),
            ),
          ),
          
          // 视频监控按钮（如果已初始化）
          if (_isVideoInitialized) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleToggleVideoStream,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isVideoStreaming ? _medicalBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isVideoStreaming ? Icons.videocam : Icons.videocam_off_outlined,
                  color: _isVideoStreaming ? const Color(0xFF1976D2) : _hintColor,
                  size: 24,
                ),
              ),
            ),
          ],
          
          // 中间：标题（可选）
          const Spacer(),
          
          // 右侧：退出按钮
          GestureDetector(
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_outlined,
                color: _hintColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部小熊Logo
  Widget _buildBottomLogo() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        children: [
          // 小熊Logo - 使用PNG图片
          const BearLogo(size: 56),
          const SizedBox(height: 8),
          Text(
            'SmartGuard',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _hintColor.withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
