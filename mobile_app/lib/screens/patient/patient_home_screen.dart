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
import '../../widgets/ai_chat_card.dart';
import '../../widgets/video_preview_widget.dart';
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
  
  // 状态
  String _ivDripStatus = '正常';
  String _emotionStatus = '平稳';
  String _medicationStatus = '已按时服药';
  
  // 下一项待办
  Map<String, dynamic>? _nextTodo;
  
  // 视频监控状态
  bool _isVideoInitialized = false;
  bool _isVideoStreaming = false;
  String _videoMode = 'none'; // 'none', 'photo', 'video', 'stream'

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
      
      // 初始化视频监控（Web平台）
      if (kIsWeb) {
        try {
          final initialized = await _videoService.initializeCamera();
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
        _handleIvDripAlert(alertMessage);
      } else if (alertType == 'emotion_companion') {
        _voiceService.speak(alertMessage);
      } else if (alertType == 'medication') {
        _voiceService.speak(alertMessage);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(alertMessage)),
        );
      }
    }
  }

  Future<void> _handleIvDripAlert(String message) async {
    try {
      await _voiceService.speak(message);
    } catch (e) {
      // 忽略语音错误
    }
    
    if (mounted) {
      setState(() {
        _ivDripStatus = '快打完';
      });
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
          _medicationStatus = '待服药';
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
        if (mounted) {
          setState(() {
            _emotionStatus = '需关注';
          });
        }
      }
    });
  }

  /// 方式1: 拍摄照片并上传
  Future<void> _handleCapturePhoto() async {
    if (_patientId == null || !_isVideoInitialized) return;
    
    try {
      final result = await _videoService.captureAndUpload(_patientId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['success'] == true ? '照片已上传' : '上传失败'),
            backgroundColor: result?['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍摄失败: $e')),
        );
      }
    }
  }

  /// 方式2: 录制视频并上传
  Future<void> _handleRecordVideo() async {
    if (_patientId == null || !_isVideoInitialized) return;
    
    try {
      setState(() {
        _videoMode = 'video';
      });
      
      final result = await _videoService.recordAndUpload(
        _patientId!,
        duration: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _videoMode = 'none';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['success'] == true ? '视频已上传' : '上传失败'),
            backgroundColor: result?['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoMode = 'none';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录制失败: $e')),
        );
      }
    }
  }

  /// 方式3: 开启视频流
  Future<void> _handleStartVideoStream() async {
    if (_patientId == null || !_isVideoInitialized) return;
    
    try {
      if (_isVideoStreaming) {
        _videoService.stopVideoStream();
        setState(() {
          _isVideoStreaming = false;
          _videoMode = 'none';
        });
      } else {
        final success = await _videoService.startVideoStream(_patientId!);
        if (success && mounted) {
          setState(() {
            _isVideoStreaming = true;
            _videoMode = 'stream';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频流启动失败: $e')),
        );
      }
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
          const SnackBar(
            content: Text('SOS报警已触发，正在呼叫紧急联系人...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS报警失败: $e')),
        );
      }
    }
  }

  void _handleAiChat() {
    // TODO: 实现AI聊天功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI聊天功能开发中...')),
    );
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('病患端'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 视频监控控制按钮
          if (kIsWeb && _isVideoInitialized)
            PopupMenuButton<String>(
              icon: const Icon(Icons.videocam),
              onSelected: (value) {
                if (value == 'photo') {
                  _handleCapturePhoto();
                } else if (value == 'video') {
                  _handleRecordVideo();
                } else if (value == 'stream') {
                  _handleStartVideoStream();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'photo',
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text('拍摄上传'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'video',
                  child: Row(
                    children: [
                      Icon(Icons.videocam),
                      SizedBox(width: 8),
                      Text('录制上传'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'stream',
                  child: Row(
                    children: [
                      Icon(_isVideoStreaming ? Icons.stop : Icons.play_arrow),
                      const SizedBox(width: 8),
                      Text(_isVideoStreaming ? '停止视频流' : '开启视频流'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 时间显示（大字体）
                    const Center(
                      child: SimpleTimeDisplay(),
                    ),
                    const SizedBox(height: 32),
                    
                    // 用药提醒卡片
                    if (_nextTodo != null)
                      MedicationCard(
                        time: _nextTodo!['time'] as String,
                        label: _nextTodo!['label'] as String,
                      )
                    else
                      const MedicationCard(
                        time: '--:--',
                        label: '暂无待办事项',
                      ),
                    const SizedBox(height: 24),
                    
                    // 视频预览（如果正在流式传输）
                    if (kIsWeb && _isVideoStreaming && _videoService.getVideoElement() != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: VideoPreviewWidget(
                          videoElement: _videoService.getVideoElement(),
                          width: double.infinity,
                          height: 200,
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // 呼叫和SOS按钮
                    Row(
                      children: [
                        CallButton(onPressed: _handleOneTouchCall),
                        SosButton(
                          onSosTriggered: _handleSos,
                          longPressDuration: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // AI聊天卡片
                    AiChatCard(onTap: _handleAiChat),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
