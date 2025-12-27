import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/voice_service.dart';
import '../../core/network/api_service.dart';
import '../../core/config/app_config.dart';

/// 家属端预警详情页面
/// 支持多个预警滑动翻页、振动提醒和语音播报
class AlertDetailPage extends StatefulWidget {
  final List<Map<String, dynamic>> alerts;
  final int initialIndex;

  const AlertDetailPage({
    super.key,
    required this.alerts,
    this.initialIndex = 0,
  });

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  late PageController _pageController;
  late int _currentIndex;
  final VoiceService _voiceService = VoiceService();
  final ApiService _apiService = ApiService();
  bool _hasVibrated = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // 初始化语音服务
    _init();
  }

  Future<void> _init() async {
    try {
      await _voiceService.init();
    } catch (e) {
      debugPrint('[预警详情] 语音服务初始化失败: $e');
    }
    
    // 触发首次振动和语音
    await _triggerAlertFeedback();
  }

  /// 触发振动和语音反馈
  Future<void> _triggerAlertFeedback() async {
    if (_hasVibrated) return; // 只振动一次
    
    final alert = widget.alerts[_currentIndex];
    final severity = alert['severity'] as String?;
    final title = alert['title'] as String? ?? '告警';
    
    // 1. 振动反馈
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (severity == 'critical') {
          // 紧急：长振动模式
          await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
        } else {
          // 其他：短振动
          await Vibration.vibrate(duration: 300);
        }
      }
    } catch (e) {
      debugPrint('[振动] 失败: $e');
    }
    
    // 2. 语音播报（不超过10个字）
    final shortMessage = _buildShortMessage(alert);
    try {
      await _voiceService.speak(shortMessage);
    } catch (e) {
      debugPrint('[语音] 失败: $e');
    }
    
    _hasVibrated = true;
  }

  /// 构建简短语音消息（不超过10个字）
  String _buildShortMessage(Map<String, dynamic> alert) {
    final alertType = alert['alert_type'] as String?;
    final severity = alert['severity'] as String?;
    
    // 根据告警类型生成简短消息
    String message = '';
    
    if (severity == 'critical') {
      message = '紧急告警';
    } else {
      message = '注意';
    }
    
    // 添加具体类型（控制总长度不超过10字）
    switch (alertType) {
      case 'heart_rate_flat':
        message = '心跳变平';
        break;
      case 'fall':
        message = '跌倒告警';
        break;
      case 'iv_drip':
        final title = alert['title'] as String?;
        if (title?.contains('已空') == true) {
          message = '吊瓶已空';
        } else {
          message = '吊瓶告警';
        }
        break;
      case 'bed_exit':
        message = '离床告警';
        break;
      case 'facial':
        message = '面部异常';
        break;
      default:
        // 保持默认消息
    }
    
    return message;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alerts[_currentIndex];
    final severity = alert['severity'] as String?;
    
    // 根据严重程度选择背景色
    Color backgroundColor;
    Color titleColor;
    IconData titleIcon;
    
    switch (severity) {
      case 'critical':
        backgroundColor = Colors.red.shade50;
        titleColor = Colors.red.shade900;
        titleIcon = Icons.warning_amber_rounded;
        break;
      case 'high':
        backgroundColor = Colors.orange.shade50;
        titleColor = Colors.orange.shade900;
        titleIcon = Icons.error_outline;
        break;
      default:
        backgroundColor = Colors.yellow.shade50;
        titleColor = Colors.orange.shade800;
        titleIcon = Icons.info_outline;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            _buildTopBar(titleColor, titleIcon),
            
            // 页面指示器（如果有多个告警）
            if (widget.alerts.length > 1)
              _buildPageIndicator(),
            
            // 主内容区域（可滑动翻页）
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.alerts.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildAlertContent(widget.alerts[index]);
                },
              ),
            ),
            
            // 底部操作按钮
            _buildBottomActions(alert),
          ],
        ),
      ),
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar(Color titleColor, IconData titleIcon) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(titleIcon, color: titleColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '预警详情',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 构建页面指示器
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_currentIndex + 1} / ${widget.alerts.length}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          ...List.generate(
            widget.alerts.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? Colors.blue
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建告警内容
  Widget _buildAlertContent(Map<String, dynamic> alert) {
    final title = alert['title'] as String? ?? '未知告警';
    final description = alert['description'] as String? ?? '';
    final originalImageUrl = alert['image_url'] as String?;
    // 使用代理URL解决CORS问题
    final imageUrl = AppConfig.getProxiedImageUrl(originalImageUrl);
    final createdAt = alert['created_at'] as String?;
    final severity = alert['severity'] as String?;
    
    // 解析description中的JSON（如果有）
    Map<String, dynamic>? detections;
    try {
      if (description.contains('{') && description.contains('detections')) {
        // 尝试从description中提取detections（如果后端把它放在description里）
        // 实际应该从单独的字段获取
      }
    } catch (e) {
      // 忽略解析错误
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 告警标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSeverityBadge(severity),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 告警图片
          if (imageUrl != null && imageUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          
          if (imageUrl != null && imageUrl.isNotEmpty)
            const SizedBox(height: 20),
          
          // 告警描述
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '详细信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建严重程度徽章
  Widget _buildSeverityBadge(String? severity) {
    String label;
    Color color;
    
    switch (severity) {
      case 'critical':
        label = '紧急';
        color = Colors.red;
        break;
      case 'high':
        label = '高';
        color = Colors.orange;
        break;
      case 'medium':
        label = '中';
        color = Colors.yellow.shade700;
        break;
      default:
        label = '低';
        color = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}小时前';
      } else {
        return '${dt.month}月${dt.day}日 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// 构建底部操作按钮
  Widget _buildBottomActions(Map<String, dynamic> alert) {
    final alertId = alert['alert_id'] as String?;
    final familyAcknowledged = alert['family_acknowledged'] as int? ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左右翻页按钮（如果有多个告警）
          if (widget.alerts.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentIndex > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              iconSize: 32,
              color: _currentIndex > 0 ? Colors.blue : Colors.grey,
            ),
            Text(
              '${_currentIndex + 1}/${widget.alerts.length}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentIndex < widget.alerts.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              iconSize: 32,
              color: _currentIndex < widget.alerts.length - 1 ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 16),
          ],
          
          // 确认按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: familyAcknowledged == 0 && alertId != null
                  ? () async {
                      await _acknowledgeAlert(alertId);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  : familyAcknowledged == 1
                      ? () => Navigator.pop(context)
                      : null,
              icon: Icon(
                familyAcknowledged == 1 ? Icons.check_circle : Icons.check,
              ),
              label: Text(
                familyAcknowledged == 1 ? '已确认' : '确认告警',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: familyAcknowledged == 1 ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 确认告警
  Future<void> _acknowledgeAlert(String alertId) async {
    try {
      await _apiService.post('/alerts/$alertId/family-acknowledge', {});
      
      if (mounted) {
        setState(() {
          // 更新当前告警状态
          widget.alerts[_currentIndex]['family_acknowledged'] = 1;
        });
      }
    } catch (e) {
      debugPrint('[确认告警] 失败: $e');
    }
  }
}

