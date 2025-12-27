import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/voice_service.dart';
import '../../services/websocket_service.dart';
import '../../services/medication_service.dart';
import '../../services/sos_service.dart';
import '../../services/contact_service.dart';
import '../../services/activity_service.dart';
import '../../services/video_monitoring_service.dart';
import '../../widgets/simple_time_display.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/call_button.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/video_preview_widget.dart';
import '../../widgets/bear_logo.dart';
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
      await _wsService.connect(_userId!);
      _wsService.messageStream?.listen((message) {
        if (message['type'] == 'voice_alert') {
          _handleVoiceAlert(message);
        }
      });
    } catch (e) {
      // 忽略WebSocket连接错误
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
          // 左侧：视频监控按钮
          if (_isVideoInitialized)
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
            )
          else
            const SizedBox(width: 44),
          
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
