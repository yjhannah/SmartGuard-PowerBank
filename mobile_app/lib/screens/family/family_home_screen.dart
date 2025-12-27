import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/websocket_service.dart';
import '../../services/voice_service.dart';
import '../../core/network/api_service.dart';
import '../../widgets/bear_logo.dart';
import 'health_report_card.dart';
import 'activity_chart.dart';
import 'emotion_gauge.dart';
import 'alerts_screen.dart';
import 'call_fab.dart';
import 'alert_detail_page.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  String? _patientId;
  String? _patientName;
  String? _userId;
  
  // 服务
  final WebSocketService _wsService = WebSocketService();
  final VoiceService _voiceService = VoiceService();
  final ApiService _apiService = ApiService();
  
  // 未读告警列表（用于自动弹窗）
  final List<Map<String, dynamic>> _pendingAlerts = [];

  // 配色方案
  static const Color _backgroundColor = Color(0xFFF5F7FA);
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
      debugPrint('[家属端] 语音服务初始化失败: $e');
    }
    
    _loadPatientId();
    
    // 如果有患者ID和用户ID，连接WebSocket
    if (_patientId != null && _userId != null) {
      try {
        await _connectWebSocket();
      } catch (e) {
        debugPrint('[家属端] WebSocket连接失败: $e');
      }
    }
  }

  void _loadPatientId() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // 从AuthProvider获取关联的患者ID和用户ID
    setState(() {
      _patientId = authProvider.patientId;
      _patientName = authProvider.username;
      _userId = authProvider.userId;
    });
  }
  
  /// 连接WebSocket并监听告警
  Future<void> _connectWebSocket() async {
    if (_userId == null) return;

    try {
      debugPrint('[家属端] 连接WebSocket: $_userId');
      await _wsService.connect(_userId!);
      
      _wsService.messageStream?.listen((message) {
        debugPrint('[家属端] 收到WebSocket消息: ${message['type']}');
        
        if (message['type'] == 'alert') {
          // 收到新告警，自动弹出详情页面
          _handleNewAlert(message);
        }
      });
      
      debugPrint('[家属端] WebSocket连接成功');
    } catch (e) {
      debugPrint('[家属端] WebSocket连接失败: $e');
    }
  }
  
  /// 处理新告警（自动弹窗）
  Future<void> _handleNewAlert(Map<String, dynamic> alertMessage) async {
    debugPrint('[家属端] ======================================');
    debugPrint('[家属端] 收到新告警WebSocket消息');
    debugPrint('[家属端] 消息类型: ${alertMessage['type']}');
    debugPrint('[家属端] 告警ID: ${alertMessage['alert_id']}');
    debugPrint('[家属端] 患者ID: ${alertMessage['patient_id']}');
    debugPrint('[家属端] 严重程度: ${alertMessage['severity']}');
    debugPrint('[家属端] 消息: ${alertMessage['message']}');
    debugPrint('[家属端] ======================================');
    
    final alertId = alertMessage['alert_id'] as String?;
    if (alertId == null) {
      debugPrint('[家属端] 告警ID为空，无法获取详情');
      return;
    }
    
    // 从后端获取告警完整详情
    try {
      debugPrint('[家属端] 正在获取告警详情: $alertId');
      final alertDetails = await _apiService.get('/alerts/$alertId');
      
      debugPrint('[家属端] 告警详情获取成功');
      debugPrint('[家属端] 告警类型: ${alertDetails['alert_type']}');
      debugPrint('[家属端] 标题: ${alertDetails['title']}');
      debugPrint('[家属端] 图片URL: ${alertDetails['image_url'] ?? "无"}');
      
      // 添加到待处理列表
      _pendingAlerts.add(alertDetails);
      
      // 立即弹出告警详情页面
      if (mounted) {
        debugPrint('[家属端] 弹出告警详情页面（${_pendingAlerts.length}个告警）');
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlertDetailPage(
              alerts: List.from(_pendingAlerts),
              initialIndex: _pendingAlerts.length - 1, // 显示最新的
            ),
            fullscreenDialog: true,
          ),
        );
        
        // 关闭后清空待处理列表
        _pendingAlerts.clear();
        debugPrint('[家属端] 告警详情页面已关闭');
      }
    } catch (e) {
      debugPrint('[家属端] 获取告警详情失败: $e');
      
      // 如果获取详情失败，使用WebSocket消息中的基本信息
      final basicAlert = {
        'alert_id': alertId,
        'patient_id': alertMessage['patient_id'],
        'severity': alertMessage['severity'],
        'title': alertMessage['title'] ?? '病房监护预警',
        'description': alertMessage['message'] ?? '',
        'created_at': alertMessage['timestamp'] ?? DateTime.now().toIso8601String(),
        'status': 'pending',
        'family_acknowledged': 0,
      };
      
      _pendingAlerts.add(basicAlert);
      
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlertDetailPage(
              alerts: List.from(_pendingAlerts),
              initialIndex: _pendingAlerts.length - 1,
            ),
            fullscreenDialog: true,
          ),
        );
        
        _pendingAlerts.clear();
      }
    }
  }
  
  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            _buildTopBar(),
            
            // 主内容
            Expanded(
              child: _patientId == null
                  ? _buildNoPatientView()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HealthReportCard(patientId: _patientId!),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ActivityChart(patientId: _patientId!),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: EmotionGauge(patientId: _patientId!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          AlertsScreen(patientId: _patientId!),
                          const SizedBox(height: 80), // 为FAB留出空间
                        ],
                      ),
                    ),
            ),
            
            // 底部Logo
            _buildBottomLogo(),
          ],
        ),
      ),
      floatingActionButton: _patientId != null ? CallFAB(patientId: _patientId) : null,
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：标题
          const Text(
            '家属端',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          
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

  /// 无关联患者时显示
  Widget _buildNoPatientView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BearLogo(size: 80),
          const SizedBox(height: 24),
          Text(
            '暂未关联患者',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请联系管理员进行关联',
            style: TextStyle(
              fontSize: 14,
              color: _hintColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部Logo
  Widget _buildBottomLogo() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        children: [
          const BearLogo(size: 40),
          const SizedBox(height: 4),
          Text(
            'SmartGuard',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _hintColor.withOpacity(0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
